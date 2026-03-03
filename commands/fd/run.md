---
name: fd:run
description: Automatically plan, execute, and verify all phases using Fucking Done background subagents
argument-hint: <feature-name> (lowercase-hyphen, e.g. "auth-system")
allowed-tools:
  - Read
  - Edit
  - Bash
  - Glob
  - Grep
  - Task
  - TaskOutput
  - AskUserQuestion
---

<argument_parsing>
## Argument: Feature Name (REQUIRED)

The `$ARGUMENTS` variable contains the feature name. Parse and validate it immediately:

1. If `$ARGUMENTS` is empty or whitespace, stop immediately:
   ```
   ERROR: Feature name required.
   Usage: /fd:run <feature-name>
   Example: /fd:run auth-system
   ```

2. Validate format (lowercase letters, numbers, hyphens only):
   - Must match pattern: `^[a-z][a-z0-9-]*$`
   - If invalid, stop:
     ```
     ERROR: Invalid feature name "$ARGUMENTS".
     Must be lowercase-hyphen format (e.g. "auth-system", "user-profile").
     ```

3. Set variables:
   ```
   FEATURE=$ARGUMENTS
   PLANNING_DIR=.fd/planning/$FEATURE
   ```

All subsequent paths use `$PLANNING_DIR` instead of `.fd/planning/`.
</argument_parsing>

<objective>
You are the FD lead agent. Orchestrate the entire build pipeline using background subagents.

Pipeline: Load Config -> Scan -> **Per-Phase Loop** (Plan -> Execute -> Verify -> Complete) -> Cleanup

**CRITICAL ARCHITECTURE -- Phase-at-a-time pipeline:**
Process each phase through the COMPLETE pipeline (plan -> execute -> verify) before moving to the next phase. This prevents context overflow from accumulating results across all phases simultaneously.

**Context-lean subagent pattern:**
- Subagents run with `run_in_background=true` -- their full output goes to a file, NOT your context
- You pass FILE PATHS to subagents, NOT file contents -- subagents read files in their own context
- You only read BRIEF STATUS from subagent results, never full reports
- This keeps your context at ~10-15% regardless of how many phases are processed

Architecture split:
- **Background Subagents** (Task with run_in_background=true): ALL work -- planning, research, execution, verification. Each subagent does 1 task, writes output to files, dies.
- No TeamCreate, no SendMessage, no shared task list. Filesystem IS the coordination layer.

**You are the lead.** You stay in this session. Subagents come and go.

**Lead MUST NOT write source code.** Only touch $PLANNING_DIR/ files for metadata updates (STATE.md, ROADMAP.md, REQUIREMENTS.md).

**Lead MUST NOT read file contents into context.** Pass file paths to subagents. Only read short status fields (grep for specific lines).
</objective>

<execution_context>
@/root/.claude/fucking-done/references/ui-brand.md
</execution_context>

<context>
Read these dynamically at runtime using $PLANNING_DIR:
- $PLANNING_DIR/ROADMAP.md
- $PLANNING_DIR/STATE.md
- .fd/config.json
</context>

<process>

## Phase 0: Load Config and Validate

1. Validate `$PLANNING_DIR/` exists. If it does not exist, stop immediately and tell the user:
   ```
   ERROR

   $PLANNING_DIR/ directory not found.

   **To fix:** Run /fd:init first to initialize project structure.
   ```

2. Read config.json for settings:
   ```bash
   cat .fd/config.json
   ```

3. Extract these settings into variables you will reference throughout:
   - `model_profile` -- for subagent model selection. Values: "quality" / "balanced" / "budget" / "adaptive" (adaptive = auto-select based on phase difficulty)
   - `workflow.research` -- whether to research before planning (boolean)
   - `workflow.plan_check` -- whether to verify plans after creation (boolean)
   - `workflow.verifier` -- whether to verify after execution (boolean)
   - `workflow.difficulty_aware` -- classify phases by difficulty and adapt workflow (boolean, default: true)
   - `agent_team.lead_model` -- lead model (default: opus)
   - `agent_team.teammate_model` -- teammate model (default: sonnet)
   - `agent_team.max_gap_loops` -- max gap closure iterations (default: 3)
   - `agent_team.max_parallel` -- max concurrent executor subagents per wave (default: 4)
   - `repair.max_retries` -- max retries for failed tasks (default: 2)
   - `repair.backoff` -- backoff strategy between retries: "none" / "linear" / "exponential" (default: "none")
   - `repair.timeout_minutes` -- minutes before a task is considered stuck (default: 30)
   - `repair.idempotency` -- check if output already exists before retrying (boolean, default: true)
   - `aid.enabled` -- whether to run optional aid distillation (boolean, default: false). Agents use Grep/Glob for just-in-time codebase discovery by default.
   - `aid.include` -- file patterns to include (string, only if aid.enabled)
   - `aid.exclude` -- file patterns to exclude (string, only if aid.enabled)
   - `aid.flags` -- extra aid flags (string, only if aid.enabled)
   - `aid.src_path` -- source path to distill (string, only if aid.enabled)

4. Read ROADMAP.md and STATE.md to understand project scope and current progress.

4b. Load cross-session deviation memory (if exists):
   ```bash
   cat $PLANNING_DIR/deviation-memory.md 2>/dev/null
   ```
   If it exists, note the file path. Deviation patterns will be referenced by path in executor task descriptions.

4c. Check for existing run-state.json for recovery:
   ```bash
   cat $PLANNING_DIR/run-state.json 2>/dev/null
   ```
   If exists, resume from recorded position instead of starting from scratch.

5. Load planning config for commit behavior:
   ```bash
   COMMIT_PLANNING_DOCS=$(cat .fd/config.json 2>/dev/null | grep -o '"commit_docs"[[:space:]]*:[[:space:]]*[^,}]*' | grep -o 'true\|false' || echo "true")
   git check-ignore -q $PLANNING_DIR 2>/dev/null && COMMIT_PLANNING_DOCS=false
   ```

5b. **Codebase context strategy: structured map + just-in-time discovery**

   **Primary:** If `.fd/codebase/` exists (created by `/fd:map-codebase` or `/fd:init` brownfield flow), subagents reference these 7 structured documents (STACK.md, INTEGRATIONS.md, ARCHITECTURE.md, STRUCTURE.md, CONVENTIONS.md, TESTING.md, CONCERNS.md) for codebase understanding. Pass `.fd/codebase/` path to subagents — they read relevant docs themselves.

   **Always available:** Subagents have Grep, Glob, Read, and Bash tools. They discover additional codebase context on-demand by searching directly. The structured map provides the foundation; just-in-time search fills gaps.

   **Supplementary:** If `aid.enabled` is `true` in config, run aid distillation as additional reference:
   ```bash
   mkdir -p .fd/codebase
   aid "${aid.src_path:-.}" \
     --include "${aid.include}" \
     --exclude "${aid.exclude}" \
     ${aid.flags} \
     --summary-type off \
     -o .fd/codebase/aid-distilled.md
   ```
   If aid fails or not found, skip silently — it's not required.

6. Display config summary:
   ```
   FD > CONFIG LOADED

   Feature:        $FEATURE
   Planning dir:   $PLANNING_DIR
   Lead model:     {lead_model}
   Teammate model: {teammate_model}
   Model profile:  {model_profile} (adaptive = auto-select by difficulty)
   Pipeline:       Phase-at-a-time (plan->execute->verify per phase)
   Research:       {enabled/disabled}
   Plan check:     {enabled/disabled}
   Verifier:       {enabled/disabled}
   Difficulty-aware: {enabled/disabled}
   Max gap loops:  {N}
   Max parallel:   {N}
   Commit docs:    {true/false}
   Repair policy:  max_retries={N}, backoff={strategy}, timeout={N}min, idempotent={bool}
   Codebase ctx:   just-in-time (agents grep/glob on demand)
   Deviation memory: {loaded N patterns / not found}
   Recovery state: {resuming from phase X step Y / fresh start}
   ```

---

## Phase 1: Scan & Identify Work

Scan the project to determine what needs to be done.

### Step 1.1: Discover phases from ROADMAP.md

Parse ROADMAP.md to find all phases defined with `### Phase` headers.

```bash
grep -E "^### Phase" $PLANNING_DIR/ROADMAP.md
```

### Step 1.2: Discover phase directories

```bash
ls -d $PLANNING_DIR/phases/*/ 2>/dev/null
```

### Step 1.3: For each phase directory, determine status

Check these files to classify each phase:
- Has PLAN.md files? (planned)
- Has SUMMARY.md files for each PLAN.md? (executed)
- Has *-VERIFICATION.md files? (verified)
- *-VERIFICATION.md status field? (passed / gaps_found)

Classification rules:
- **needs_planning**: Phase exists in ROADMAP but has no PLAN.md files in its directory
- **needs_execution**: Has PLAN.md file(s) but at least one PLAN.md is missing a corresponding SUMMARY.md
- **needs_verification**: All plans have SUMMARY.md but no *-VERIFICATION.md exists, OR *-VERIFICATION.md has `status: gaps_found`
- **complete**: *-VERIFICATION.md exists with `status: passed`

### Step 1.4: Classify phase difficulty (if difficulty_aware enabled)

If `workflow.difficulty_aware` is `true`, classify each phase that needs work:

**Heuristics:**
- `simple`: Config changes, documentation updates, single-file modifications, renaming, formatting. Indicators: phase goal mentions "config", "docs", "rename", "update", or ROADMAP description implies a single file change.
- `moderate`: Multi-file feature work, adding a new route + handler + tests, standard CRUD operations. Indicators: phase goal involves 2-5 files, standard patterns, no new libraries.
- `complex`: New architecture, multiple integrations, new libraries/frameworks, database migrations with data transforms, cross-cutting concerns (auth, caching, observability). Indicators: phase goal mentions "architect", "integrate", "migrate", or involves 6+ files / new dependencies.

Store difficulty per phase alongside status for use in Phase 2.

### Step 1.5: Build and display status matrix

```
FD > SCANNING PROJECT

| Phase          | Planned | Executed | Verified | Difficulty | Status             |
|----------------|---------|----------|----------|------------|--------------------|
| 01-setup       | yes     | no       | no       | simple     | needs_execution    |
| 02-auth        | no      | no       | no       | complex    | needs_planning     |
| 03-content     | no      | no       | no       | moderate   | needs_planning     |

Pipeline: Each phase will be processed completely (plan->execute->verify) before moving to the next.
```

If ALL phases are `complete`, skip to Phase 3 (Cleanup & Completion) immediately.

---

## Phase 2: Per-Phase Pipeline

**This is the core of the FD approach.** Instead of planning ALL phases then executing ALL then verifying ALL (which bloats lead context), we process each phase through the complete pipeline before moving to the next.

**Context-lean rules for the lead:**
1. **NEVER read file contents** (RESEARCH.md, PLAN.md, SUMMARY.md, etc.) into your context. Pass file PATHS to subagents.
2. **All subagents run in background** (`run_in_background=true`). Wait for completion with `TaskOutput(task_id=..., block=true)`.
3. **Only read brief status** from subagent results or grep specific status lines from output files.
4. **Subagents read files themselves** in their own fresh context window.
5. **Re-orient after every subagent completes.** Re-read `$PLANNING_DIR/run-state.json` and verify FEATURE/PLANNING_DIR variables are still set. If context was compressed and you lost track, re-read `$PLANNING_DIR/STATE.md` to recover current position.

```
phases_to_process = [phases with status != complete, ordered by phase number]

For each phase in phases_to_process:
  Display phase header
  Run Step 2.A if needs_planning
  Run Step 2.B if has unexecuted plans
  Run Step 2.C if workflow.verifier enabled
  Run Step 2.D to complete and commit
  Update run-state.json cursor
```

Display at start of each phase:
```
FD > PHASE {N}: {phase_name}
 Status:     {needs_planning | needs_execution | needs_verification}
 Difficulty: {simple | moderate | complex}
```

---

### Step 2.A: Plan (if status == needs_planning)

#### 2.A.0: Determine workflow path based on difficulty

If `workflow.difficulty_aware` is `true`, adapt the planning pipeline per phase:

- **simple** phases: Skip research AND plan-check. Go directly: CONTEXT.md check -> Plan -> done.
- **moderate** phases: Skip research only. Go: CONTEXT.md check -> Plan -> Plan-check -> (revision if needed) -> done.
- **complex** phases: Full pipeline. Go: CONTEXT.md check -> Research -> Plan -> Plan-check -> (revision if needed) -> done.

Display the workflow path:
```
Phase {N} ({phase_name}): difficulty={difficulty} -> {workflow_path}
```

**Adaptive model selection:** If `model_profile` is `"adaptive"`, select the model profile for this phase's subagents based on difficulty:
- simple -> budget profile
- moderate -> balanced profile
- complex -> quality profile

#### 2.A.1: Check for existing CONTEXT.md

CONTEXT.md is created by `/fd:discuss-phase` and contains user decisions and clarifications.

```bash
ls $PLANNING_DIR/phases/${PHASE_DIR}/*-CONTEXT.md 2>/dev/null | head -1
```

Note whether CONTEXT.md exists and its path. Do NOT read its contents -- the subagent will read it.

#### 2.A.2: Research (if enabled, background subagent)

Only if `workflow.research` is `true` AND no RESEARCH.md exists yet for this phase.

```bash
ls $PLANNING_DIR/phases/${PHASE_DIR}/*-RESEARCH.md 2>/dev/null | head -1
```

If RESEARCH.md does not exist, spawn fd-phase-researcher as a **background subagent**:

```
bg_research = Task(
  prompt="First, read /root/.claude/agents/fd-phase-researcher.md for your role and instructions.

Phase: {phase_name}
Phase directory: $PLANNING_DIR/phases/{phase_dir}/
Phase goal (from ROADMAP): {phase_goal_text}
PLANNING_DIR: $PLANNING_DIR/

Read these files for context (read them yourself, they are NOT pasted here):
- State: $PLANNING_DIR/STATE.md
- Context (if exists): $PLANNING_DIR/phases/{phase_dir}/{NN}-CONTEXT.md

Use Grep/Glob/Read to explore the codebase directly for relevant code. Do NOT rely on pre-loaded dumps.

Research this phase's requirements and write RESEARCH.md to the phase directory.

IMPORTANT: Your final response to the lead must be ONLY a single status line:
'STATUS: complete -- RESEARCH.md written to $PLANNING_DIR/phases/{phase_dir}/'",
  description="Research Phase {N}: {phase_name}",
  subagent_type="fd-phase-researcher",
  run_in_background=true
)
```

Wait for completion:
```
TaskOutput(task_id=bg_research.task_id, block=true, timeout=300000)
```

Verify file was created:
```bash
ls $PLANNING_DIR/phases/${PHASE_DIR}/*-RESEARCH.md
```

Display:
```
Researcher (background): Phase {N}...
Researcher complete: RESEARCH.md written
```

#### 2.A.3: Plan (background subagent, file-path handoff)

Spawn fd-planner as a **background subagent**. Pass FILE PATHS, not file contents:

```
bg_plan = Task(
  prompt="First, read /root/.claude/agents/fd-planner.md for your role and instructions.

Phase: {phase_name}
Phase number: {phase_number}
Phase directory: $PLANNING_DIR/phases/{phase_dir}/
Phase goal (from ROADMAP): {phase_goal_text}
PLANNING_DIR: $PLANNING_DIR/

Read these files for context (read them yourself, they are NOT pasted here):
- Roadmap: $PLANNING_DIR/ROADMAP.md
- State: $PLANNING_DIR/STATE.md
- Requirements: $PLANNING_DIR/REQUIREMENTS.md (if exists)
- Context: $PLANNING_DIR/phases/{phase_dir}/{NN}-CONTEXT.md (if exists)
- Research: $PLANNING_DIR/phases/{phase_dir}/{NN}-RESEARCH.md (if exists)
- Existing plans from earlier phases: check $PLANNING_DIR/phases/ for other phase directories

Use Grep/Glob/Read to explore the codebase directly for relevant code. Do NOT rely on pre-loaded dumps.

Create detailed PLAN.md files for this phase. Each plan should include wave and depends_on frontmatter.

IMPORTANT: Your final response to the lead must be ONLY a single status line:
'STATUS: complete -- {N} plans created in $PLANNING_DIR/phases/{phase_dir}/'",
  description="Plan Phase {N}: {phase_name}",
  subagent_type="fd-planner",
  run_in_background=true
)
```

Wait for completion:
```
TaskOutput(task_id=bg_plan.task_id, block=true, timeout=300000)
```

Verify plan files were created:
```bash
ls $PLANNING_DIR/phases/${PHASE_DIR}/*-PLAN.md
```

Display:
```
Planner (background): Phase {N}...
Planner complete: {X} plans created
```

#### 2.A.4: Verify plans (if enabled, background subagent)

Only if `workflow.plan_check` is `true`.

Spawn fd-plan-checker as a **background subagent**. It reads plan files itself:

```
bg_check = Task(
  prompt="First, read /root/.claude/agents/fd-plan-checker.md for your role and instructions.

Phase: {phase_name}
Phase directory: $PLANNING_DIR/phases/{phase_dir}/
PLANNING_DIR: $PLANNING_DIR/

Read these files yourself:
- All PLAN.md files in $PLANNING_DIR/phases/{phase_dir}/
- Roadmap: $PLANNING_DIR/ROADMAP.md
- Requirements: $PLANNING_DIR/REQUIREMENTS.md (if exists)
- Context: $PLANNING_DIR/phases/{phase_dir}/{NN}-CONTEXT.md (if exists)

Review these plans for completeness, correctness, and alignment with the roadmap.

Write your full findings to $PLANNING_DIR/phases/{phase_dir}/{NN}-PLAN-CHECK.md

IMPORTANT: Your final response to the lead must be ONLY a single status line:
'STATUS: passed' if no blockers found
'STATUS: {N} blockers found -- needs revision' if issues exist",
  description="Check Phase {N} plans",
  subagent_type="fd-plan-checker",
  run_in_background=true
)
```

Wait for completion:
```
TaskOutput(task_id=bg_check.task_id, block=true, timeout=300000)
```

Parse the brief status from the result. Only look for "passed" or "blockers found".

Display:
```
Plan checker (background): Phase {N}...
Plan checker complete: {passed / N blockers found}
```

#### 2.A.5: Revision loop (if checker found blockers)

If the checker found blockers, spawn the planner again with revision context. Maximum 3 revision iterations per phase.

```
revision_count = 0
while checker_found_blockers AND revision_count < 3:
  revision_count++

  Display:
    Phase {N} checker: {M} blockers found -- needs revision {revision_count}/3...

  # Revision planner -- reads checker feedback FILE, not content
  bg_revise = Task(
    prompt="First, read /root/.claude/agents/fd-planner.md for your role and instructions.

MODE: REVISION

Phase: {phase_name}
Phase directory: $PLANNING_DIR/phases/{phase_dir}/
PLANNING_DIR: $PLANNING_DIR/

Read these files yourself:
- Checker feedback: $PLANNING_DIR/phases/{phase_dir}/{NN}-PLAN-CHECK.md
- All existing PLAN.md files in $PLANNING_DIR/phases/{phase_dir}/
- Roadmap: $PLANNING_DIR/ROADMAP.md

Revise the plans to address the checker's issues.

IMPORTANT: Your final response must be ONLY:
'STATUS: revised -- {N} plans updated'",
    description="Revise Phase {N} plans (attempt {revision_count})",
    subagent_type="fd-planner",
    run_in_background=true
  )

  TaskOutput(task_id=bg_revise.task_id, block=true, timeout=300000)

  # Re-check
  bg_recheck = Task(
    prompt="First, read /root/.claude/agents/fd-plan-checker.md for your role and instructions.

Phase: {phase_name}
Phase directory: $PLANNING_DIR/phases/{phase_dir}/
PLANNING_DIR: $PLANNING_DIR/

Read these files yourself:
- All PLAN.md files in $PLANNING_DIR/phases/{phase_dir}/
- Roadmap: $PLANNING_DIR/ROADMAP.md
- Requirements: $PLANNING_DIR/REQUIREMENTS.md (if exists)

Re-check the revised plans. Write findings to $PLANNING_DIR/phases/{phase_dir}/{NN}-PLAN-CHECK.md (overwrite previous).

IMPORTANT: Your final response must be ONLY:
'STATUS: passed' or 'STATUS: {N} blockers found -- needs revision'",
    description="Re-check Phase {N} plans (attempt {revision_count})",
    subagent_type="fd-plan-checker",
    run_in_background=true
  )

  TaskOutput(task_id=bg_recheck.task_id, block=true, timeout=300000)
  Parse status from result.
```

After revision loop completes (either passed or max iterations reached):
```
Plans finalized for Phase {N} (revision {revision_count})
```

#### 2.A.6: Update STATE.md

After planning completes for this phase, update STATE.md to reflect the phase is now planned.

---

### Step 2.B: Execute (if phase has unexecuted plans)

Check if this phase has PLAN.md files without corresponding SUMMARY.md files. If all plans already have summaries, skip execution.

#### 2.B.1: Parse plans and build wave schedule

For each unexecuted PLAN.md in this phase, extract from frontmatter:
- `wave` number
- `depends_on` list

Group plans by wave. Plans in the same wave execute in parallel. Waves execute sequentially.

```bash
# Check which plans need execution
for f in $PLANNING_DIR/phases/${PHASE_DIR}/*-PLAN.md; do
  summary=$(echo "$f" | sed 's/-PLAN\.md/-SUMMARY.md/')
  [ ! -f "$summary" ] && echo "needs_execution: $f"
done
```

Display:
```
Phase {N} execution schedule:
  Wave 1: {plan_a}, {plan_b} (parallel)
  Wave 2: {plan_c} (depends on wave 1)
```

#### 2.B.2: Execute wave-by-wave

For each wave (sequential):

**Spawn 1 background subagent per plan in this wave (parallel):**

All subagents in the same wave are spawned in a SINGLE message with multiple Task calls.

```
For each plan in current_wave:

  bg_exec = Task(
    prompt="You are an FD executor. Read /root/.claude/agents/fd-executor.md for your instructions.

TASK: Execute plan {plan_id}
Plan file: $PLANNING_DIR/phases/{phase_dir}/{plan_filename}
Phase: {phase_name}
Phase dir: $PLANNING_DIR/phases/{phase_dir}/
Phase goal: {phase_goal}
PLANNING_DIR: $PLANNING_DIR/

Read these files before starting:
- Plan file (above)
- Dependency SUMMARYs: {list of dependency summary paths or 'None'}
- Deviation memory: $PLANNING_DIR/deviation-memory.md (if exists)

Execute ALL tasks in the plan:
1. Read the plan file
2. Execute each task sequentially (atomic commit per task)
3. Create {plan_id}-SUMMARY.md when done
4. Stage files individually (never git add . or git add -A)
5. Never modify $PLANNING_DIR/STATE.md or $PLANNING_DIR/ROADMAP.md

IMPORTANT: Your final response must be ONLY:
'STATUS: complete -- {N}/{N} tasks done, {M} deviations'
or 'STATUS: error -- {description}'",
    description="Execute {plan_id}",
    subagent_type="fd-executor",
    mode="bypassPermissions",
    run_in_background=true
  )
```

**Wait for all subagents in this wave:**

```
For each bg_exec in current_wave:
  TaskOutput(task_id=bg_exec.task_id, block=true, timeout=600000)
```

**Check results:**

For each completed subagent, check:
1. Parse STATUS line from result
2. Verify SUMMARY.md exists: `ls $PLANNING_DIR/phases/${PHASE_DIR}/{plan_id}-SUMMARY.md`

Display per-wave progress:
```
Wave {W}: {completed}/{total} plans done
```

#### 2.B.3: Handle failures

For each plan that returned "STATUS: error":

```
retry_count = 0
while error AND retry_count < repair.max_retries:
  retry_count++

  # Idempotency check
  if SUMMARY.md exists for this plan: skip retry

  # Write error context to file for retry subagent
  # (error details are in the TaskOutput result)

  bg_retry = Task(
    prompt="You are an FD executor. Read /root/.claude/agents/fd-executor.md for your instructions.

RETRY: Execute plan {plan_id} (attempt {retry_count + 1})
Plan file: $PLANNING_DIR/phases/{phase_dir}/{plan_filename}
Phase dir: $PLANNING_DIR/phases/{phase_dir}/
PLANNING_DIR: $PLANNING_DIR/

Previous attempt failed. Check git log for partial commits from prior attempt.
If partial work exists, continue from where it left off.

Execute ALL remaining tasks, create SUMMARY.md, commit.

IMPORTANT: Your final response must be ONLY:
'STATUS: complete -- {N}/{N} tasks done, {M} deviations'
or 'STATUS: error -- {description}'",
    description="Retry {plan_id} (attempt {retry_count + 1})",
    subagent_type="fd-executor",
    mode="bypassPermissions",
    run_in_background=true
  )

  TaskOutput(task_id=bg_retry.task_id, block=true, timeout=600000)
  Check result
```

After max retries: log as gap for verification/gap-closure loop.

Display execution summary:
```
FD > PHASE {N} EXECUTION COMPLETE
Completed: {N}/{M} plans
Errors: {E} plans (will be logged as gaps)
```

---

### Step 2.C: Verify (if workflow.verifier enabled)

If `workflow.verifier` is `false`, skip verification. Mark phase as complete and proceed to Step 2.D.

#### 2.C.1: Spawn verifier (background subagent)

```
bg_verify = Task(
  prompt="First, read /root/.claude/agents/fd-verifier.md for your role and instructions.

Phase: {phase_name}
Phase directory: $PLANNING_DIR/phases/{phase_dir}/
Phase goal (from ROADMAP): {phase_goal_text}
PLANNING_DIR: $PLANNING_DIR/

Read these files yourself:
- All PLAN.md and SUMMARY.md files in $PLANNING_DIR/phases/{phase_dir}/
- Requirements: $PLANNING_DIR/REQUIREMENTS.md (if exists, extract requirements relevant to this phase)

Use Grep/Glob/Read to explore the codebase directly for verification. Do NOT rely on pre-loaded dumps.

Verify that all plans were executed correctly and the phase goal is met.
Write {phase}-VERIFICATION.md to the phase directory.

IMPORTANT: Your final response to the lead must be ONLY a single status line:
'STATUS: passed' if all criteria met
'STATUS: gaps_found -- {N} gaps identified' if issues found
'STATUS: human_needed -- {description}' if human verification required",
  description="Verify Phase {N}: {phase_name}",
  subagent_type="fd-verifier",
  run_in_background=true
)
```

Wait for completion:
```
TaskOutput(task_id=bg_verify.task_id, block=true, timeout=300000)
```

Parse the brief status from the result.

Display:
```
Verifier (background): Phase {N}...
Verifier complete: {passed / gaps_found / human_needed}
```

#### 2.C.2: Handle verification result

- `passed` -> Phase is complete. Proceed to Step 2.D.
- `human_needed` -> Display items to user. Proceed to Step 2.D (with note).
- `gaps_found` -> Enter gap loop (2.C.3).

#### 2.C.3: Gap loop (if gaps_found)

```
gap_iteration = 0
max_iterations = agent_team.max_gap_loops (from config, default: 3)

while gaps_found AND gap_iteration < max_iterations:
  gap_iteration++
```

Display:
```
FD > PHASE {N} GAP CLOSURE (iteration {gap_iteration}/{max_iterations})
```

**2.C.3a: Re-plan with localized repair (background subagent)**

Spawn fd-planner with gap closure context:

```
bg_gap_plan = Task(
  prompt="First, read /root/.claude/agents/fd-planner.md for your role and instructions.

MODE: GAP CLOSURE (LOCALIZED REPAIR)

Phase: {phase_name}
Phase directory: $PLANNING_DIR/phases/{phase_dir}/
PLANNING_DIR: $PLANNING_DIR/

Read these files yourself:
- Verification report: $PLANNING_DIR/phases/{phase_dir}/{NN}-VERIFICATION.md (contains gaps to fix)
- All existing PLAN.md files in $PLANNING_DIR/phases/{phase_dir}/
- All existing SUMMARY.md files in $PLANNING_DIR/phases/{phase_dir}/

IMPORTANT: Create targeted repair plan(s) that ONLY address the specific gaps in VERIFICATION.md.
- max_edit_radius: Only touch files directly related to each gap.
- Name with next available plan number.
- Set wave: 1 for all gap closure plans.

IMPORTANT: Your final response must be ONLY:
'STATUS: complete -- {N} gap closure plans created'",
  description="Gap Plan Phase {N} (iteration {gap_iteration})",
  subagent_type="fd-planner",
  run_in_background=true
)

TaskOutput(task_id=bg_gap_plan.task_id, block=true, timeout=300000)
```

**2.C.3b: Execute gap closure plans (background subagents)**

Follow the same wave-based background subagent pattern as Step 2.B:
1. Parse gap closure plans, group by wave
2. Spawn 1 background subagent per plan (parallel within wave)
3. Wait all (TaskOutput block=true)
4. Retry failures (fresh subagent per retry)

**2.C.3c: Re-verify (background subagent)**

Spawn verifier again (same pattern as 2.C.1).

Parse result:
- `passed` -> Break gap loop. Proceed to Step 2.D.
- `gaps_found` -> Continue gap loop.
- `human_needed` -> Display items. Break gap loop.

```
  end while
```

If `gap_iteration == max_iterations` AND gaps still exist:
```
FD > PHASE {N} GAP CLOSURE EXHAUSTED
WARNING: Maximum gap closure iterations ({max_iterations}) reached.
Manual intervention may be required.
```

---

### Step 2.D: Complete Phase

#### 2.D.1: Update tracking files

For phases that passed verification (or skipped verification):

1. Update ROADMAP.md: Mark phase as complete (checkbox ticked)
2. Update STATE.md: Update phase status to `complete`, update current position
3. Update REQUIREMENTS.md: Mark phase requirements as `Complete` (if REQUIREMENTS.md exists)

#### 2.D.2: Commit phase completion

**If `COMMIT_PLANNING_DOCS=false`:** Skip git operations, log "Skipping planning docs commit"

**If `COMMIT_PLANNING_DOCS=true` (default):**

```bash
git add $PLANNING_DIR/ROADMAP.md $PLANNING_DIR/STATE.md $PLANNING_DIR/phases/{phase_dir}/*-VERIFICATION.md
```

If REQUIREMENTS.md was updated:
```bash
git add $PLANNING_DIR/REQUIREMENTS.md
```

```bash
git commit -m "docs({phase_name}): complete {phase_name} phase"
```

**Always stage files individually by their full path. NEVER use `git add .` or `git add -A`.**

#### 2.D.3: Update run-state.json cursor

Write current position to `$PLANNING_DIR/run-state.json` for recovery:

```json
{
  "current_phase": {N},
  "phase_step": "complete",
  "wave": 0,
  "gap_iteration": 0
}
```

#### 2.D.4: Display phase complete

```
FD > PHASE {N} ({phase_name}): COMPLETE
Plans: {X} executed
Verification: {passed / gaps_remaining}

Moving to next phase...
```

---

**End of per-phase loop.** Repeat Phase 2 for the next phase in `phases_to_process`.

---

## Phase 3: Cleanup & Completion

### Step 3.1: Persist deviation memory (cross-session learning)

After all execution is complete, extract deviations from all SUMMARY.md files across all phases:

1. Scan all SUMMARY.md files for deviation mentions (look for "deviation", "workaround", "unexpected", "changed approach", "differed from plan").

2. If new unique deviation patterns are found, append them to `$PLANNING_DIR/deviation-memory.md`:

```markdown
# Deviation Memory

Accumulated patterns from past runs. Provided to executors to avoid repeating mistakes.

| Pattern | Fix | Category | Source Task | Frequency | Last Seen |
|---------|-----|----------|-------------|-----------|-----------|
| {description of what went wrong} | {how it was resolved} | {rule category} | {originating task} | {count} | {date} |
```

3. If the file already exists, merge new patterns: increment frequency for duplicates, add new rows for novel patterns.

4. Stage and commit if `COMMIT_PLANNING_DOCS=true`:
```bash
git add $PLANNING_DIR/deviation-memory.md
git commit -m "docs: update deviation memory after fd:run"
```

### Step 3.2: Handle any uncommitted orchestrator changes

```bash
git status --porcelain $PLANNING_DIR/
```

If there are uncommitted changes:
```bash
git add $PLANNING_DIR/STATE.md $PLANNING_DIR/ROADMAP.md
git commit -m "docs: update project state after fd:run"
```

### Step 3.3: Clean up run-state.json

Delete the cursor file on successful completion:
```bash
rm -f $PLANNING_DIR/run-state.json
```

### Step 3.4: Display final status

**If ALL phases are complete (no gaps):**

```
FD > ALL PHASES COMPLETE

Project:      {project_name}
Feature:      $FEATURE
Phases:       {N} completed
Plans:        {M} executed
Verification: All phases verified

## Stats

| Phase          | Plans | Status     |
|----------------|-------|------------|
| 01-setup       | 3     | Verified   |
| 02-auth        | 4     | Verified   |
| 03-content     | 3     | Verified   |

## Next Steps

- /fd:run $FEATURE -- run again (will pick up any new unfinished work)
- Manual acceptance testing can be done by reviewing verification reports
```

**If some phases have unresolved gaps:**

```
FD > RUN COMPLETE (with gaps)

{N} phases completed, {M} phases have unresolved gaps.

## Stats

| Phase          | Plans | Status            |
|----------------|-------|-------------------|
| 01-setup       | 3     | Verified          |
| 02-auth        | 4     | Gaps remaining    |
| 03-content     | 3     | Verified          |

## Unresolved Gaps

**Phase 02-auth:**
- {gap description from VERIFICATION.md}

## Next Steps

- /fd:run $FEATURE -- retry gap closure
- /fd:discuss-phase 02-auth -- discuss approach for problematic phase
- Manual fix then /fd:run $FEATURE to re-verify
```

</process>

<execution_architecture>

## Background Subagent Execution

All work is done by background subagents (Task with run_in_background=true). No Agent Teams.

### Why Background Subagents (not Agent Teams)

Agent Teams (TeamCreate/SendMessage/TaskList) have known issues:
- Context compaction causes lead to lose team awareness
- Crashed teammates leave zombie tmux sessions preventing TeamDelete
- Complex coordination protocol (SendMessage, shutdown_request, orphan detection)

Background subagents are simpler and more reliable:
- 1 subagent = 1 task (context never accumulates)
- Shared state = filesystem (git commits, SUMMARY.md files)
- Retry = spawn fresh subagent with full 200K context
- Parallel = multiple background Tasks in single message
- No coordination protocol needed

### Execution Pattern

```
For each wave (sequential):
  Spawn 1 background subagent per plan (parallel, run_in_background=true)
  Wait all (TaskOutput block=true)
  Check results (STATUS line from each)
  Retry failures (fresh subagent per retry)
Next wave
```

### State Recovery

Lead writes cursor position to `$PLANNING_DIR/run-state.json` after each step:
```json
{
  "current_phase": 3,
  "phase_step": "execute",
  "wave": 2,
  "gap_iteration": 0
}
```

Task status is derived from filesystem:
- SUMMARY.md exists -> plan executed
- VERIFICATION.md exists -> phase verified
- No state file bloat -- just a cursor

</execution_architecture>

<commit_rules>
**Per-Task Commits:** Done by executor subagents. Each subagent commits per-task during execution.

**Phase Completion Commits:** Done by the lead (you):
1. After each phase verification passes (in Step 2.D)
2. Stage specific files individually:
   - $PLANNING_DIR/ROADMAP.md
   - $PLANNING_DIR/STATE.md
   - $PLANNING_DIR/REQUIREMENTS.md (only if updated)
   - $PLANNING_DIR/phases/{phase_dir}/*-VERIFICATION.md
3. Commit message format: `docs({phase}): complete {phase-name} phase`

**Orchestrator State Commits:** Done by the lead (you):
1. After all phases complete or gap loop exhausts (in Phase 3)
2. Stage only $PLANNING_DIR/ metadata files
3. Commit message format: `docs: update project state after fd:run`

**NEVER use:**
- `git add .`
- `git add -A`
- `git add src/` or any broad directory pattern

**Always stage files individually by their full path.**
</commit_rules>

<error_handling>

### Executor Subagent Failures

If a background executor subagent fails (TaskOutput returns error or STATUS: error):
1. Check if SUMMARY.md was created anyway (partial success)
2. If SUMMARY exists: plan is done, proceed
3. If SUMMARY missing: check git log for partial commits
4. Retry with fresh subagent (up to repair.max_retries)
5. Fresh subagent gets full 200K context -- can read error context and continue
6. After max retries: log as gap for gap closure loop

### Background Subagent Failures

If a background subagent fails (TaskOutput returns error):
1. Check if the expected output file was created anyway (partial success)
2. If file exists, proceed with next step
3. If file missing, retry the subagent once
4. If still failing, display error and ask user for guidance

### Missing Files

If expected files are missing (PLAN.md, SUMMARY.md, etc.):
1. Check if the subagent created them in a different location
2. Check git status for recently created files
3. If truly missing, treat as a failed execution and retry

### Config Errors

If config.json is malformed or missing required fields:
1. Display the error clearly
2. Use defaults where possible:
   - workflow.research: true
   - workflow.plan_check: true
   - workflow.verifier: true
   - agent_team.max_gap_loops: 3
   - agent_team.max_parallel: 4
3. Ask user to fix config.json if critical fields are missing

### Git Conflicts

If git operations fail:
1. Display the conflict/error
2. Do NOT attempt to resolve merge conflicts automatically
3. Ask the user to resolve and then re-run /fd:run

</error_handling>

<monitoring_patterns>

## Lead Monitoring

The lead uses TaskOutput(block=true) to wait for background subagents. No polling, no sleep, no event-driven messages.

Per wave:
1. Spawn all subagents in wave (parallel)
2. TaskOutput(block=true) for each (sequential wait)
3. Parse STATUS from each result
4. Log progress
5. Handle errors (retry with fresh subagent)
6. Next wave

Context stays lean because:
- run_in_background=true -> full output goes to file, NOT lead context
- Lead only sees brief STATUS line per subagent
- State derived from filesystem, not accumulated in memory

</monitoring_patterns>

<phase_flow_summary>

## Complete Phase Flow

```
Phase 0: Load Config
  - Validate $PLANNING_DIR/ exists
  - Read config.json, ROADMAP.md, STATE.md
  - Note deviation-memory.md path (cross-session learning)
  - Check run-state.json for recovery
  - Codebase context: just-in-time (agents grep/glob on demand)
  - Display config summary

Phase 1: Scan & Identify Work
  - Discover phases from ROADMAP.md
  - Classify: needs_planning, needs_execution, needs_verification, complete
  - Classify difficulty: simple / moderate / complex (if difficulty_aware)
  - If ALL complete -> skip to Phase 3

Phase 2: Per-Phase Pipeline (for each phase, sequential)
  - For each phase needing work:
      |
      +- Step 2.A: Plan (if needs_planning)
      |   +- Determine workflow path by difficulty
      |   +- Check CONTEXT.md exists (note path only)
      |   +- Research (bg subagent -> writes RESEARCH.md)
      |   +- Plan (bg subagent, file-path handoff -> writes PLAN.md files)
      |   +- Check plans (bg subagent -> writes PLAN-CHECK.md)
      |   +- Revision loop (bg subagents, max 3)
      |   +- Update STATE.md
      |
      +- Step 2.B: Execute (if has unexecuted plans)
      |   +- Parse plans, group by wave
      |   +- Per wave: spawn parallel background subagents
      |   +- Wait all (TaskOutput block=true)
      |   +- Retry failures (fresh subagent)
      |   +- Check all SUMMARYs exist
      |
      +- Step 2.C: Verify (if workflow.verifier enabled)
      |   +- Verifier (bg subagent -> writes VERIFICATION.md)
      |   +- Parse result (just status line)
      |   +- Gap loop if needed:
      |       +- Re-plan (bg subagent, localized repair)
      |       +- Execute gap plans (bg subagents, wave-based)
      |       +- Re-distill aid (if enabled)
      |       +- Re-verify (bg subagent)
      |
      +- Step 2.D: Complete Phase
          +- Update ROADMAP.md, STATE.md, REQUIREMENTS.md
          +- Commit phase completion
          +- Update run-state.json cursor
          +- Display phase complete

Phase 3: Cleanup & Completion
  - 3.1: Persist deviation memory
  - 3.2: Commit orchestrator changes
  - 3.3: Delete run-state.json
  - 3.4: Display final status
```

</phase_flow_summary>

<success_criteria>
- [ ] Feature name argument parsed and validated
- [ ] $PLANNING_DIR set to .fd/planning/$FEATURE
- [ ] Config loaded and validated from .fd/config.json
- [ ] Phases classified by difficulty (if difficulty_aware)
- [ ] **Per-phase pipeline**: each phase processed completely (plan->execute->verify) before next
- [ ] **Background subagents**: all subagents use run_in_background=true
- [ ] **File-path handoff**: lead passes file paths to subagents, NEVER reads file contents into own context
- [ ] **Brief status only**: lead only reads status lines from subagent results, never full reports
- [ ] **PLANNING_DIR passed to all subagents** as context in Task prompts
- [ ] Workflow adapted per difficulty: simple skips research+check, moderate skips research, complex full pipeline
- [ ] Plans created via background planner subagent (writes to files)
- [ ] Plan checker writes findings to PLAN-CHECK.md file (background subagent)
- [ ] Executor subagents spawned per wave (background, parallel)
- [ ] Fresh subagent for retries (full context recovery)
- [ ] State file updated per step ($PLANNING_DIR/run-state.json)
- [ ] Failed executors handled with repair policy
- [ ] Verification via background verifier subagent (writes VERIFICATION.md)
- [ ] Gap closure uses localized repair (background subagents for both planning and execution)
- [ ] Tracking files (STATE.md, ROADMAP.md, REQUIREMENTS.md) updated after each phase
- [ ] Phase completion committed after each phase
- [ ] Deviation memory persisted after all phases
- [ ] Individual file staging for all git commits (no broad adds)
- [ ] Codebase context via just-in-time discovery (agents use Grep/Glob/Read)
- [ ] Lead context stayed lean throughout (~10-15%)
- [ ] User informed of final status and next steps
</success_criteria>
