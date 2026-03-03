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

## Step 3b: Optional aid Pre-Scan

```bash
if command -v aid &>/dev/null; then
  # Auto-detect source path
  SRC_PATH="."
  [ -d "src" ] && SRC_PATH="src"

  # Distill public API surface (compact)
  aid "$SRC_PATH" \
    --exclude "*test*,*spec*,*.config.*,node_modules,vendor,.git" \
    --format md \
    --summary-type off \
    --stdout > .fd/codebase/aid-distilled.md 2>/dev/null || true

  DISTILLED_LINES=$(wc -l < .fd/codebase/aid-distilled.md 2>/dev/null || echo 0)

  # If output is too large (>5000 lines), truncate with notice
  if [ "$DISTILLED_LINES" -gt 5000 ]; then
    head -5000 .fd/codebase/aid-distilled.md > .fd/codebase/aid-distilled.tmp
    echo -e "\n<!-- TRUNCATED: ${DISTILLED_LINES} total lines, showing first 5000 -->" >> .fd/codebase/aid-distilled.tmp
    mv .fd/codebase/aid-distilled.tmp .fd/codebase/aid-distilled.md
  fi
fi
```

If `aid` is installed, this produces a compact structural overview that mapper agents can use as a starting point. If `aid` is not installed, this step is silently skipped.

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

If .fd/codebase/aid-distilled.md exists, read it FIRST for a quick structural overview before doing deep exploration. This saves exploration time.

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

If .fd/codebase/aid-distilled.md exists, read it FIRST for a quick structural overview before doing deep exploration. This saves exploration time.

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

If .fd/codebase/aid-distilled.md exists, read it FIRST for a quick structural overview before doing deep exploration. This saves exploration time.

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

If .fd/codebase/aid-distilled.md exists, read it FIRST for a quick structural overview before doing deep exploration. This saves exploration time.

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

## Step 6b: Generate INDEX.md

Auto-generate a registry from the 7 documents + aid output:

```bash
cat > .fd/codebase/INDEX.md << 'HEADER'
# Codebase Index
<!-- Auto-generated by /fd:map-codebase -->

## Documents

| Document | Focus | Description |
|----------|-------|-------------|
| STACK.md | Technology | Languages, frameworks, dependencies |
| INTEGRATIONS.md | External | APIs, databases, third-party services |
| ARCHITECTURE.md | Design | Patterns, layers, data flow |
| STRUCTURE.md | Files | Directory layout, file locations |
| CONVENTIONS.md | Style | Naming, formatting, code patterns |
| TESTING.md | Tests | Framework, patterns, coverage |
| CONCERNS.md | Issues | Tech debt, known bugs, risks |
HEADER

# Add aid status
if [ -f ".fd/codebase/aid-distilled.md" ]; then
  DIST_LINES=$(wc -l < .fd/codebase/aid-distilled.md)
  echo "| aid-distilled.md | API Surface | Public signatures, types, exports ($DIST_LINES lines) |" >> .fd/codebase/INDEX.md
fi

# Extract key stats from existing docs
echo "" >> .fd/codebase/INDEX.md
echo "## Quick Stats" >> .fd/codebase/INDEX.md
grep -h "^- \|^## " .fd/codebase/STACK.md 2>/dev/null | head -10 >> .fd/codebase/INDEX.md
```

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
       .fd/codebase/CONCERNS.md \
       .fd/codebase/INDEX.md

# Include aid output if generated
[ -f .fd/codebase/aid-distilled.md ] && git add .fd/codebase/aid-distilled.md

git commit -m "$(cat <<'EOF'
docs: map codebase (7 documents + index)

Tech: STACK.md, INTEGRATIONS.md
Architecture: ARCHITECTURE.md, STRUCTURE.md
Quality: CONVENTIONS.md, TESTING.md
Concerns: CONCERNS.md
Index: INDEX.md
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
| INDEX.md         | {N}   | ✓      |
| aid-distilled.md | {N}   | ✓/skip |

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
- [ ] aid pre-scan attempted (skipped silently if aid not installed)
- [ ] 4 parallel fd-codebase-mapper agents spawned with run_in_background=true
- [ ] Model profile read from .fd/config.json (default: sonnet)
- [ ] All 4 agents completed
- [ ] All 7 documents verified (exist and >20 lines)
- [ ] INDEX.md generated with document registry
- [ ] Committed if commit_docs enabled
- [ ] Completion summary with line counts displayed
</success_criteria>
