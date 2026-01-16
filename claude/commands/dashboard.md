---
description: Display real-time autonomous loop status dashboard with metrics, Circuit Breaker state, and rate limits
argument-hint: []
allowed-tools: Read, Bash, Glob
---

# Dashboard Command

Display the current status of autonomous loop execution including:
- Loop state and phase progress
- Circuit Breaker status
- Rate limit tracking
- Recent activity and metrics

## Execution

Read and display all `.prp-session/` state files in a formatted dashboard.

## Dashboard Layout

```
╔══════════════════════════════════════════════════════════════════════════╗
║                         BP AUTONOMOUS DASHBOARD                           ║
╠══════════════════════════════════════════════════════════════════════════╣
║                                                                           ║
║  📋 SESSION INFO                                                         ║
║  ├── Session ID:    a1b2c3d4-e5f6-7890-abcd-ef1234567890                ║
║  ├── PRP:           docs/PRPs/2026-01-16-feature.md                     ║
║  ├── Started:       2026-01-16 10:00:00 (-03:00)                        ║
║  ├── Last Activity: 2026-01-16 10:45:00 (15 min ago)                    ║
║  └── Status:        🟢 RUNNING                                          ║
║                                                                           ║
║  🔄 LOOP STATE                                                           ║
║  ├── Current Phase:   GREEN 🟢                                          ║
║  ├── Iteration:       5                                                 ║
║  ├── Phases Complete: RED ✅                                            ║
║  └── Overall Progress: ████████████░░░░░░░░ 60%                         ║
║                                                                           ║
║  📊 CURRENT METRICS (GREEN)                                              ║
║  ├── Tests Total:     10                                                ║
║  ├── Tests Passing:   6                                                 ║
║  ├── Tests Failing:   4                                                 ║
║  ├── Consecutive Runs: 0                                                ║
║  ├── Files Created:   3                                                 ║
║  └── Files Modified:  2                                                 ║
║                                                                           ║
║  🔌 CIRCUIT BREAKER                                                      ║
║  ├── State:           CLOSED ✅                                         ║
║  ├── No-Progress:     0 / 2 (GREEN threshold)                          ║
║  └── Same-Error:      0 / 3 (GREEN threshold)                          ║
║                                                                           ║
║  ⏱️ RATE LIMIT                                                           ║
║  ├── Hourly:          45/100 calls (55 remaining)                       ║
║  ├── Window Reset:    In 28m 15s                                        ║
║  ├── 5h Limit:        Not detected ✅                                   ║
║  └── Status:          ACTIVE                                            ║
║                                                                           ║
║  📜 RECENT ACTIVITY (last 5)                                            ║
║  ├── 10:45 - GREEN iter 5: tests_passing 5→6                           ║
║  ├── 10:42 - GREEN iter 4: tests_passing 4→5                           ║
║  ├── 10:38 - GREEN iter 3: tests_passing 3→4                           ║
║  ├── 10:33 - GREEN iter 2: tests_passing 2→3                           ║
║  └── 10:28 - GREEN iter 1: tests_passing 0→2                           ║
║                                                                           ║
╚══════════════════════════════════════════════════════════════════════════╝
```

## Implementation

### Step 1: Check Session Exists

```bash
if [ ! -d ".prp-session" ]; then
  echo "No active session found."
  echo "Start autonomous execution with: /bp:autonomous <prp-file>"
  exit 0
fi
```

### Step 2: Load State Files

```yaml
files_to_read:
  - .prp-session/loop-state.json
  - .prp-session/circuit-breaker.json
  - .prp-session/rate-limit.json
  - .prp-session/metrics.json
  - .prp-session/dual-gate.json (optional)
  - .prp-session/phase-status.log (last 5 entries)
```

### Step 3: Format Display

Parse JSON files and format into dashboard display.

## Status Indicators

### Session Status

| Status | Indicator | Description |
|--------|-----------|-------------|
| running | 🟢 RUNNING | Active execution in progress |
| paused | ⏸️ PAUSED | Temporarily stopped, resumable |
| completed | ✅ COMPLETED | All phases finished |
| halted | 🛑 HALTED | Stopped by Circuit Breaker |

### Phase Status

| Phase | Indicator | Description |
|-------|-----------|-------------|
| RED | 🔴 | Test generation phase |
| GREEN | 🟢 | Implementation phase |
| REFACTOR | 🔵 | Code quality improvement |
| DOCUMENT | 📚 | Documentation generation |

### Circuit Breaker

| State | Indicator | Description |
|-------|-----------|-------------|
| CLOSED | ✅ CLOSED | Normal operation |
| HALF_OPEN | ⚠️ HALF_OPEN | Monitoring for progress |
| OPEN | 🛑 OPEN | Execution halted |

### Rate Limit

| State | Indicator | Description |
|-------|-----------|-------------|
| ACTIVE | ✅ ACTIVE | Under limit, ok to proceed |
| PAUSED | ⏸️ PAUSED | Hourly limit reached |
| RATE_LIMITED | 🚫 5H_LIMIT | Anthropic limit detected |

## Alternate Displays

### No Active Session

```
╔══════════════════════════════════════════════════════════════╗
║                    BP AUTONOMOUS DASHBOARD                    ║
╠══════════════════════════════════════════════════════════════╣
║                                                               ║
║  ⚪ NO ACTIVE SESSION                                         ║
║                                                               ║
║  Start autonomous execution with:                            ║
║  /bp:autonomous <path/to/prp-file.md>                       ║
║                                                               ║
║  Or run manual execution with:                               ║
║  /bp:execute-prp <path/to/prp-file.md>                      ║
║                                                               ║
╚══════════════════════════════════════════════════════════════╝
```

### Paused Session

```
╔══════════════════════════════════════════════════════════════╗
║                    BP AUTONOMOUS DASHBOARD                    ║
╠══════════════════════════════════════════════════════════════╣
║                                                               ║
║  ⏸️ SESSION PAUSED                                            ║
║                                                               ║
║  Session ID:    a1b2c3d4-...                                 ║
║  PRP:           feature.md                                   ║
║  Phase:         GREEN (iteration 5)                          ║
║  Paused At:     2026-01-16 10:45:00                         ║
║  Reason:        User interrupt                               ║
║                                                               ║
║  Progress: 6/10 tests passing (60%)                          ║
║                                                               ║
║  Resume with:                                                ║
║  /bp:autonomous docs/PRPs/feature.md                        ║
║                                                               ║
╚══════════════════════════════════════════════════════════════╝
```

### Circuit Breaker Open

```
╔══════════════════════════════════════════════════════════════╗
║                    BP AUTONOMOUS DASHBOARD                    ║
╠══════════════════════════════════════════════════════════════╣
║                                                               ║
║  🛑 CIRCUIT BREAKER OPEN                                      ║
║                                                               ║
║  Session ID:    a1b2c3d4-...                                 ║
║  Phase:         GREEN                                        ║
║  Iteration:     7                                            ║
║                                                               ║
║  Reason:        No progress for 2 iterations                 ║
║  Opened At:     2026-01-16 10:45:00                         ║
║                                                               ║
║  Tests:         6/10 passing (no change)                     ║
║  Last Error:    TypeError: Cannot read property 'x'          ║
║                                                               ║
║  Options:                                                    ║
║  - Reset:  /bp:autonomous --reset <prp-file>                ║
║  - Review: Check test failures and implementation           ║
║                                                               ║
╚══════════════════════════════════════════════════════════════╝
```

### Rate Limited

```
╔══════════════════════════════════════════════════════════════╗
║                    BP AUTONOMOUS DASHBOARD                    ║
╠══════════════════════════════════════════════════════════════╣
║                                                               ║
║  ⏸️ RATE LIMIT REACHED                                        ║
║                                                               ║
║  Session:       a1b2c3d4-...                                 ║
║  Phase:         GREEN (iteration 5)                          ║
║                                                               ║
║  Hourly Limit:  100/100 calls                                ║
║  Reset In:      23m 45s                                      ║
║                                                               ║
║  Session will auto-resume when limit resets.                 ║
║                                                               ║
╚══════════════════════════════════════════════════════════════╝
```

## Data Sources

### loop-state.json

```json
{
  "session_id": "uuid",
  "prp_file": "path",
  "started_at": "ISO-8601",
  "current_phase": "GREEN",
  "current_iteration": 5,
  "last_activity": "ISO-8601",
  "status": "running",
  "phases_completed": ["RED"]
}
```

### circuit-breaker.json

```json
{
  "state": "CLOSED",
  "no_progress_count": 0,
  "same_error_count": 0,
  "open_reason": null
}
```

### rate-limit.json

```json
{
  "hourly": {
    "calls_made": 45,
    "limit": 100,
    "next_reset": "ISO-8601"
  },
  "anthropic_5h": {
    "detected": false,
    "waiting": false
  }
}
```

### metrics.json

```json
{
  "current_phase": "GREEN",
  "phases": {
    "GREEN": {
      "current_metrics": {
        "tests_total": 10,
        "tests_passing": 6,
        "tests_failing": 4
      }
    }
  }
}
```

## Usage

```bash
# Show dashboard
/bp:dashboard

# Dashboard is read-only - displays current state
# To control execution, use:
# - /bp:autonomous <prp> to start/resume
# - MCP tools pause-loop/resume-loop for remote control
```

## Related Commands

- `/bp:autonomous` - Start/resume autonomous execution
- `/bp:execute-prp` - Manual PRP execution
- MCP Resources for external access (bp://dashboard/*)

---

*Dashboard Command v1.0.0*
*Real-time autonomous loop monitoring*
