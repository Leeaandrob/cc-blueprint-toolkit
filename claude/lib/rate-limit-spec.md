# Rate Limit Specification

**Version:** 1.0.0
**Pattern Origin:** Ralph for Claude Code
**Purpose:** Protect against API overuse with hourly limits and Anthropic 5h limit detection

---

## Overview

The Rate Limit system prevents excessive API consumption by:
1. **Hourly tracking** - Configurable calls per hour with pause+notify behavior
2. **5h limit detection** - Detects Anthropic's overload limit and auto-waits
3. **Per-project persistence** - Each project maintains independent rate state

## Rate Limit State Machine

```
         ┌─────────────────────────────────────────┐
         │                                         │
         ▼                                         │
    ┌─────────┐   limit reached    ┌───────────┐  │
    │ ACTIVE  │───────────────────▶│  PAUSED   │  │
    │(Normal) │                    │(Waiting)  │  │
    └─────────┘                    └───────────┘  │
         ▲                              │         │
         │   reset window               │         │
         │   OR user resume             │         │
         │                              ▼         │
         │                        ┌──────────┐    │
         └────────────────────────│RATE_LIMIT│────┘
                                  │(5h Limit)│
                                  └──────────┘
```

## Configuration

```yaml
defaults:
  hourly_limit: 100          # Max calls per hour
  hourly_window_minutes: 60  # Window duration
  anthropic_5h_wait_minutes: 60  # Wait after 5h detection

configurable_via:
  environment: BP_RATE_LIMIT_HOURLY
  state_file: .prp-session/rate-limit.json
```

## Hourly Rate Limiting

### Behavior: Pause + Notify

When hourly limit is reached:
1. **PAUSE** autonomous execution immediately
2. **NOTIFY** user with countdown to reset
3. **WAIT** for user confirmation to continue after reset

```yaml
trigger: calls_made >= hourly_limit

action:
  - pause_loop: true
  - calculate: time_until_reset = next_reset - now()
  - notify: |
      ⚠️ Hourly API limit reached ({calls_made}/{limit})
      Reset in: {countdown_formatted}

      Options:
      [W]ait - Resume when limit resets
      [C]ontinue - Override limit (not recommended)
      [A]bort - Stop execution
  - wait_for_input: true
```

### Countdown Calculation

```python
def format_countdown(next_reset: datetime) -> str:
    """Format time until reset for display."""
    delta = next_reset - datetime.now()

    if delta.total_seconds() < 0:
        return "Ready to resume"

    minutes = int(delta.total_seconds() // 60)
    seconds = int(delta.total_seconds() % 60)

    if minutes > 0:
        return f"{minutes}m {seconds}s"
    else:
        return f"{seconds}s"
```

### Window Management

```yaml
window_reset:
  trigger: now() >= next_reset
  action:
    - reset: calls_made = 0
    - update: window_start = now()
    - update: next_reset = window_start + 60 minutes
    - state: ACTIVE
```

## Anthropic 5h Limit Detection

### Detection Method

The 5h limit is detected from API error responses:

```yaml
detection_patterns:
  - status_code: 529
    message_contains: "overloaded"
  - status_code: 429
    message_contains: "rate limit"
    retry_after_header: ">= 3600"  # 1+ hours suggests 5h limit
```

### Behavior: Auto-Wait

When 5h limit is detected:
1. **DETECT** via error response patterns
2. **CALCULATE** resume time (detected_at + 60 minutes)
3. **AUTO-WAIT** without user intervention
4. **RESUME** automatically when wait period expires

```yaml
trigger: 5h_limit_detected

action:
  - record: detected_at = now()
  - calculate: resume_at = detected_at + 60 minutes
  - state: RATE_LIMIT
  - waiting: true
  - notify: |
      🚫 Anthropic 5h rate limit detected
      Auto-waiting until: {resume_at_formatted}
      Remaining: {countdown_formatted}

      (No action required - will auto-resume)
  - auto_resume_at: resume_at
```

### Auto-Resume Logic

```python
def check_5h_resume(state: dict) -> bool:
    """Check if ready to resume from 5h limit."""
    if not state.get("anthropic_5h", {}).get("waiting"):
        return True  # Not waiting

    resume_at = datetime.fromisoformat(state["anthropic_5h"]["resume_at"])

    if datetime.now() >= resume_at:
        # Clear waiting state
        state["anthropic_5h"]["waiting"] = False
        state["anthropic_5h"]["detected"] = False
        return True

    return False
```

## Rate Limit State Schema

```json
{
  "hourly": {
    "calls_made": 0,
    "limit": 100,
    "window_start": "2026-01-16T10:00:00-03:00",
    "next_reset": "2026-01-16T11:00:00-03:00"
  },
  "anthropic_5h": {
    "detected": false,
    "detected_at": null,
    "resume_at": null,
    "waiting": false
  },
  "paused": false,
  "pause_reason": null,
  "paused_at": null
}
```

## Persistence

```yaml
persistence:
  location: .prp-session/rate-limit.json
  scope: per-project
  format: JSON
  operations:
    read: before each API call
    write: after each call increment and state change
```

## Integration Points

### Before Each Agent Spawn

```yaml
pre_spawn_check:
  1. load: rate_state from .prp-session/rate-limit.json
  2. check_5h:
     if anthropic_5h.waiting AND now() < resume_at:
       wait: resume_at - now()
       continue: after wait
  3. check_hourly:
     if calls_made >= limit:
       pause: true
       notify: countdown message
       wait_for_user: true
  4. proceed: if all checks pass
```

### After Each Agent Response

```yaml
post_response:
  1. increment: calls_made += 1
  2. check_response:
     if error indicates 5h limit:
       set: anthropic_5h.detected = true
       set: anthropic_5h.detected_at = now()
       set: anthropic_5h.resume_at = now() + 60 minutes
       set: anthropic_5h.waiting = true
  3. save: rate_state to file
```

## User Override Options

```yaml
override_hourly:
  trigger: user selects [C]ontinue
  warning: "Continuing may result in API errors. Are you sure?"
  action:
    - if confirmed:
        reset: calls_made = 0
        continue: true
    - else:
        wait: for reset

force_abort:
  trigger: user selects [A]bort
  action:
    - save: current state
    - exit: with message
    - preserve: session for resume
```

## Status Display

```
📊 RATE LIMIT STATUS
====================
Hourly:     45/100 calls (55 remaining)
Window:     Started 32m ago, resets in 28m
5h Limit:   Not detected
Status:     ✅ ACTIVE

-- OR if paused --

📊 RATE LIMIT STATUS
====================
Hourly:     100/100 calls (LIMIT REACHED)
Window:     Resets in 12m 34s
5h Limit:   Not detected
Status:     ⏸️ PAUSED - Waiting for reset

-- OR if 5h limit --

📊 RATE LIMIT STATUS
====================
Hourly:     N/A (5h limit active)
5h Limit:   Detected at 10:30
Resume at:  11:30 (in 45m 20s)
Status:     🚫 RATE_LIMITED - Auto-waiting
```

## Best Practices

1. **Check BEFORE action**: Always verify rate limits before spawning agents
2. **Increment AFTER action**: Count the call after it completes
3. **Persist immediately**: Write state after every change
4. **Respect auto-wait**: Don't override 5h limit auto-wait
5. **Log rate events**: Keep history for debugging
6. **Per-project scope**: Each project has independent tracking

## Error Handling

### Window Corruption

```yaml
if window_start > now() OR next_reset < window_start:
  # Time corruption detected
  reset:
    window_start: now()
    next_reset: now() + 60 minutes
    calls_made: 0
  log: "Rate limit window reset due to corruption"
```

### State File Missing

```yaml
if not exists .prp-session/rate-limit.json:
  create: new state with defaults
  log: "Initialized new rate limit state"
```

---

*Rate Limit Specification v1.0.0*
*Inspired by Ralph for Claude Code API protection*
