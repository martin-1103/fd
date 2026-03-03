---
name: fd:feature
description: Plan a feature — research, requirements, and roadmap (Fucking Done)
argument-hint: feature-name (lowercase-hyphen, e.g. "auth-system", "chat-widget")
allowed-tools:
  - Read
  - Bash
  - Write
  - Task
  - TaskOutput
  - AskUserQuestion
---

## Argument Parsing

**MANDATORY FIRST STEP — Parse and validate arguments before anything else:**

```
FEATURE = $ARGUMENTS (trimmed)
```

**BAHASA:** User-facing output in Bahasa Indonesia (santai). Technical terms (file names, config keys, status codes) in English. Generated files (PLAN.md, SUMMARY.md, etc.) in English.

**Validation:**
1. If `FEATURE` is empty → Output "ERROR: Feature name required. Usage: /fd:feature <feature-name>" and STOP.
2. If `FEATURE` contains spaces or uppercase → Output "ERROR: Feature name must be lowercase-hyphen format (e.g. 'auth-system', 'chat-widget')" and STOP.
3. Set `PLANNING_DIR = .fd/planning/$FEATURE`

All paths below use `$PLANNING_DIR/` instead of `.fd/planning/`.

**Prerequisite check:**

```bash
[ -f .fd/PROJECT.md ] || { echo "ERROR: Project not initialized. Run /fd:init first."; exit 1; }
[ -f .fd/config.json ] || { echo "ERROR: Project config missing. Run /fd:init first."; exit 1; }
```

<objective>

Plan a feature: research the domain, define requirements, create a roadmap.

Requires `/fd:init` to have been run first (creates `.fd/PROJECT.md` and `.fd/config.json`).

**Creates:**
- `$PLANNING_DIR/research/` — domain research (optional)
- `$PLANNING_DIR/REQUIREMENTS.md` — scoped requirements
- `$PLANNING_DIR/ROADMAP.md` — phase structure
- `$PLANNING_DIR/STATE.md` — feature memory

**After this command:** Run `/fd:discuss-phase $FEATURE 1` then `/fd:run $FEATURE` to start.

</objective>

<execution_context>

@/root/.claude/fucking-done/references/ui-brand.md
@/root/.claude/fucking-done/templates/requirements.md

</execution_context>

<process>

## Phase 5.5: Resolve Model Profile

Read model profile for agent spawning:

```bash
MODEL_PROFILE=$(cat .fd/config.json 2>/dev/null | grep -o '"model_profile"[[:space:]]*:[[:space:]]*"[^"]*"' | grep -o '"[^"]*"$' | tr -d '"' || echo "balanced")
```

Default to "balanced" if not set.

**Model lookup table:**

| Agent | quality | balanced | budget |
|-------|---------|----------|--------|
| fd-project-researcher | opus | sonnet | haiku |
| fd-research-synthesizer | sonnet | sonnet | haiku |
| fd-roadmapper | opus | sonnet | sonnet |

Store resolved models for use in Task calls below.

## Phase 6: Research Decision

Use AskUserQuestion:
- header: "Research"
- question: "Research the domain ecosystem before defining requirements?"
- options:
  - "Research first (Recommended)" — Discover standard stacks, expected features, architecture patterns
  - "Skip research" — I know this domain well, go straight to requirements

**If "Research first":**

Display stage banner:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  FD ► RESEARCHING [$FEATURE]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Researching [domain] ecosystem...
```

Create research directory:
```bash
mkdir -p $PLANNING_DIR/research
```

**Determine milestone context:**

Check if this is greenfield or subsequent milestone:
- If no "Validated" requirements in `.fd/PROJECT.md` → Greenfield (building from scratch)
- If "Validated" requirements exist → Subsequent milestone (adding to existing app)

Display spawning indicator:
```
◆ Spawning 4 researchers in parallel...
  → Stack research
  → Features research
  → Architecture research
  → Pitfalls research
```

Spawn 4 parallel fd-project-researcher agents with rich context:

```
Task(prompt="First, read /root/.claude/agents/fd-project-researcher.md for your role and instructions.

PLANNING_DIR: $PLANNING_DIR/

<research_type>
Project Research — Stack dimension for [domain].
</research_type>

<milestone_context>
[greenfield OR subsequent]

Greenfield: Research the standard stack for building [domain] from scratch.
Subsequent: Research what's needed to add [target features] to an existing [domain] app. Don't re-research the existing system.
</milestone_context>

<question>
What's the standard 2025 stack for [domain]?
</question>

<project_context>
[PROJECT.md summary - core value, constraints, what they're building]
</project_context>

<downstream_consumer>
Your STACK.md feeds into roadmap creation. Be prescriptive:
- Specific libraries with versions
- Clear rationale for each choice
- What NOT to use and why
</downstream_consumer>

<quality_gate>
- [ ] Versions are current (verify with Context7/official docs, not training data)
- [ ] Rationale explains WHY, not just WHAT
- [ ] Confidence levels assigned to each recommendation
</quality_gate>

<output>
Write to: $PLANNING_DIR/research/STACK.md
Use template: /root/.claude/fucking-done/templates/research-project/STACK.md
</output>
", subagent_type="general-purpose", model="{researcher_model}", description="Stack research")

Task(prompt="First, read /root/.claude/agents/fd-project-researcher.md for your role and instructions.

PLANNING_DIR: $PLANNING_DIR/

<research_type>
Project Research — Features dimension for [domain].
</research_type>

<milestone_context>
[greenfield OR subsequent]

Greenfield: What features do [domain] products have? What's table stakes vs differentiating?
Subsequent: How do [target features] typically work? What's expected behavior?
</milestone_context>

<question>
What features do [domain] products have? What's table stakes vs differentiating?
</question>

<project_context>
[PROJECT.md summary]
</project_context>

<downstream_consumer>
Your FEATURES.md feeds into requirements definition. Categorize clearly:
- Table stakes (must have or users leave)
- Differentiators (competitive advantage)
- Anti-features (things to deliberately NOT build)
</downstream_consumer>

<quality_gate>
- [ ] Categories are clear (table stakes vs differentiators vs anti-features)
- [ ] Complexity noted for each feature
- [ ] Dependencies between features identified
</quality_gate>

<output>
Write to: $PLANNING_DIR/research/FEATURES.md
Use template: /root/.claude/fucking-done/templates/research-project/FEATURES.md
</output>
", subagent_type="general-purpose", model="{researcher_model}", description="Features research")

Task(prompt="First, read /root/.claude/agents/fd-project-researcher.md for your role and instructions.

PLANNING_DIR: $PLANNING_DIR/

<research_type>
Project Research — Architecture dimension for [domain].
</research_type>

<milestone_context>
[greenfield OR subsequent]

Greenfield: How are [domain] systems typically structured? What are major components?
Subsequent: How do [target features] integrate with existing [domain] architecture?
</milestone_context>

<question>
How are [domain] systems typically structured? What are major components?
</question>

<project_context>
[PROJECT.md summary]
</project_context>

<downstream_consumer>
Your ARCHITECTURE.md informs phase structure in roadmap. Include:
- Component boundaries (what talks to what)
- Data flow (how information moves)
- Suggested build order (dependencies between components)
</downstream_consumer>

<quality_gate>
- [ ] Components clearly defined with boundaries
- [ ] Data flow direction explicit
- [ ] Build order implications noted
</quality_gate>

<output>
Write to: $PLANNING_DIR/research/ARCHITECTURE.md
Use template: /root/.claude/fucking-done/templates/research-project/ARCHITECTURE.md
</output>
", subagent_type="general-purpose", model="{researcher_model}", description="Architecture research")

Task(prompt="First, read /root/.claude/agents/fd-project-researcher.md for your role and instructions.

PLANNING_DIR: $PLANNING_DIR/

<research_type>
Project Research — Pitfalls dimension for [domain].
</research_type>

<milestone_context>
[greenfield OR subsequent]

Greenfield: What do [domain] projects commonly get wrong? Critical mistakes?
Subsequent: What are common mistakes when adding [target features] to [domain]?
</milestone_context>

<question>
What do [domain] projects commonly get wrong? Critical mistakes?
</question>

<project_context>
[PROJECT.md summary]
</project_context>

<downstream_consumer>
Your PITFALLS.md prevents mistakes in roadmap/planning. For each pitfall:
- Warning signs (how to detect early)
- Prevention strategy (how to avoid)
- Which phase should address it
</downstream_consumer>

<quality_gate>
- [ ] Pitfalls are specific to this domain (not generic advice)
- [ ] Prevention strategies are actionable
- [ ] Phase mapping included where relevant
</quality_gate>

<output>
Write to: $PLANNING_DIR/research/PITFALLS.md
Use template: /root/.claude/fucking-done/templates/research-project/PITFALLS.md
</output>
", subagent_type="general-purpose", model="{researcher_model}", description="Pitfalls research")
```

After all 4 agents complete, spawn synthesizer to create SUMMARY.md:

```
Task(prompt="
PLANNING_DIR: $PLANNING_DIR/

<task>
Synthesize research outputs into SUMMARY.md.
</task>

<research_files>
Read these files:
- $PLANNING_DIR/research/STACK.md
- $PLANNING_DIR/research/FEATURES.md
- $PLANNING_DIR/research/ARCHITECTURE.md
- $PLANNING_DIR/research/PITFALLS.md
</research_files>

<output>
Write to: $PLANNING_DIR/research/SUMMARY.md
Use template: /root/.claude/fucking-done/templates/research-project/SUMMARY.md
Commit after writing.
</output>
", subagent_type="fd-research-synthesizer", model="{synthesizer_model}", description="Synthesize research")
```

Display research complete banner and key findings:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  FD ► RESEARCH COMPLETE ✓ [$FEATURE]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Key Findings

**Stack:** [from SUMMARY.md]
**Table Stakes:** [from SUMMARY.md]
**Watch Out For:** [from SUMMARY.md]

Files: `$PLANNING_DIR/research/`
```

**If "Skip research":** Continue to Phase 7.

## Phase 7: Define Requirements

Display stage banner:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  FD ► DEFINING REQUIREMENTS [$FEATURE]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Load context:**

Read `.fd/PROJECT.md` and extract:
- Core value (the ONE thing that must work)
- Stated constraints (budget, timeline, tech limitations)
- Any explicit scope boundaries

**For brownfield projects (codebase map exists at `.fd/codebase/`):**

Read `.fd/codebase/ARCHITECTURE.md` and `.fd/codebase/STACK.md` to understand existing capabilities. Use this to infer validated requirements.

**If research exists:** Read research/FEATURES.md and extract feature categories.

**Present features by category:**

```
Here are the features for [domain]:

## Authentication
**Table stakes:**
- Sign up with email/password
- Email verification
- Password reset
- Session management

**Differentiators:**
- Magic link login
- OAuth (Google, GitHub)
- 2FA

**Research notes:** [any relevant notes]

---

## [Next Category]
...
```

**If no research:** Gather requirements through conversation instead.

Ask: "What are the main things users need to be able to do?"

For each capability mentioned:
- Ask clarifying questions to make it specific
- Probe for related capabilities
- Group into categories

**Scope each category:**

For each category, use AskUserQuestion:

- header: "[Category name]"
- question: "Which [category] features are in v1?"
- multiSelect: true
- options:
  - "[Feature 1]" — [brief description]
  - "[Feature 2]" — [brief description]
  - "[Feature 3]" — [brief description]
  - "None for v1" — Defer entire category

Track responses:
- Selected features → v1 requirements
- Unselected table stakes → v2 (users expect these)
- Unselected differentiators → out of scope

**Identify gaps:**

Use AskUserQuestion:
- header: "Additions"
- question: "Any requirements research missed? (Features specific to your vision)"
- options:
  - "No, research covered it" — Proceed
  - "Yes, let me add some" — Capture additions

**Validate core value:**

Cross-check requirements against Core Value from PROJECT.md. If gaps detected, surface them.

**Generate REQUIREMENTS.md:**

Create `$PLANNING_DIR/REQUIREMENTS.md` with:
- v1 Requirements grouped by category (checkboxes, REQ-IDs)
- v2 Requirements (deferred)
- Out of Scope (explicit exclusions with reasoning)
- Traceability section (empty, filled by roadmap)

**REQ-ID format:** `[CATEGORY]-[NUMBER]` (AUTH-01, CONTENT-02)

**Requirement quality criteria:**

Good requirements are:
- **Specific and testable:** "User can reset password via email link" (not "Handle password reset")
- **User-centric:** "User can X" (not "System does Y")
- **Atomic:** One capability per requirement (not "User can login and manage profile")
- **Independent:** Minimal dependencies on other requirements

Reject vague requirements. Push for specificity:
- "Handle authentication" → "User can log in with email/password and stay logged in across sessions"
- "Support sharing" → "User can share post via link that opens in recipient's browser"

**Present full requirements list:**

Show every requirement (not counts) for user confirmation:

```
## v1 Requirements

### Authentication
- [ ] **AUTH-01**: User can create account with email/password
- [ ] **AUTH-02**: User can log in and stay logged in across sessions
- [ ] **AUTH-03**: User can log out from any page

### Content
- [ ] **CONT-01**: User can create posts with text
- [ ] **CONT-02**: User can edit their own posts

[... full list ...]

---

Does this capture what you're building? (yes / adjust)
```

If "adjust": Return to scoping.

**Commit requirements:**

```bash
git add $PLANNING_DIR/REQUIREMENTS.md
git commit -m "$(cat <<'EOF'
docs($FEATURE): define v1 requirements

[X] requirements across [N] categories
[Y] requirements deferred to v2
EOF
)"
```

## Phase 8: Create Roadmap

Display stage banner:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  FD ► CREATING ROADMAP [$FEATURE]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

◆ Spawning roadmapper...
```

Spawn fd-roadmapper agent with context:

```
Task(prompt="
PLANNING_DIR: $PLANNING_DIR/

<planning_context>

**Project:**
@.fd/PROJECT.md

**Requirements:**
@$PLANNING_DIR/REQUIREMENTS.md

**Research (if exists):**
@$PLANNING_DIR/research/SUMMARY.md

**Config:**
@.fd/config.json

</planning_context>

<instructions>
Create roadmap:
1. Derive phases from requirements (don't impose structure)
2. Map every v1 requirement to exactly one phase
3. Derive 2-5 success criteria per phase (observable user behaviors)
4. Validate 100% coverage
5. Write files immediately (ROADMAP.md, STATE.md, update REQUIREMENTS.md traceability)
6. Return ROADMAP CREATED with summary

Write files first, then return. This ensures artifacts persist even if context is lost.
</instructions>
", subagent_type="fd-roadmapper", model="{roadmapper_model}", description="Create roadmap")
```

**Handle roadmapper return:**

**If `## ROADMAP BLOCKED`:**
- Present blocker information
- Work with user to resolve
- Re-spawn when resolved

**If `## ROADMAP CREATED`:**

Read the created ROADMAP.md and present it nicely inline:

```
---

## Proposed Roadmap

**[N] phases** | **[X] requirements mapped** | All v1 requirements covered ✓

| # | Phase | Goal | Requirements | Success Criteria |
|---|-------|------|--------------|------------------|
| 1 | [Name] | [Goal] | [REQ-IDs] | [count] |
| 2 | [Name] | [Goal] | [REQ-IDs] | [count] |
| 3 | [Name] | [Goal] | [REQ-IDs] | [count] |
...

### Phase Details

**Phase 1: [Name]**
Goal: [goal]
Requirements: [REQ-IDs]
Success criteria:
1. [criterion]
2. [criterion]
3. [criterion]

**Phase 2: [Name]**
Goal: [goal]
Requirements: [REQ-IDs]
Success criteria:
1. [criterion]
2. [criterion]

[... continue for all phases ...]

---
```

**CRITICAL: Ask for approval before committing:**

Use AskUserQuestion:
- header: "Roadmap"
- question: "Does this roadmap structure work for you?"
- options:
  - "Approve" — Commit and continue
  - "Adjust phases" — Tell me what to change
  - "Review full file" — Show raw ROADMAP.md

**If "Approve":** Continue to commit.

**If "Adjust phases":**
- Get user's adjustment notes
- Re-spawn roadmapper with revision context:
  ```
  Task(prompt="
  PLANNING_DIR: $PLANNING_DIR/

  <revision>
  User feedback on roadmap:
  [user's notes]

  Current ROADMAP.md: @$PLANNING_DIR/ROADMAP.md

  Update the roadmap based on feedback. Edit files in place.
  Return ROADMAP REVISED with changes made.
  </revision>
  ", subagent_type="fd-roadmapper", model="{roadmapper_model}", description="Revise roadmap")
  ```
- Present revised roadmap
- Loop until user approves

**If "Review full file":** Display raw `cat $PLANNING_DIR/ROADMAP.md`, then re-ask.

**Commit roadmap (after approval):**

```bash
git add $PLANNING_DIR/ROADMAP.md $PLANNING_DIR/STATE.md $PLANNING_DIR/REQUIREMENTS.md
git commit -m "$(cat <<'EOF'
docs($FEATURE): create roadmap ([N] phases)

Phases:
1. [phase-name]: [requirements covered]
2. [phase-name]: [requirements covered]
...

All v1 requirements mapped to phases.
EOF
)"
```

## Phase 10: Done

Present completion with next steps:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  FD ► FEATURE PLANNED ✓ [$FEATURE]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

**[Project Name] — $FEATURE**

| Artifact       | Location                          |
|----------------|-----------------------------------|
| Project        | `.fd/PROJECT.md`                  |
| Config         | `.fd/config.json`                 |
| Research       | `$PLANNING_DIR/research/`         |
| Requirements   | `$PLANNING_DIR/REQUIREMENTS.md`   |
| Roadmap        | `$PLANNING_DIR/ROADMAP.md`        |

**[N] phases** | **[X] requirements** | Ready to build ✓

───────────────────────────────────────────────────────────────

## ▶ Next Up

**Phase 1: [Phase Name]** — [Goal from ROADMAP.md]

/fd:discuss-phase $FEATURE 1 — gather context and clarify approach

<sub>/clear first → fresh context window</sub>

---

**Then run:**
- /fd:run $FEATURE — plan, execute, and verify automatically with fucking dones

───────────────────────────────────────────────────────────────
```

</process>

<output>

- `$PLANNING_DIR/research/` (if research selected)
  - `STACK.md`
  - `FEATURES.md`
  - `ARCHITECTURE.md`
  - `PITFALLS.md`
  - `SUMMARY.md`
- `$PLANNING_DIR/REQUIREMENTS.md`
- `$PLANNING_DIR/ROADMAP.md`
- `$PLANNING_DIR/STATE.md`

</output>

<success_criteria>

- [ ] Feature name argument parsed and validated
- [ ] .fd/PROJECT.md exists (prerequisite check)
- [ ] .fd/config.json exists (prerequisite check)
- [ ] $PLANNING_DIR set to .fd/planning/$FEATURE
- [ ] Model profile resolved from .fd/config.json
- [ ] Research completed (if selected) — 4 parallel agents spawned → **committed**
- [ ] Requirements gathered (from research or conversation)
- [ ] User scoped each category (v1/v2/out of scope)
- [ ] REQUIREMENTS.md created with REQ-IDs → **committed**
- [ ] fd-roadmapper spawned with context
- [ ] Roadmap files written immediately (not draft)
- [ ] User feedback incorporated (if any)
- [ ] ROADMAP.md created with phases, requirement mappings, success criteria
- [ ] STATE.md initialized
- [ ] REQUIREMENTS.md traceability updated
- [ ] User knows next step is `/fd:discuss-phase $FEATURE 1` then `/fd:run $FEATURE`

**Atomic commits:** Each phase commits its artifacts immediately. If context is lost, artifacts persist.

</success_criteria>
