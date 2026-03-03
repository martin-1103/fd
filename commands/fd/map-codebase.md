---
name: fd:map-codebase
description: Analyze codebase with parallel mapper agents to produce structured codebase documents
allowed-tools:
  - Read
  - Bash
  - Glob
  - Grep
  - Write
  - Task
  - TaskOutput
  - AskUserQuestion
---

<objective>
Analyze existing codebase using parallel fd-codebase-mapper agents to produce structured codebase documents.

Each mapper agent explores a focus area and **writes documents directly** to `.fd/codebase/`. The orchestrator only receives confirmations, keeping context usage minimal.

Output: `.fd/codebase/` folder with 7 structured documents about the codebase state.
</objective>

<execution_context>
@/root/.claude/fucking-done/references/ui-brand.md
</execution_context>

<process>

## Step 1: Validate Environment

```bash
# Ensure .fd/ directory exists or will be created
[ -d ".fd" ] || echo "NOTE: .fd/ not found. Will create it."
```

## Step 2: Check Existing Codebase Map

```bash
ls .fd/codebase/*.md 2>/dev/null | wc -l
```

**If codebase documents already exist:**

Use AskUserQuestion:
- header: "Codebase Map"
- question: "Codebase map already exists. What would you like to do?"
- options:
  - "Refresh" — Re-analyze and overwrite existing documents
  - "Skip" — Keep existing documents, do nothing

If "Skip" → Display "Keeping existing codebase map." and STOP.
If "Refresh" → Continue to Step 3.

## Step 3: Create Directory & Resolve Model

```bash
mkdir -p .fd/codebase
```

**Read model profile from config (if exists):**

```bash
MODEL_PROFILE=$(cat .fd/config.json 2>/dev/null | grep -o '"model_profile"[[:space:]]*:[[:space:]]*"[^"]*"' | grep -o '"[^"]*"$' | tr -d '"' || echo "balanced")
```

**Model lookup for fd-codebase-mapper:**

| quality | balanced | budget |
|---------|----------|--------|
| sonnet  | sonnet   | haiku  |

## Step 4: Spawn 4 Parallel Mapper Agents

Display spawning indicator:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  FD ► MAPPING CODEBASE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

◆ Spawning 4 mapper agents in parallel...
  → Tech (STACK.md, INTEGRATIONS.md)
  → Architecture (ARCHITECTURE.md, STRUCTURE.md)
  → Quality (CONVENTIONS.md, TESTING.md)
  → Concerns (CONCERNS.md)
```

Spawn all 4 agents in a **single message** with `run_in_background=true`:

```
bg_tech = Task(
  prompt="First, read /root/.claude/agents/fd-codebase-mapper.md for your role and instructions.

FOCUS: tech
CODEBASE_DIR: .fd/codebase

Write STACK.md and INTEGRATIONS.md to .fd/codebase/.

Return only a brief confirmation with file names and line counts.",
  description="Map codebase: tech",
  subagent_type="fd-codebase-mapper",
  model="{mapper_model}",
  run_in_background=true
)

bg_arch = Task(
  prompt="First, read /root/.claude/agents/fd-codebase-mapper.md for your role and instructions.

FOCUS: arch
CODEBASE_DIR: .fd/codebase

Write ARCHITECTURE.md and STRUCTURE.md to .fd/codebase/.

Return only a brief confirmation with file names and line counts.",
  description="Map codebase: arch",
  subagent_type="fd-codebase-mapper",
  model="{mapper_model}",
  run_in_background=true
)

bg_quality = Task(
  prompt="First, read /root/.claude/agents/fd-codebase-mapper.md for your role and instructions.

FOCUS: quality
CODEBASE_DIR: .fd/codebase

Write CONVENTIONS.md and TESTING.md to .fd/codebase/.

Return only a brief confirmation with file names and line counts.",
  description="Map codebase: quality",
  subagent_type="fd-codebase-mapper",
  model="{mapper_model}",
  run_in_background=true
)

bg_concerns = Task(
  prompt="First, read /root/.claude/agents/fd-codebase-mapper.md for your role and instructions.

FOCUS: concerns
CODEBASE_DIR: .fd/codebase

Write CONCERNS.md to .fd/codebase/.

Return only a brief confirmation with file names and line counts.",
  description="Map codebase: concerns",
  subagent_type="fd-codebase-mapper",
  model="{mapper_model}",
  run_in_background=true
)
```

## Step 5: Wait for All Agents

Wait for each agent to complete:

```
TaskOutput(task_id=bg_tech.task_id, block=true, timeout=300000)
TaskOutput(task_id=bg_arch.task_id, block=true, timeout=300000)
TaskOutput(task_id=bg_quality.task_id, block=true, timeout=300000)
TaskOutput(task_id=bg_concerns.task_id, block=true, timeout=300000)
```

Display progress as each completes:
```
✓ Tech mapper complete
✓ Architecture mapper complete
✓ Quality mapper complete
✓ Concerns mapper complete
```

## Step 6: Verify All 7 Documents

```bash
for doc in STACK INTEGRATIONS ARCHITECTURE STRUCTURE CONVENTIONS TESTING CONCERNS; do
  f=".fd/codebase/${doc}.md"
  if [ -f "$f" ]; then
    lines=$(wc -l < "$f")
    if [ "$lines" -gt 20 ]; then
      echo "OK: ${doc}.md ($lines lines)"
    else
      echo "WARN: ${doc}.md only $lines lines (expected >20)"
    fi
  else
    echo "MISSING: ${doc}.md"
  fi
done
```

If any documents are MISSING, report the error and suggest re-running.

## Step 7: Commit (if enabled)

```bash
COMMIT_DOCS=$(cat .fd/config.json 2>/dev/null | grep -o '"commit_docs"[[:space:]]*:[[:space:]]*[^,}]*' | grep -o 'true\|false' || echo "true")
```

**If commit_docs is true:**

```bash
git add .fd/codebase/STACK.md \
       .fd/codebase/INTEGRATIONS.md \
       .fd/codebase/ARCHITECTURE.md \
       .fd/codebase/STRUCTURE.md \
       .fd/codebase/CONVENTIONS.md \
       .fd/codebase/TESTING.md \
       .fd/codebase/CONCERNS.md
git commit -m "$(cat <<'EOF'
docs: map codebase (7 documents)

Tech: STACK.md, INTEGRATIONS.md
Architecture: ARCHITECTURE.md, STRUCTURE.md
Quality: CONVENTIONS.md, TESTING.md
Concerns: CONCERNS.md
EOF
)"
```

## Step 8: Display Completion Summary

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  FD ► CODEBASE MAPPED ✓
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

| Document         | Lines | Status |
|------------------|-------|--------|
| STACK.md         | {N}   | ✓      |
| INTEGRATIONS.md  | {N}   | ✓      |
| ARCHITECTURE.md  | {N}   | ✓      |
| STRUCTURE.md     | {N}   | ✓      |
| CONVENTIONS.md   | {N}   | ✓      |
| TESTING.md       | {N}   | ✓      |
| CONCERNS.md      | {N}   | ✓      |

Location: `.fd/codebase/`

───────────────────────────────────────────────────────

## ▶ Next Steps

- /fd:init — initialize project (if not done yet)
- /fd:feature <name> — plan a feature (codebase map will inform requirements)
- /fd:run <name> — if feature already planned, start building

<sub>/clear first → fresh context window</sub>
```

</process>

<success_criteria>
- [ ] .fd/codebase/ directory created
- [ ] 4 parallel fd-codebase-mapper agents spawned with run_in_background=true
- [ ] Model profile read from .fd/config.json (default: sonnet)
- [ ] All 4 agents completed
- [ ] All 7 documents verified (exist and >20 lines)
- [ ] Committed if commit_docs enabled
- [ ] Completion summary with line counts displayed
</success_criteria>
