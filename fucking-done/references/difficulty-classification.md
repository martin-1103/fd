# Difficulty Classification

Phase difficulty classification for adaptive workflow. Based on DAAO (arxiv:2509.11079).

## Why Classify Difficulty

Not all phases need the full pipeline. Simple config changes don't need research. Complex architecture needs full research + plan checking. Adaptive workflow saves tokens and time.

## Classification Criteria

### Simple
- ≤2 tasks expected
- Config, docs, or single-file changes
- No new dependencies
- Uses only existing patterns
- Examples: add env variable, update README, modify config schema

**Workflow**: Plan only (skip research, skip plan-check)
**Executors**: 1
**Model profile**: budget (if adaptive)

### Moderate
- 3-5 tasks expected
- Multi-file feature using existing patterns
- May add 1-2 new dependencies
- Clear implementation path
- Examples: add new API endpoint, create UI component, add database migration

**Workflow**: Plan + plan-check (skip research)
**Executors**: 2
**Model profile**: balanced (if adaptive)

### Complex
- 6+ tasks expected
- New architecture or patterns
- Multiple new dependencies
- Multiple integrations needed
- Unfamiliar domain or technology
- Examples: auth system, payment integration, real-time features, new service layer

**Workflow**: Full pipeline (research → plan → plan-check)
**Executors**: max_parallel from config
**Model profile**: quality (if adaptive)

## Classification Heuristics

The lead agent classifies phases in Phase 2 (Scan) using:

1. **Task count estimate**: Read phase goal from ROADMAP.md, estimate task count
2. **Dependency depth**: How many prior phases does this depend on?
3. **New tech signal**: Does the phase goal mention technologies not in the current stack?
4. **Scope keywords**: "integrate", "architect", "redesign" → complex. "add", "update", "fix" → simple/moderate.
5. **CONTEXT.md complexity**: If discuss-phase produced many decisions → likely complex

## Config

In `.fd/config.json`:
```json
"workflow": {
  "difficulty_aware": true
}
```

When `difficulty_aware: false`, all phases get the full pipeline (backward compatible).

## Override

Per-phase overrides in ROADMAP.md phase description:
```markdown
### Phase 3: Add API endpoint
<!-- difficulty: simple -->
```

If present, this overrides automatic classification.
