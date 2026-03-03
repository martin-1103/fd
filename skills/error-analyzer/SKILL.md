---
name: error-analyzer
description: "Query production errors, view root cause analyses, review fix plans, and update error statuses from the Error Analyzer at e.nuxhub.site. Use when user asks about production errors, error stats, fix plans, error diffs, or wants to update error status."
---

# Error Analyzer

Query and manage production errors from the Error Analyzer system at `https://e.nuxhub.site`. No authentication required.

## Commands

### Stats — Overview of all errors

```bash
~/.claude/skills/error-analyzer/scripts/ea.sh stats
```

**Interpretation**: Summarize in natural language:
- Active error count (excluding merged/discarded)
- Highlight critical and high severity counts
- Trend direction (increasing/decreasing/stable based on trend_7d)
- Top services by error count

### Show — Full error detail

```bash
~/.claude/skills/error-analyzer/scripts/ea.sh show <id>
```

**Interpretation**: Present as structured prose — do NOT dump the full JSON. Extract and summarize:
- Service, project, severity, category, status
- Normalized pattern (the error message)
- Root cause from `analysis.root_cause`
- Occurrence count and time range (first_seen → last_seen)
- Related files from `analysis.related_files`
- Next action if present

### Update — Change error status

```bash
~/.claude/skills/error-analyzer/scripts/ea.sh update <id> <status>
```

Valid statuses: `new`, `fixed`, `merged`, `discarded`, `regression`

**Interpretation**: Confirm the status change with "Error #ID status updated: old_status → new_status"

### Plan — View fix plan

```bash
~/.claude/skills/error-analyzer/scripts/ea.sh plan <id>
```

**Interpretation**: Present actionably:
- Summary (one line)
- Approach and rationale
- Steps as a numbered list with file paths and descriptions
- Risk level and estimated complexity
- Verification steps as a checklist
- Fix status (pending/applied/merged/failed) and branch name if available

### Diff — View applied fix diff

```bash
~/.claude/skills/error-analyzer/scripts/ea.sh diff <id>
```

**Interpretation**: Display in a code block with diff syntax highlighting. If 404 (no fix applied), say "No applied fix diff available for this error."

## Error Handling

The script outputs errors as `{"error": "message"}` to stderr. Present error messages plainly to the user without the JSON wrapper.

## API Reference

For full response schemas, see `resources/api-reference.md` in this skill directory.
