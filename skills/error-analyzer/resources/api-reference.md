# Error Analyzer API Reference

Base URL: `https://e.nuxhub.site`

No authentication required.

## GET /api/stats

Aggregated error metrics across all services.

### Response

| Field | Type | Description |
|-------|------|-------------|
| `total_patterns` | number | Total unique error patterns tracked |
| `total_occurrences` | number | Sum of all error occurrences |
| `by_status` | object | Count per status: `new`, `fixed`, `merged`, `discarded` |
| `by_severity` | object | Count per severity: `critical`, `high`, `medium`, `low` |
| `by_category` | object | Count per category: `bug`, `race_condition`, `config`, `infra`, `dependency`, `expected` |
| `by_service` | array | `[{service_name, count}]` sorted by count descending |
| `trend_7d` | array | `[{date, total_errors}]` last 7 days of error occurrences |
| `cron_schedule` | string | Cron expression for the error collection job |
| `next_run` | string | ISO 8601 timestamp of next scheduled run |

### Example Response

```json
{
  "total_patterns": 35,
  "total_occurrences": 1781,
  "by_status": { "new": 10, "fixed": 5, "merged": 12, "discarded": 8 },
  "by_severity": { "critical": 1, "high": 16, "medium": 7, "low": 2 },
  "by_category": { "bug": 15, "race_condition": 7, "config": 1, "infra": 1, "dependency": 1, "expected": 1 },
  "by_service": [
    { "service_name": "service-channels", "count": 8 },
    { "service_name": "service-core", "count": 7 }
  ],
  "trend_7d": [
    { "date": "2026-02-27", "total_errors": 1781 },
    { "date": "2026-03-03", "total_errors": 63 }
  ],
  "cron_schedule": "0 * * * *",
  "next_run": "2026-03-03T08:00:00.000Z"
}
```

## GET /api/errors/:id

Full error detail. Response can be large (~56KB) due to sample_logs and analysis history.

### Response

| Field | Type | Description |
|-------|------|-------------|
| `id` | number | Unique error pattern ID |
| `service_name` | string | Service that produced the error |
| `project_name` | string | Project/repo name |
| `normalized_pattern` | string | Normalized error message pattern |
| `status` | string | Current status: `new`, `fixed`, `merged`, `discarded`, `regression` |
| `severity` | string | `critical`, `high`, `medium`, `low` |
| `category` | string | `bug`, `race_condition`, `config`, `infra`, `dependency`, `expected` |
| `occurrence_count` | number | Total times this error has occurred |
| `pattern_hash` | string | SHA hash of the normalized pattern |
| `first_seen_at` | string | ISO 8601 timestamp of first occurrence |
| `last_seen_at` | string | ISO 8601 timestamp of most recent occurrence |
| `created_at` | string | ISO 8601 record creation timestamp |
| `updated_at` | string | ISO 8601 record update timestamp |
| `last_analyzed_at` | string | ISO 8601 timestamp of last AI analysis |
| `sample_logs` | array | Raw log entries (can be large) |
| `raw_sample` | string | Original raw error sample |
| `analysis` | object | AI-generated root cause analysis (see below) |
| `analysis_history` | array | Previous analysis versions |
| `fix_plan` | object/null | Fix plan if generated (see `/plan` endpoint) |
| `related_errors` | array | IDs of related error patterns |
| `next_action` | string/null | Suggested next action |
| `avg_count` | number | Average occurrence count per collection window |

### Analysis Object

| Field | Type | Description |
|-------|------|-------------|
| `root_cause` | string | AI-determined root cause explanation |
| `severity` | string | Analysis-determined severity |
| `category` | string | Analysis-determined category |
| `trace` | array | Execution trace leading to the error |
| `related_files` | array | Source files involved |
| `dependencies` | array | Service/package dependencies involved |
| `requires_restart` | boolean | Whether fix requires service restart |
| `config_context` | object/null | Relevant configuration context |
| `error_logs` | array | Key log entries from analysis |

## PATCH /api/errors/:id/status

Update an error pattern's status.

### Request

```json
{ "status": "fixed" }
```

Valid statuses: `new`, `fixed`, `merged`, `discarded`, `regression`

### Response

```json
{ "id": 43, "status": "fixed" }
```

## GET /api/errors/:id/plan

Retrieve the AI-generated fix plan for an error pattern.

### Response

| Field | Type | Description |
|-------|------|-------------|
| `id` | number | Fix plan ID |
| `pattern_id` | number | Associated error pattern ID |
| `analysis_id` | number | Associated analysis ID |
| `summary` | string | One-line description of the fix |
| `approach` | string | High-level fix strategy |
| `rationale` | string | Why this approach was chosen |
| `steps` | array | Ordered fix steps (see below) |
| `verification` | array | Verification checks to confirm fix works |
| `review_log` | array | AI review iterations and feedback |
| `risk_level` | string | `low`, `medium`, `high` |
| `estimated_complexity` | string | `trivial`, `simple`, `moderate`, `complex` |
| `fix_status` | string | `pending`, `applied`, `merged`, `failed` |
| `fix_branch` | string/null | Git branch name if fix was applied |
| `fix_type` | string | Type of fix: `code_change`, `config_change`, etc. |
| `fix_applied_at` | string/null | ISO 8601 when fix was applied |
| `fix_merged_at` | string/null | ISO 8601 when fix was merged |
| `fix_model` | string | AI model used for fix generation |
| `requires_downtime` | boolean | Whether deployment requires downtime |
| `rollback` | string | Rollback instructions |
| `tests_needed` | array | Tests that should be added/verified |
| `services_to_restart` | array | Services needing restart after deploy |
| `similar_issues` | array | References to similar known issues |
| `corrections` | array/null | Corrections made during review |
| `missing_context` | array/null | Context gaps identified during planning |
| `created_at` | string | ISO 8601 plan creation timestamp |

### Step Object

| Field | Type | Description |
|-------|------|-------------|
| `file` | string | File path to modify |
| `action` | string | What to do (e.g., "modify", "create") |
| `description` | string | Detailed description of the change |
| `code_before` | string | Current code (if modifying) |
| `code_after` | string | Target code after fix |

### Verification Object

| Field | Type | Description |
|-------|------|-------------|
| `type` | string | Check type (e.g., "log_check", "test", "manual") |
| `description` | string | What to verify |
| `command` | string/null | Command to run for automated checks |

## GET /api/errors/:id/fix-diff

Plain text unified diff of the applied fix. Only available after a fix has been applied.

### Response

- **200**: Plain text unified diff
- **404**: `{"error": "No applied fix found"}` — no fix has been applied yet
