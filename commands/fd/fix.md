---
name: fd:fix
description: Execute a fix plan from /fd:planner with review loop. Reads .fd/plans/{NN}.md, executes steps with sonnet subagents, reviews with opus until all 7 dimensions pass. Use after /fd:planner produces a fix plan.
argument-hint: "<plan-number> (e.g. 01, 02)"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
  - Agent
  - AskUserQuestion
---

<objective>
Execute a fix plan and iterate until the fix passes a strict 7-dimension review.

**Architecture:**
- Lead (you): orchestrate only — read plan, spawn agents, check results
- Fixer agents: `model="sonnet"`, execute plan steps, write code
- Reviewer agent: `model="opus"`, review fix against 7 dimensions
- Loop until review passes or max 5 iterations

**Input:** `.fd/plans/{NN}-*.md` (from `/fd:planner`)
**Output:** `.fd/fixes/{NN}-*.md` (fix report with review history)
</objective>

<process>

**BAHASA & GAYA:**
- Output ke user pakai Bahasa Indonesia. Santai.
- Commit messages dan fix report tetap English.

---

## STEP 1 — Load Plan

Parse `$ARGUMENTS` as plan number (NN).

```bash
ls .fd/plans/${NN}-*.md 2>/dev/null | head -1
```

If not found:
```
ERROR: Plan .fd/plans/{NN}-*.md not found.
Jalankan /fd:planner {NN} dulu.
```

Read the plan file. Extract:
- `bug` from frontmatter (links back to bug report)
- `fix-type` from frontmatter
- `approach` from frontmatter
- `risk` from frontmatter
- All fix steps (Step 1, Step 2, etc.)
- Tests/verification needed
- Codebase patterns section

Also read the linked bug report:
```bash
ls .fd/bugs/${NN}-*.md 2>/dev/null | head -1
```

Extract root cause from bug report — reviewer needs this to check correctness.

**Check for existing fix report:**
```bash
ls .fd/fixes/${NN}-*.md 2>/dev/null | head -1
```
If exists, ask user:
```
Fix report .fd/fixes/{NN}-*.md sudah ada dari run sebelumnya.
Overwrite atau cancel?
```
If cancel → stop.

**Check for clean working tree:**
```bash
git status --porcelain
```
If dirty (has uncommitted changes), warn user:
```
Working tree kotor — ada uncommitted changes.
Commit atau stash dulu sebelum jalankan fd:fix, biar fixer agents ga bingung.
```
Stop and wait for user to clean up.

**Save base commit hash** (needed for reviewer git diff later):
```bash
BASE_HASH=$(git rev-parse HEAD)
```

**Create worktree for fix:**

```bash
# Derive slug from plan filename
FIX_SLUG=$(ls .fd/plans/${NN}-*.md 2>/dev/null | head -1 | sed 's|.fd/plans/||;s|\.md||' | sed 's/^[0-9]*-//')
WORKTREE_BRANCH="fd/fix-${FIX_SLUG}"
WORKTREE_PATH=".claude/worktrees/fd-fix-${FIX_SLUG}"

# Check if worktree already exists
if [ -d "$WORKTREE_PATH" ]; then
  echo "Worktree sudah ada: $WORKTREE_PATH"
fi
```

**If worktree exists:** Ask user:
```
Worktree untuk fix "${FIX_SLUG}" sudah ada di ${WORKTREE_PATH}.
Lanjutkan dari yang ada, atau mulai fresh?
```
- **Continue** → use existing
- **Fresh start** → `git worktree remove $WORKTREE_PATH && git branch -D $WORKTREE_BRANCH` then recreate

**If worktree doesn't exist:** Create it:
```bash
mkdir -p .claude/worktrees
git worktree add -b "$WORKTREE_BRANCH" "$WORKTREE_PATH" HEAD
```

**Copy bug/plan files into worktree:**
```bash
mkdir -p "$WORKTREE_PATH/.fd/bugs" "$WORKTREE_PATH/.fd/plans"
cp .fd/bugs/${NN}-*.md "$WORKTREE_PATH/.fd/bugs/"
cp .fd/plans/${NN}-*.md "$WORKTREE_PATH/.fd/plans/"
```

**Set context for all agents:**
```
WORKTREE_ABS=$(cd "$WORKTREE_PATH" && pwd)
BASE_HASH=$(cd "$WORKTREE_PATH" && git rev-parse HEAD)
```

All fixer and reviewer agents receive in their prompt: `WORKTREE: $WORKTREE_ABS — all file operations and git commands inside this directory.`

Announce:
```
Loading plan: .fd/plans/{NN}-{slug}.md
Bug: .fd/bugs/{NN}-{slug}.md
Fix type: {fix-type}
Risk: {risk}
Steps: {N}

Mulai eksekusi...
```

---

## STEP 2 — Execute Fix Steps

For each step in the plan, spawn a fixer subagent:

```
Agent(
  prompt="You are a fixer agent. Execute this fix step precisely.

Working directory: $WORKTREE_ABS

CONTEXT:
- Bug report: .fd/bugs/{NN}-{slug}.md (read this for full context)
- Full plan: .fd/plans/{NN}-{slug}.md (read this for all steps)
- You are executing Step {N} of {total}

STEP {N}: {step title}
- Area: {area from plan}
- Problem: {problem from plan}
- Direction: {direction from plan}
- Constraints: {constraints from plan}
- Gate: {gate from plan}

RULES:
1. Read the actual current code BEFORE making changes
2. Follow the direction — don't improvise a different approach
3. Respect constraints listed in the plan
4. Follow existing codebase patterns and conventions
5. Make minimum necessary changes — surgical, not over-engineered
6. After making changes, verify the gate condition
7. If changes were made: stage files individually (never git add . or git add -A) and commit with message: fix({scope}): {what this step does}
8. If step requires no code changes (e.g. verification-only), skip commit and report gate result

IMPORTANT: Report back what you changed, what files were modified, and whether the gate passed.",
  subagent_type="coder",
  model="sonnet",
  mode="bypassPermissions",
  description="Fix step {N}: {title}"
)
```

Wait for completion. Check result.

**If step fails:** retry once with error context. If still fails, stop and ask user.

**Between steps:** verify previous step's gate before proceeding to next.

After all steps complete:
```
Semua {N} steps selesai. Mulai review...
```

---

## STEP 3 — Review Loop

```
iteration = 0
max_iterations = 5

while iteration < max_iterations:
  iteration++
```

### 3.A — Spawn Reviewer (opus)

```
Agent(
  prompt="You are a senior code reviewer performing a post-fix review.

Working directory: $WORKTREE_ABS — run git diff inside this directory.

CONTEXT:
Read these files first:
- Bug report: .fd/bugs/{NN}-{slug}.md (root cause and symptoms)
- Fix plan: .fd/plans/{NN}-{slug}.md (intended approach)

Then examine the ACTUAL changes made. Use these commands:
- git diff {BASE_HASH}..HEAD to see ALL changes since fix started (includes fix steps + review iterations)
- git log --oneline {BASE_HASH}..HEAD to see all fix-related commits
- Read the modified files in full to understand context

REVIEW DIMENSIONS — Score each as PASS or FAIL with evidence:

### 1. Performance
- No unnecessary computation on hot paths
- No N+1 queries or redundant API calls
- No memory leaks or unbounded growth
- No unnecessary re-renders (frontend)
- Bundle size impact acceptable
PASS if: no performance degradation introduced
FAIL if: measurable negative impact on perf

### 2. Code Quality
- Clean, readable, concise
- DRY — no duplicated logic
- Single responsibility per function/module
- Proper error handling at system boundaries
- Full type safety (no any, no type assertions unless justified)
- No dead code, no commented-out code
PASS if: code is clean and maintainable
FAIL if: introduces tech debt or code smells

### 3. Security
- No injection vulnerabilities (SQL, command, XSS)
- No auth/authz bypass
- No sensitive data exposure (logs, errors, responses)
- Input validation at system boundaries
- No hardcoded secrets or credentials
PASS if: no security concerns
FAIL if: any security vulnerability introduced or exposed

### 4. AI-Readable
- Clear, descriptive naming (functions, variables, types)
- Predictable code structure — no surprises
- Self-documenting — logic is obvious from reading
- No magic numbers or strings (use constants/enums)
- No clever tricks that require comments to explain
PASS if: another AI or junior dev can understand without asking questions
FAIL if: requires tribal knowledge or deep context to understand

### 5. Well-Organized
- Changes in the right file(s) and right layer
- Follows existing codebase conventions and patterns
- Proper separation of concerns
- Imports organized, no circular dependencies
- File naming follows project conventions
PASS if: feels like it belongs in this codebase
FAIL if: breaks conventions or puts logic in wrong place

### 6. Correctness
- Actually fixes the ROOT CAUSE (not a band-aid)
- Cross-check: does the fix address what the bug report identified?
- Edge cases handled
- No regressions — existing behavior preserved
- If fix-type in plan is 'band_aid', flag it but don't auto-fail
PASS if: root cause is genuinely fixed, no regressions
FAIL if: bug still exists, or fix introduces new bugs

### 7. Verification
- Bug can be proven fixed (test, manual check, or runtime evidence)
- If test exists: test passes and covers the bug scenario
- If no test: clear manual verification steps documented
- Regression scenario covered (won't come back)
PASS if: there is evidence the bug is fixed
FAIL if: no way to prove fix works

OUTPUT FORMAT (strict):

## Review Summary

| # | Dimension | Score | Evidence |
|---|-----------|-------|----------|
| 1 | Performance | PASS/FAIL | [one-line evidence] |
| 2 | Code Quality | PASS/FAIL | [one-line evidence] |
| 3 | Security | PASS/FAIL | [one-line evidence] |
| 4 | AI-Readable | PASS/FAIL | [one-line evidence] |
| 5 | Well-Organized | PASS/FAIL | [one-line evidence] |
| 6 | Correctness | PASS/FAIL | [one-line evidence] |
| 7 | Verification | PASS/FAIL | [one-line evidence] |

Overall: PASS (all 7 pass) / FAIL (any fail)

## Verdict

**Result:** LGTM | ISSUES_FOUND
**Blocking issues:** {count of must_fix}
**Non-blocking issues:** {count of should_fix}

If ISSUES_FOUND, issues are listed below with must_fix/should_fix severity.
If LGTM, no issues section needed.

## Issues Found (if any FAIL)

For each FAIL:

### {Dimension}: FAIL
- **File:** path:line
- **Problem:** what is wrong (specific, with code reference)
- **Fix direction:** how to fix it (specific, actionable)
- **Severity:** must_fix / should_fix

IMPORTANT:
- Be strict but fair. Don't nitpick style if codebase has no style guide.
- Evidence must reference actual code, not assumptions.
- 'must_fix' = blocks ship. 'should_fix' = improve but doesn't block.
- Only FAIL dimensions that have real, evidence-backed issues.
- At least 1 must_fix issue required for overall FAIL.",
  subagent_type="reviewer",
  model="opus",
  mode="bypassPermissions",
  description="Review fix (iteration {iteration}/{max_iterations})"
)
```

Wait for completion. Parse review result.

### 3.B — Check Review Result

**If overall PASS (all 7 dimensions pass):**
```
Review PASSED (iteration {iteration}/{max_iterations})
Semua 7 dimensi lolos.
```
Break loop → go to STEP 4.

**If overall FAIL:**

Display review summary to user:
```
Review iteration {iteration}/{max_iterations}: FAIL

| # | Dimension | Score |
|---|-----------|-------|
| 1 | Performance | PASS |
| 2 | Code Quality | FAIL |
| ... | ... | ... |

Issues:
- [Code Quality] path:line — {problem}

Fixing...
```

**Parse verdict:**
- If "LGTM" (or all 7 PASS) → break loop
- If "ISSUES_FOUND" → count must_fix vs should_fix
  - If only should_fix remaining and iteration >= 3 → ask user: "Remaining issues are should_fix only. Ship atau fix?"
  - If must_fix → continue loop

### 3.C — Spawn Fixer with Review Feedback (sonnet)

```
Agent(
  prompt="You are a fixer agent. The code review found issues that need to be fixed.

Working directory: $WORKTREE_ABS

REVIEW FEEDBACK:
{paste the FAIL dimensions with their issues and fix directions}

RULES:
1. Read the files mentioned in the review
2. Fix ONLY the issues listed — don't refactor unrelated code
3. Each fix must address the specific problem cited with evidence
4. Follow the fix direction provided by the reviewer
5. Maintain existing codebase patterns
6. Stage files individually
7. If fixing multiple dimensions, make ONE commit covering all fixes: fix({scope}): address review — {list dimensions}
8. If a step requires no code changes (e.g. only verification), skip commit

IMPORTANT: Only fix must_fix issues. should_fix issues are optional.",
  subagent_type="coder",
  model="sonnet",
  mode="bypassPermissions",
  description="Fix review issues (iteration {iteration})"
)
```

Wait for completion. Loop back to 3.A (re-review).

```
end while
```

**If max iterations (5) reached and still failing:**
```
Review loop exhausted ({max_iterations} iterations).
Remaining issues:
{list FAIL dimensions from last review}

Fix commits since {BASE_HASH}:
{git log --oneline {BASE_HASH}..HEAD}

Manual intervention needed.
Opsi: revert semua fix commits dengan `git revert {BASE_HASH}..HEAD` atau fix manual.
```

---

## STEP 4 — Save Fix Report

```bash
mkdir -p "$WORKTREE_PATH/.fd/fixes"
```

Extract slug from plan filename. Write to `$WORKTREE_PATH/.fd/fixes/{NN}-{slug}.md`:

```markdown
---
bug: {NN}-{slug}
plan: {NN}-{slug}
date: YYYY-MM-DD
fix-type: {from plan}
status: passed|failed
review-iterations: {N}
files-changed: [list]
---

## Fix Summary

Bug: .fd/bugs/{NN}-{slug}.md
Plan: .fd/plans/{NN}-{slug}.md
Root cause: {from bug report}
Fix approach: {from plan}

## Changes Made

| File | What changed |
|------|-------------|
| path/to/file.ts | {description} |

## Review History

### Iteration 1
| Dimension | Score | Evidence |
|-----------|-------|----------|
| Performance | PASS | ... |
| ... | ... | ... |

Issues fixed: [list]

### Iteration 2 (if needed)
...

## Final Review
[Last review that passed — full table]

## Commits
- {hash} fix({scope}): {message}
- {hash} fix({scope}): address review — {dimension}
```

---

## STEP 5 — Done

```
Fix selesai di worktree: $WORKTREE_PATH (branch: $WORKTREE_BRANCH)
Jalankan /fd:merge untuk merge ke main.

Status: {passed|failed}
Iterations: {N}/{max_iterations}
Files changed: {list}
Commits: {N}

Pipeline complete:
  /fd:analyze → .fd/bugs/{NN}-{slug}.md ✓
  /fd:planner {NN} → .fd/plans/{NN}-{slug}.md ✓
  /fd:fix {NN} → .fd/fixes/{NN}-{slug}.md ✓
```

</process>

<rules>
## Hard Rules

1. **Lead does NOT write code.** Only orchestrate.
2. **Fixer agents = sonnet.** Always `model="sonnet"`.
3. **Reviewer agent = opus.** Always `model="opus"`.
4. **Max 5 review iterations.** Don't infinite loop.
5. **Review must reference actual code.** No vague "looks good".
6. **Correctness dimension cross-checks bug report.** Fix must address root cause.
7. **Atomic commits per step.** Stage files individually, never `git add .`.
8. **Fixer only fixes review issues.** Don't refactor unrelated code in fix iterations.

## Anti-Patterns

| Thought | Reality |
|---------|---------|
| "Review passed first try" | Suspicious — opus should be thorough |
| "5 iterations and still failing" | Something fundamental is wrong — stop, ask user |
| "Skip review, fix is simple" | Review is mandatory. No exceptions. |
| "Fix all should_fix too" | Only must_fix blocks. Don't over-iterate. |
| "Rewrite the whole function" | Surgical fixes only. Minimum change. |
</rules>
