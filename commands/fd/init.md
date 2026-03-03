---
name: fd:init
description: Initialize a project with deep context gathering, codebase mapping, and workflow config (Fucking Done)
allowed-tools:
  - Read
  - Bash
  - Write
  - Task
  - TaskOutput
  - AskUserQuestion
---

<objective>

Initialize a new project through: setup → brownfield detection → questioning → PROJECT.md → config.

This is the project-level setup. It creates `.fd/PROJECT.md` and `.fd/config.json` — shared across all features. After this, use `/fd:feature <name>` to plan individual features.

**Creates:**
- `.fd/PROJECT.md` — project context
- `.fd/config.json` — workflow preferences
- `.fd/codebase/` — codebase analysis (if brownfield)

**After this command:** Run `/fd:feature <name>` to plan a feature.

</objective>

<execution_context>

@/root/.claude/fucking-done/references/questioning.md
@/root/.claude/fucking-done/references/ui-brand.md
@/root/.claude/fucking-done/templates/project.md

</execution_context>

<process>

## Phase 1: Setup

**MANDATORY FIRST STEP — Execute these checks before ANY user interaction:**

1. **Abort if project exists:**
   ```bash
   [ -f .fd/PROJECT.md ] && echo "ERROR: Project already initialized at .fd/PROJECT.md. Use /fd:feature <name> to plan a feature." && exit 1
   ```

2. **Initialize git repo in THIS directory** (required even if inside a parent repo):
   ```bash
   if [ -d .git ] || [ -f .git ]; then
       echo "Git repo exists in current directory"
   else
       git init
       echo "Initialized new git repo"
   fi
   ```

3. **Detect existing code (brownfield detection):**
   ```bash
   CODE_FILES=$(find . -name "*.ts" -o -name "*.js" -o -name "*.py" -o -name "*.go" -o -name "*.rs" -o -name "*.swift" -o -name "*.java" 2>/dev/null | grep -v node_modules | grep -v .git | head -20)
   HAS_PACKAGE=$([ -f package.json ] || [ -f requirements.txt ] || [ -f Cargo.toml ] || [ -f go.mod ] || [ -f Package.swift ] && echo "yes")
   HAS_CODEBASE_MAP=$([ -d .fd/codebase ] && echo "yes")
   ```

   **You MUST run all bash commands above using the Bash tool before proceeding.**

## Phase 2: Brownfield Detection

**If existing code detected** (`CODE_FILES` non-empty OR `HAS_PACKAGE` is "yes") AND codebase map doesn't exist (`HAS_CODEBASE_MAP` is not "yes"):

Use AskUserQuestion:
- header: "Codebase"
- question: "Existing code detected. Map the codebase first? This produces 7 structured analysis documents that improve planning accuracy."
- options:
  - "Map codebase first (Recommended)" — Analyze stack, architecture, conventions, testing, and concerns
  - "Skip mapping" — Continue without codebase analysis

**If "Map codebase first":**

Display stage banner:
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

Create directory:
```bash
mkdir -p .fd/codebase
```

Spawn 4 parallel fd-codebase-mapper agents in a **single message** with `run_in_background=true`:

```
bg_tech = Task(
  prompt="First, read /root/.claude/agents/fd-codebase-mapper.md for your role and instructions.

FOCUS: tech
CODEBASE_DIR: .fd/codebase

Write STACK.md and INTEGRATIONS.md to .fd/codebase/.

Return only a brief confirmation with file names and line counts.",
  description="Map codebase: tech",
  subagent_type="fd-codebase-mapper",
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
  run_in_background=true
)
```

Wait for all 4 agents:
```
TaskOutput(task_id=bg_tech.task_id, block=true, timeout=300000)
TaskOutput(task_id=bg_arch.task_id, block=true, timeout=300000)
TaskOutput(task_id=bg_quality.task_id, block=true, timeout=300000)
TaskOutput(task_id=bg_concerns.task_id, block=true, timeout=300000)
```

Verify all 7 documents exist and are non-empty (>20 lines):
```bash
for doc in STACK INTEGRATIONS ARCHITECTURE STRUCTURE CONVENTIONS TESTING CONCERNS; do
  f=".fd/codebase/${doc}.md"
  if [ -f "$f" ]; then
    lines=$(wc -l < "$f")
    echo "OK: ${doc}.md ($lines lines)"
  else
    echo "MISSING: ${doc}.md"
  fi
done
```

Display completion:
```
✓ Codebase mapped — 7 documents in .fd/codebase/
```

**If "Skip mapping":** Note this is a brownfield project without codebase analysis. Continue to Phase 3.

**If codebase map already exists** (`HAS_CODEBASE_MAP` is "yes"):

Note this is a brownfield project with existing codebase map. Continue to Phase 3.

## Phase 3: Deep Questioning

**Display stage banner:**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  FD ► QUESTIONING
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Open the conversation:**

Ask inline (freeform, NOT AskUserQuestion):

"What do you want to build?"

Wait for their response. This gives you the context needed to ask intelligent follow-up questions.

**Follow the thread:**

Based on what they said, ask follow-up questions that dig into their response. Use AskUserQuestion with options that probe what they mentioned — interpretations, clarifications, concrete examples.

Keep following threads. Each answer opens new threads to explore. Ask about:
- What excited them
- What problem sparked this
- What they mean by vague terms
- What it would actually look like
- What's already decided

Consult `questioning.md` for techniques:
- Challenge vagueness
- Make abstract concrete
- Surface assumptions
- Find edges
- Reveal motivation

**Check context (background, not out loud):**

As you go, mentally check the context checklist from `questioning.md`. If gaps remain, weave questions naturally. Don't suddenly switch to checklist mode.

**Decision gate:**

When you could write a clear PROJECT.md, use AskUserQuestion:

- header: "Ready?"
- question: "I think I understand what you're after. Ready to create PROJECT.md?"
- options:
  - "Create PROJECT.md" — Let's move forward
  - "Keep exploring" — I want to share more / ask me more

If "Keep exploring" — ask what they want to add, or identify gaps and probe naturally.

Loop until "Create PROJECT.md" selected.

## Phase 4: Write PROJECT.md

Synthesize all context into `.fd/PROJECT.md` using the template from `templates/project.md`.

**For greenfield projects:**

Initialize requirements as hypotheses:

```markdown
## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] [Requirement 1]
- [ ] [Requirement 2]
- [ ] [Requirement 3]

### Out of Scope

- [Exclusion 1] — [why]
- [Exclusion 2] — [why]
```

All Active requirements are hypotheses until shipped and validated.

**For brownfield projects (codebase map exists):**

Infer Validated requirements from existing code:

1. Read `.fd/codebase/ARCHITECTURE.md` and `STACK.md`
2. Identify what the codebase already does
3. These become the initial Validated set

```markdown
## Requirements

### Validated

- ✓ [Existing capability 1] — existing
- ✓ [Existing capability 2] — existing
- ✓ [Existing capability 3] — existing

### Active

- [ ] [New requirement 1]
- [ ] [New requirement 2]

### Out of Scope

- [Exclusion 1] — [why]
```

**Key Decisions:**

Initialize with any decisions made during questioning:

```markdown
## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| [Choice from questioning] | [Why] | — Pending |
```

**Last updated footer:**

```markdown
---
*Last updated: [date] after initialization*
```

Do not compress. Capture everything gathered.

**Commit PROJECT.md:**

```bash
mkdir -p .fd
git add .fd/PROJECT.md
git commit -m "$(cat <<'EOF'
docs: initialize project

[One-liner from PROJECT.md What This Is section]
EOF
)"
```

## Phase 5: Workflow Preferences

**Round 1 — Core workflow settings (3 questions):**

```
questions: [
  {
    header: "Mode",
    question: "How do you want to work?",
    multiSelect: false,
    options: [
      { label: "YOLO (Recommended)", description: "Auto-approve, just execute" },
      { label: "Interactive", description: "Confirm at each step" }
    ]
  },
  {
    header: "Depth",
    question: "How thorough should planning be?",
    multiSelect: false,
    options: [
      { label: "Quick", description: "Ship fast (3-5 phases, 1-3 plans each)" },
      { label: "Standard", description: "Balanced scope and speed (5-8 phases, 3-5 plans each)" },
      { label: "Comprehensive", description: "Thorough coverage (8-12 phases, 5-10 plans each)" }
    ]
  },
  {
    header: "Git Tracking",
    question: "Commit planning docs to git?",
    multiSelect: false,
    options: [
      { label: "Yes (Recommended)", description: "Planning docs tracked in version control" },
      { label: "No", description: "Keep .fd/ local-only (add to .gitignore)" }
    ]
  }
]
```

**Round 2 — Workflow agents:**

These spawn additional agents during planning/execution. They add tokens and time but improve quality.

| Agent | When it runs | What it does |
|-------|--------------|--------------|
| **Researcher** | Before planning each phase | Investigates domain, finds patterns, surfaces gotchas |
| **Plan Checker** | After plan is created | Verifies plan actually achieves the phase goal |
| **Verifier** | After phase execution | Confirms must-haves were delivered |

All recommended for important projects. Skip for quick experiments.

```
questions: [
  {
    header: "Research",
    question: "Research before planning each phase? (adds tokens/time)",
    multiSelect: false,
    options: [
      { label: "Yes (Recommended)", description: "Investigate domain, find patterns, surface gotchas" },
      { label: "No", description: "Plan directly from requirements" }
    ]
  },
  {
    header: "Plan Check",
    question: "Verify plans will achieve their goals? (adds tokens/time)",
    multiSelect: false,
    options: [
      { label: "Yes (Recommended)", description: "Catch gaps before execution starts" },
      { label: "No", description: "Execute plans without verification" }
    ]
  },
  {
    header: "Verifier",
    question: "Verify work satisfies requirements after each phase? (adds tokens/time)",
    multiSelect: false,
    options: [
      { label: "Yes (Recommended)", description: "Confirm deliverables match phase goals" },
      { label: "No", description: "Trust execution, skip verification" }
    ]
  },
  {
    header: "Model Profile",
    question: "Which AI models for planning agents?",
    multiSelect: false,
    options: [
      { label: "Balanced (Recommended)", description: "Sonnet for most agents — good quality/cost ratio" },
      { label: "Quality", description: "Opus for research/roadmap — higher cost, deeper analysis" },
      { label: "Budget", description: "Haiku where possible — fastest, lowest cost" }
    ]
  }
]
```

**Round 3 — Fucking done settings:**

```
questions: [
  {
    header: "Team Models",
    question: "Which models for fucking done execution?",
    multiSelect: false,
    options: [
      { label: "Opus lead + Sonnet teammates (Recommended)", description: "Best quality/cost balance" },
      { label: "All Opus", description: "Highest quality, highest cost" },
      { label: "Sonnet lead + Haiku teammates", description: "Budget option" }
    ]
  }
]
```

Create `.fd/config.json` with all settings:

```json
{
  "mode": "yolo|interactive",
  "depth": "quick|standard|comprehensive",
  "parallelization": true,
  "commit_docs": true|false,
  "model_profile": "quality|balanced|budget",
  "workflow": {
    "research": true|false,
    "plan_check": true|false,
    "verifier": true|false,
    "difficulty_aware": true
  },
  "agent_team": {
    "lead_model": "opus",
    "teammate_model": "sonnet",
    "max_gap_loops": 3,
    "max_parallel": 4,
    "isolation": "shared"
  },
  "repair": {
    "max_retries": 2,
    "backoff": "none",
    "timeout_minutes": 30,
    "idempotency": true
  },
  "aid": {
    "enabled": true,
    "include": "",
    "exclude": "*test*,*spec*,*.config.*,node_modules,vendor",
    "flags": "--format md",
    "src_path": ""
  }
}
```

Note: `aid.include` defaults to empty (auto-detect from project). For Go+React use `"*.go,*.tsx,*.ts"`, Python use `"*.py"`, etc.

Note: `parallelization` is always `true` — fucking done always runs plans in parallel via fucking dones.

Map Round 3 selections to `agent_team` config:
- "Opus lead + Sonnet teammates" → `lead_model: "opus"`, `teammate_model: "sonnet"`
- "All Opus" → `lead_model: "opus"`, `teammate_model: "opus"`
- "Sonnet lead + Haiku teammates" → `lead_model: "sonnet"`, `teammate_model: "haiku"`

**If commit_docs = No:**
- Set `commit_docs: false` in config.json
- Add `.fd/` to `.gitignore` (create if needed)

**If commit_docs = Yes:**
- No additional gitignore entries needed

**Commit config.json:**

```bash
git add .fd/config.json
git commit -m "$(cat <<'EOF'
chore: add project config

Mode: [chosen mode]
Depth: [chosen depth]
Parallelization: enabled
Workflow agents: research=[on/off], plan_check=[on/off], verifier=[on/off]
Fucking done: [lead_model] lead + [teammate_model] teammates
EOF
)"
```

**Note:** Run `/fd:settings` anytime to update these preferences.

## Phase 10: Done

Present completion with next steps:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  FD ► PROJECT INITIALIZED ✓
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

**[Project Name]**

| Artifact       | Location                    |
|----------------|-----------------------------|
| Project        | `.fd/PROJECT.md`            |
| Config         | `.fd/config.json`           |
| Codebase       | `.fd/codebase/`             |

Ready to plan features ✓

───────────────────────────────────────────────────────────────

## ▶ Next Up

**Plan a feature:**

/fd:feature <name> — research, define requirements, create roadmap

<sub>/clear first → fresh context window</sub>

───────────────────────────────────────────────────────────────
```

</process>

<output>

- `.fd/PROJECT.md`
- `.fd/config.json`
- `.fd/codebase/` (if brownfield and mapping selected)
  - `STACK.md`
  - `INTEGRATIONS.md`
  - `ARCHITECTURE.md`
  - `STRUCTURE.md`
  - `CONVENTIONS.md`
  - `TESTING.md`
  - `CONCERNS.md`

</output>

<success_criteria>

- [ ] `.fd/` directory created
- [ ] Git repo initialized
- [ ] Brownfield detection completed
- [ ] Deep questioning completed (threads followed, not rushed)
- [ ] PROJECT.md captures full context → **committed**
- [ ] config.json has workflow mode, depth, parallelization, agent_team → **committed**
- [ ] Codebase mapped (if brownfield and selected)
- [ ] User knows next step is `/fd:feature <name>`

**Atomic commits:** Each phase commits its artifacts immediately. If context is lost, artifacts persist.

</success_criteria>
