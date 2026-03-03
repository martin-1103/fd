<planning_config>

Configuration options for `.fd/planning/` directory behavior.

<config_schema>
```json
"planning": {
  "commit_docs": true,
  "search_gitignored": false
},
"git": {
  "branching_strategy": "none",
  "phase_branch_template": "fd/phase-{phase}-{slug}",
  "milestone_branch_template": "fd/{milestone}-{slug}"
},
"worktree": {
  "enabled": true,
  "base_path": ".claude/worktrees",
  "feature_branch_template": "fd/feature-{slug}",
  "fix_branch_template": "fd/fix-{slug}",
  "auto_cleanup": false
}
```

| Option | Default | Description |
|--------|---------|-------------|
| `commit_docs` | `true` | Whether to commit planning artifacts to git |
| `search_gitignored` | `false` | Add `--no-ignore` to broad rg searches |
| `git.branching_strategy` | `"none"` | Git branching approach: `"none"`, `"phase"`, or `"milestone"` |
| `git.phase_branch_template` | `"fd/phase-{phase}-{slug}"` | Branch template for phase strategy |
| `git.milestone_branch_template` | `"fd/{milestone}-{slug}"` | Branch template for milestone strategy |
| `worktree.enabled` | `true` | Whether /fd:run and /fd:fix create isolated worktrees |
| `worktree.base_path` | `".claude/worktrees"` | Base directory for worktrees |
| `worktree.feature_branch_template` | `"fd/feature-{slug}"` | Branch template for feature worktrees |
| `worktree.fix_branch_template` | `"fd/fix-{slug}"` | Branch template for fix worktrees |
| `worktree.auto_cleanup` | `false` | Whether to auto-remove worktree after merge |
</config_schema>

<commit_docs_behavior>

**When `commit_docs: true` (default):**
- Planning files committed normally
- SUMMARY.md, STATE.md, ROADMAP.md tracked in git
- Full history of planning decisions preserved

**When `commit_docs: false`:**
- Skip all `git add`/`git commit` for `.fd/planning/` files
- User must add `.fd/planning/` to `.gitignore`
- Useful for: OSS contributions, client projects, keeping planning private

**Checking the config:**

```bash
# Check config.json first
COMMIT_DOCS=$(cat .fd/config.json 2>/dev/null | grep -o '"commit_docs"[[:space:]]*:[[:space:]]*[^,}]*' | grep -o 'true\|false' || echo "true")

# Auto-detect gitignored (overrides config)
git check-ignore -q .fd/planning 2>/dev/null && COMMIT_DOCS=false
```

**Auto-detection:** If `.fd/planning/` is gitignored, `commit_docs` is automatically `false` regardless of config.json. This prevents git errors when users have `.fd/planning/` in `.gitignore`.

**Conditional git operations:**

```bash
if [ "$COMMIT_DOCS" = "true" ]; then
  git add .fd/planning/STATE.md
  git commit -m "docs: update state"
fi
```

</commit_docs_behavior>

<search_behavior>

**When `search_gitignored: false` (default):**
- Standard rg behavior (respects .gitignore)
- Direct path searches work: `rg "pattern" .fd/planning/` finds files
- Broad searches skip gitignored: `rg "pattern"` skips `.fd/planning/`

**When `search_gitignored: true`:**
- Add `--no-ignore` to broad rg searches that should include `.fd/planning/`
- Only needed when searching entire repo and expecting `.fd/planning/` matches

**Note:** Most FD operations use direct file reads or explicit paths, which work regardless of gitignore status.

</search_behavior>

<setup_uncommitted_mode>

To use uncommitted mode:

1. **Set config:**
   ```json
   "planning": {
     "commit_docs": false,
     "search_gitignored": true
   }
   ```

2. **Add to .gitignore:**
   ```
   .fd/planning/
   ```

3. **Existing tracked files:** If `.fd/planning/` was previously tracked:
   ```bash
   git rm -r --cached .fd/planning/
   git commit -m "chore: stop tracking planning docs"
   ```

</setup_uncommitted_mode>

<branching_strategy_behavior>

**Branching Strategies:**

| Strategy | When branch created | Branch scope | Merge point |
|----------|---------------------|--------------|-------------|
| `none` | Never | N/A | N/A |
| `phase` | At `execute-phase` start | Single phase | User merges after phase |
| `milestone` | At first `execute-phase` of milestone | Entire milestone | At `complete-milestone` |

**When `git.branching_strategy: "none"` (default):**
- All work commits to current branch
- Standard FD behavior

**When `git.branching_strategy: "phase"`:**
- `execute-phase` creates/switches to a branch before execution
- Branch name from `phase_branch_template` (e.g., `fd/phase-03-authentication`)
- All plan commits go to that branch
- User merges branches manually after phase completion
- `complete-milestone` offers to merge all phase branches

**When `git.branching_strategy: "milestone"`:**
- First `execute-phase` of milestone creates the milestone branch
- Branch name from `milestone_branch_template` (e.g., `fd/v1.0-mvp`)
- All phases in milestone commit to same branch
- `complete-milestone` offers to merge milestone branch to main

**Template variables:**

| Variable | Available in | Description |
|----------|--------------|-------------|
| `{phase}` | phase_branch_template | Zero-padded phase number (e.g., "03") |
| `{slug}` | Both | Lowercase, hyphenated name |
| `{milestone}` | milestone_branch_template | Milestone version (e.g., "v1.0") |

**Checking the config:**

```bash
# Get branching strategy (default: none)
BRANCHING_STRATEGY=$(cat .fd/config.json 2>/dev/null | grep -o '"branching_strategy"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*:.*"\([^"]*\)"/\1/' || echo "none")

# Get phase branch template
PHASE_BRANCH_TEMPLATE=$(cat .fd/config.json 2>/dev/null | grep -o '"phase_branch_template"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*:.*"\([^"]*\)"/\1/' || echo "fd/phase-{phase}-{slug}")

# Get milestone branch template
MILESTONE_BRANCH_TEMPLATE=$(cat .fd/config.json 2>/dev/null | grep -o '"milestone_branch_template"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*:.*"\([^"]*\)"/\1/' || echo "fd/{milestone}-{slug}")
```

**Branch creation:**

```bash
# For phase strategy
if [ "$BRANCHING_STRATEGY" = "phase" ]; then
  PHASE_SLUG=$(echo "$PHASE_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//')
  BRANCH_NAME=$(echo "$PHASE_BRANCH_TEMPLATE" | sed "s/{phase}/$PADDED_PHASE/g" | sed "s/{slug}/$PHASE_SLUG/g")
  git checkout -b "$BRANCH_NAME" 2>/dev/null || git checkout "$BRANCH_NAME"
fi

# For milestone strategy
if [ "$BRANCHING_STRATEGY" = "milestone" ]; then
  MILESTONE_SLUG=$(echo "$MILESTONE_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//')
  BRANCH_NAME=$(echo "$MILESTONE_BRANCH_TEMPLATE" | sed "s/{milestone}/$MILESTONE_VERSION/g" | sed "s/{slug}/$MILESTONE_SLUG/g")
  git checkout -b "$BRANCH_NAME" 2>/dev/null || git checkout "$BRANCH_NAME"
fi
```

**Merge options at complete-milestone:**

| Option | Git command | Result |
|--------|-------------|--------|
| Squash merge (recommended) | `git merge --squash` | Single clean commit per branch |
| Merge with history | `git merge --no-ff` | Preserves all individual commits |
| Delete without merging | `git branch -D` | Discard branch work |
| Keep branches | (none) | Manual handling later |

Squash merge is recommended — keeps main branch history clean while preserving the full development history in the branch (until deleted).

**Use cases:**

| Strategy | Best for |
|----------|----------|
| `none` | Solo development, simple projects |
| `phase` | Code review per phase, granular rollback, team collaboration |
| `milestone` | Release branches, staging environments, PR per version |

</branching_strategy_behavior>

<agent_team_config>

Agent Team configuration in `.fd/config.json`:

```json
"agent_team": {
  "lead_model": "opus",
  "teammate_model": "sonnet",
  "max_gap_loops": 3,
  "max_parallel": 4,
  "isolation": "shared"
}
```

| Option | Default | Description |
|--------|---------|-------------|
| `lead_model` | `"opus"` | Model for lead agent |
| `teammate_model` | `"sonnet"` | Model for executor teammates |
| `max_gap_loops` | `3` | Maximum gap closure iterations |
| `max_parallel` | `4` | Maximum concurrent executor teammates |
| `isolation` | `"shared"` | Workspace isolation: `"shared"` (same git workspace) or `"worktree"` (git worktree per executor) |

</agent_team_config>

<repair_config>

Repair policy configuration:

```json
"repair": {
  "max_retries": 2,
  "backoff": "none",
  "timeout_minutes": 30,
  "idempotency": true,
  "max_edit_radius": 10
}
```

| Option | Default | Description |
|--------|---------|-------------|
| `max_retries` | `2` | Max retry attempts per failed task |
| `backoff` | `"none"` | Retry delay: `"none"`, `"linear"`, `"exponential"` |
| `timeout_minutes` | `30` | Max task execution time before timeout |
| `idempotency` | `true` | Check existing output before re-executing |
| `max_edit_radius` | `10` | Max files gap closure can touch |

See `references/repair-policies.md` for detailed policy documentation.

</repair_config>

<workflow_config>

Extended workflow configuration:

```json
"workflow": {
  "research": true,
  "plan_check": true,
  "verifier": true,
  "difficulty_aware": true
}
```

| Option | Default | Description |
|--------|---------|-------------|
| `difficulty_aware` | `true` | Classify phase difficulty and adapt pipeline depth |

When `difficulty_aware: true`:
- Simple phases skip research AND plan-check
- Moderate phases skip research only
- Complex phases get full pipeline

See `references/difficulty-classification.md` for classification criteria.

</workflow_config>

<model_adaptive_config>

Model profile "adaptive" mode:

```json
"model_profile": "adaptive"
```

When set to `"adaptive"`, model selection is based on phase difficulty:
- Simple phases → budget profile
- Moderate phases → balanced profile
- Complex phases → quality profile

See `references/model-profiles.md` for profile definitions.

</model_adaptive_config>

<aid_config>

AI Distiller (aid) integration configuration:

```json
"aid": {
  "enabled": true,
  "src_path": "",
  "include": "",
  "exclude": "*test*,*spec*,*.config.*,node_modules",
  "flags": "--public --format md"
}
```

| Option | Default | Description |
|--------|---------|-------------|
| `enabled` | `true` | Whether to run aid codebase distillation during Phase 0 |
| `src_path` | `""` (auto-detect) | Source directory to distill. Empty = auto-detect ("src" if exists, else ".") |
| `include` | `""` (all supported) | File patterns to include (e.g., "*.ts,*.tsx,*.py") |
| `exclude` | `"*test*,*spec*,*.config.*,node_modules"` | File patterns to exclude |
| `flags` | `"--public --format md"` | Extra aid flags for API surface distillation |

**What aid generates:**

Two files in `.fd/codebase/`:

| File | Content | Used by | Size |
|------|---------|---------|------|
| `aid-distilled.md` | Public API surface only (signatures, types, exports) | Planner, researcher, verifier | Compact (60-90% smaller) |
| `aid-full.md` | API surface + implementation bodies | Executors | Larger but complete |

**When aid runs:**
- Phase 0: Initial distillation of entire codebase
- Phase 6.5: Re-distillation after gap closure (codebase changed)

**When aid.enabled: false:**
- All aid steps are skipped
- Agents fall back to grep-based codebase exploration
- No performance penalty, just less upfront context

**Auto-detection:**
If `src_path` is empty, the lead agent checks:
1. Does `src/` directory exist? → use "src"
2. Otherwise → use "." (project root)

**Tip:** For monorepos, set `src_path` to the relevant package directory.

</aid_config>

</planning_config>
