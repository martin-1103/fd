# Model Profiles

Model profiles control which Claude model each FD agent uses. This allows balancing quality vs token spend.

## Profile Definitions

| Agent | `quality` | `balanced` | `budget` |
|-------|-----------|------------|----------|
| fd-planner | opus | opus | sonnet |
| fd-roadmapper | opus | sonnet | sonnet |
| fd-executor | opus | sonnet | sonnet |
| fd-phase-researcher | opus | sonnet | haiku |
| fd-project-researcher | opus | sonnet | haiku |
| fd-research-synthesizer | sonnet | sonnet | haiku |
| fd-debugger | opus | sonnet | sonnet |
| fd-codebase-mapper | sonnet | haiku | haiku |
| fd-verifier | sonnet | sonnet | haiku |
| fd-plan-checker | sonnet | sonnet | haiku |
| fd-integration-checker | sonnet | sonnet | haiku |

## Profile Philosophy

**quality** - Maximum reasoning power
- Opus for all decision-making agents
- Sonnet for read-only verification
- Use when: quota available, critical architecture work

**balanced** (default) - Smart allocation
- Opus only for planning (where architecture decisions happen)
- Sonnet for execution and research (follows explicit instructions)
- Sonnet for verification (needs reasoning, not just pattern matching)
- Use when: normal development, good balance of quality and cost

**budget** - Minimal Opus usage
- Sonnet for anything that writes code
- Haiku for research and verification
- Use when: conserving quota, high-volume work, less critical phases

## Resolution Logic

Orchestrators resolve model before spawning:

```
1. Read .planning/config.json
2. Get model_profile (default: "balanced")
3. Look up agent in table above
4. Pass model parameter to Task call
```

## Switching Profiles

Runtime: `/fd:set-profile <profile>`

Per-project default: Set in `.planning/config.json`:
```json
{
  "model_profile": "balanced"
}
```

## Design Rationale

**Why Opus for fd-planner?**
Planning involves architecture decisions, goal decomposition, and task design. This is where model quality has the highest impact.

**Why Sonnet for fd-executor?**
Executors follow explicit PLAN.md instructions. The plan already contains the reasoning; execution is implementation.

**Why Sonnet (not Haiku) for verifiers in balanced?**
Verification requires goal-backward reasoning - checking if code *delivers* what the phase promised, not just pattern matching. Sonnet handles this well; Haiku may miss subtle gaps.

**Why Haiku for fd-codebase-mapper?**
Read-only exploration and pattern extraction. No reasoning required, just structured output from file contents.

## Adaptive Profile

When `model_profile: "adaptive"` in config.json, the profile is selected per-phase based on difficulty:

| Phase Difficulty | Profile Used | Rationale |
|-----------------|-------------|-----------|
| simple | budget | Config/docs changes don't need Opus reasoning |
| moderate | balanced | Standard features need good planning, efficient execution |
| complex | quality | Architecture decisions need maximum reasoning power |

This is the most cost-effective mode — it automatically allocates expensive models only where reasoning complexity demands it.

### How it works

1. Lead classifies each phase's difficulty in Phase 2 (Scan)
2. When spawning agents for a phase, lead resolves: `adaptive` → difficulty → profile → model
3. All agents for that phase use the resolved profile

### Override

Per-phase override in ROADMAP.md: `<!-- difficulty: complex -->` forces quality profile regardless of automatic classification.
