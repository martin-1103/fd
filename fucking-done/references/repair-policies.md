# Repair Policies

Repair policies control how FD handles failures during execution and gap closure. Based on transactional repair patterns from ALAS (arxiv:2511.03094).

## Policy Configuration

In `.planning/config.json`:
```json
"repair": {
  "max_retries": 2,
  "backoff": "none",
  "timeout_minutes": 30,
  "idempotency": true,
  "max_edit_radius": 10
}
```

| Policy | Default | Description |
|--------|---------|-------------|
| `max_retries` | 2 | Max retry attempts per failed task before marking as permanent failure |
| `backoff` | `"none"` | Delay strategy between retries: `"none"`, `"linear"` (30s increments), `"exponential"` (30s, 60s, 120s) |
| `timeout_minutes` | 30 | Max minutes a task can be in_progress before considered stuck |
| `idempotency` | true | Check if task output already exists before re-executing |
| `max_edit_radius` | 10 | Max files a gap closure plan should touch (localized repair) |

## Retry Flow

```
task_fails:
  1. Check retry count < max_retries
  2. If idempotency=true: check if SUMMARY.md already exists (task done by other means)
  3. Apply backoff delay
  4. Reset task: TaskUpdate(status=pending, owner="")
  5. Available executor picks it up
  6. If max_retries exhausted: mark as permanent_failure, log for gap closure
```

## Idempotency Check

Before executing any task, executor checks:
1. Does SUMMARY.md for this plan already exist in phase directory?
2. Does git log contain commits with this plan_id?
3. If yes to either: mark task complete, skip execution

This prevents duplicate work when:
- Task was completed but status wasn't updated (executor crashed)
- Task was reassigned after timeout but original executor finished

## Timeout Detection

Lead monitors task durations:
```
For each in_progress task:
  elapsed = now - task.claimed_at
  if elapsed > timeout_minutes:
    Log: "Task {id} timed out after {elapsed}min"
    Reset task (follows retry flow)
```

## Localized Repair (Gap Closure)

When gap closure is needed, repair is localized:
1. Parse VERIFICATION.md for specific failed items
2. Each gap has: repair_hint, affected_files, estimated_effort
3. Gap closure plan touches ONLY affected_files (max_edit_radius constraint)
4. If repair needs more files than max_edit_radius: flag as architectural concern

Benefits vs global recompute:
- 60% fewer tokens used (ALAS paper benchmark)
- Preserves working code that passed verification
- Targeted fixes = less regression risk
