---
name: fd:planner
description: Create evidence-driven fix plan from a bug analysis report. Reads .fd/bugs/{NN}.md, verifies claims against actual code using ast-grep, detects band-aids, and produces a proper fix plan. Use after /fd:analyze produces a bug report.
argument-hint: "<bug-number> (e.g. 01, 02)"
allowed-tools:
  - Read
  - Write
  - Bash
  - Glob
  - Grep
  - Agent
  - AskUserQuestion
---

<objective>
You are a senior engineer reviewing an automated bug analysis and planning a PROPER fix.

**Your job:**
1. Verify the analysis against actual code (analysis may be wrong)
2. Understand codebase patterns around the bug
3. Detect band-aid vs root cause fixes (STRICT)
4. Assess risk with evidence
5. Produce a surgical fix plan

**You do NOT write code.** You produce a plan that a fixer agent or human can execute.

**Input:** `.fd/bugs/{NN}-*.md` (from `/fd:analyze`)
**Output:** `.fd/plans/{NN}-*.md` (fix plan with same number)
</objective>

<process>

**BAHASA & GAYA:**
- SEMUA output pakai Bahasa Indonesia. Santai, kayak ngobrol.
- Istilah teknis tetap English.
- Plan file content tetap English (biar executable by agents).

---

## STEP 1 — Load Bug Report

Parse `$ARGUMENTS` as bug number (NN).

```bash
ls .fd/bugs/${NN}-*.md 2>/dev/null | head -1
```

If not found:
```
ERROR: Bug report .fd/bugs/{NN}-*.md not found.
Jalankan /fd:analyze dulu untuk generate bug report.
```

Read the bug report. Extract:
- `root-cause` from frontmatter
- `severity` from frontmatter
- `scope` from frontmatter
- Execution trace (file:line references)
- Divergence point
- Verified root cause description
- Supporting evidence

Announce:
```
Loading bug report: .fd/bugs/{NN}-{slug}.md
Root cause claim: {root-cause from frontmatter}
Severity: {severity}
Scope: {scope}

Mulai verifikasi...
```

---

## STEP 2 — Verify Analysis Against Actual Code

**The analysis is a HYPOTHESIS, not truth.** Verify everything.

For each file:line referenced in the bug report:

1. **Read actual current code** at those locations
2. **Check accuracy:**
   - Do line numbers still match? (code may have changed since analysis)
   - Does the described behavior match what the code actually does?
   - Are function signatures correct?
   - Is the execution flow claim accurate?

3. **Use ast-grep for semantic verification:**

First, detect the primary language from the buggy file(s) referenced in the bug report:
```bash
# FILE = primary buggy file from bug report's divergence point
# Detect language from file extension:
# .ts/.tsx → typescript, .py → python, .go → go, .rs → rust, .js/.jsx → javascript
LANG=$(case "${FILE##*.}" in ts|tsx) echo typescript;; py) echo python;; go) echo go;; rs) echo rust;; js|jsx) echo javascript;; *) echo typescript;; esac)
```

```bash
# Find the function mentioned in root cause
ast-grep run --pattern 'function $FUNC_NAME($$PARAMS) { $$BODY }' --lang $LANG path/to/file

# Find all callers of the buggy function
ast-grep run --pattern '$FUNC_NAME($$ARGS)' --lang $LANG .

# Find similar patterns that work correctly
ast-grep run --pattern '$SIMILAR_PATTERN' --lang $LANG .
```

Adapt patterns to the language — e.g. Python uses `def`, Go uses `func`, Rust uses `fn`.
Use Grep as fallback when ast-grep patterns don't match the language's syntax.

4. **Trace caller chain** — verify the execution path from entry point to divergence:

```bash
# Who calls the function where bug originates?
ast-grep run --pattern '$CALLER($$ARGS)' --lang $LANG path/

# Trace one level up — who calls the caller?
ast-grep run --pattern '$PARENT_CALLER($$ARGS)' --lang $LANG path/
```

5. **Record verification result:**

For each claim in the analysis:
- `CONFIRMED` — actual code matches claim
- `OUTDATED` — line numbers shifted but logic is same
- `INCORRECT` — analysis got this wrong, actual behavior is [X]
- `MISSING` — analysis didn't mention [important thing]

**If analysis is significantly wrong (>2 INCORRECT findings):**
```
Analysis accuracy: LOW
Corrections needed before planning.
[list what's wrong]

Recommend: re-run /fd:analyze with corrected context.
```
Ask user whether to continue planning with corrections or re-analyze.

### Staleness Detection

Check time gap between analysis and planning:

```bash
# Read date from bug report frontmatter
ANALYSIS_DATE=$(grep '^date:' .fd/bugs/${NN}-*.md | head -1 | awk '{print $2}')
CURRENT_DATE=$(date +%Y-%m-%d)

# Calculate days since analysis
DAYS_OLD=$(( ($(date -d "$CURRENT_DATE" +%s) - $(date -d "$ANALYSIS_DATE" +%s)) / 86400 ))
```

- If > 0 days: warn "Analysis sudah {N} hari. Code mungkin sudah berubah."

Check git changes since analysis:

```bash
# Files referenced in bug report — extract file paths
REFERENCED_FILES=$(grep -oE '[a-zA-Z0-9_/.-]+\.(ts|tsx|js|jsx|py|go|rs):[0-9]+' .fd/bugs/${NN}-*.md | cut -d: -f1 | sort -u)

# Check if any referenced files changed since analysis date
CHANGED_FILES=$(git log --since="$ANALYSIS_DATE" --name-only --pretty=format: -- $REFERENCED_FILES 2>/dev/null | sort -u | grep -v '^$')
```

If any referenced files changed since analysis:
```
⚠️ STALENESS WARNING: File berikut berubah sejak analisis ({ANALYSIS_DATE}):
{list of changed files}

Recommend: re-run /fd:analyze atau lanjut dengan extra caution.
```

Flag as STALE in verification status if changes found.

---

## STEP 3 — Understand Codebase Patterns

Before planning any fix, understand HOW this codebase works:

1. **Error handling pattern** (adapt patterns to $LANG from Step 2):
```bash
# JS/TS:
ast-grep run --pattern 'catch ($ERR) { $$BODY }' --lang $LANG path/to/scope/
# Python:
ast-grep run --pattern 'except $ERR: $$BODY' --lang python path/to/scope/
# Go:
ast-grep run --pattern 'if $ERR != nil { $$BODY }' --lang go path/to/scope/
# Use the pattern that matches $LANG. Fallback to Grep if ast-grep doesn't match.
```

2. **Similar working implementations:**
```bash
# Find similar code that works correctly
ast-grep run --pattern '$SIMILAR_PATTERN' --lang $LANG .
```
Use Grep as fallback for text patterns ast-grep can't match.

3. **Dependency chain:**
   - Read imports of the buggy file
   - Identify shared state, singletons, global config
   - Note async boundaries (Promise, callback, event)

4. **Conventions:**
   - Naming patterns
   - File organization
   - State management approach
   - Testing patterns (if tests exist nearby)

Record findings — the fix MUST align with existing patterns.

---

## STEP 4 — Band-Aid Detection (STRICT)

**BEFORE planning any fix, classify it honestly.**

### Classification Rules

| Type | Definition |
|------|-----------|
| **root_cause** | Fix changes the LOGIC, SEQUENCE, or DATA FLOW that creates the bug |
| **mitigation** | Temporarily reduces impact (feature flag, disable path) while root cause fix is pending |
| **band_aid** | Adds fallback/default/retry/null-check that HIDES the bug without fixing WHY it occurs |

### Critical Tests

**Order-of-operations bug:**
- If analysis says "X happens before Y" → root_cause fix MUST reorder operations
- Adding a fallback so X doesn't fail = band_aid, PERIOD
- "Higher risk" or "larger refactor" is NOT valid reason to choose band_aid

**Data flow bug:**
- If data flows A → B → C and breaks at C → fix where data gets lost (A or B), NOT C
- Patching C to handle missing data = band_aid

**The Definitive Test:**
Ask: "After my fix, does the original faulty logic still exist but get hidden?"
- YES → band_aid
- NO → root_cause

**ALWAYS prefer root_cause.** Only use band_aid if root_cause is genuinely impossible (not just harder).

### Enforcement Rules

If fix is classified as `band_aid`:
1. MUST document why root_cause is genuinely impossible (not just harder)
2. MUST describe what the ideal root_cause fix would look like
3. MUST assess long-term risk of keeping the band_aid
4. MUST get explicit user confirmation before proceeding

If fix is classified as `root_cause` but plan includes ANY of these patterns:
- Adding null/undefined check → RE-CLASSIFY as band_aid
- Adding try-catch around existing code → RE-CLASSIFY as band_aid
- Adding default/fallback value → RE-CLASSIFY as band_aid
- Adding retry logic → RE-CLASSIFY as band_aid

These patterns are band_aid BY DEFINITION regardless of how they're labeled.

---

## STEP 5 — Risk Assessment

Assess using ONLY verified evidence (not speculation):

| Dimension | Level | Evidence |
|-----------|-------|----------|
| Correctness | low/medium/high/unknown | [what could break] |
| Security | low/medium/high/unknown | [auth/data exposure concerns] |
| Performance | low/medium/high/unknown | [hot path impact] |

Rules:
- If you can't assess → mark `unknown`, don't guess
- `unknown` is better than wrong assessment
- Note blast radius: how many code paths affected?

---

## STEP 6 — Plan Fix Steps

**Rules:**
- Fix where data BECOMES wrong, not where error APPEARS
- Fix producers before consumers
- Use EXACT names from codebase (copy from actual code, don't invent)
- Every step = minimum necessary change
- The fix must be: correct, secure, performant, readable, and follow existing conventions
- Plan is GUIDANCE for executor, not literal code

For each step:

```markdown
### Step N: [short title]
- **Area:** path/to/file.ts:line, functionName
- **Problem:** [what is wrong — reference actual code]
- **Direction:** [approach to fix — be specific but don't write code]
- **Constraints:** [perf impact, security concern, patterns to follow]
- **Gate:** [how to verify this step is correct]
```

**Step ordering:**
1. Fix root cause first (the divergence point)
2. Fix upstream producers if needed
3. Fix downstream consumers if affected
4. Add/update tests

---

## STEP 7 — Define Tests

For each step, define what must be tested:

```markdown
### Tests Needed
- [ ] [scenario]: [what to test and expected result]
- [ ] [scenario]: [regression — existing behavior still works]
```

If test files exist near buggy code, reference them.
If no test infrastructure, note what manual verification is needed.

---

## STEP 8 — Save Plan

Save to `.fd/plans/` with same number as bug report.

```bash
mkdir -p .fd/plans
```

**Check for existing plan:**
```bash
ls .fd/plans/${NN}-*.md 2>/dev/null | head -1
```
If exists, ask user:
```
Plan .fd/plans/{NN}-*.md sudah ada dari run sebelumnya.
Overwrite atau cancel?
```
If cancel → stop.

Extract slug from bug report filename:
```bash
SLUG=$(ls .fd/bugs/${NN}-*.md 2>/dev/null | head -1 | sed 's|.fd/bugs/||;s|\.md||')
```

Write plan to `.fd/plans/{SLUG}.md`:

```markdown
---
bug: {NN}-{slug}
date: YYYY-MM-DD
fix-type: root_cause|mitigation|band_aid
approach: patch|targeted_fix|refactor
risk: low|medium|high
complexity: trivial|simple|moderate|complex
---

## Verification

Analysis accuracy: [HIGH/MEDIUM/LOW]

| Claim | Status | Notes |
|-------|--------|-------|
| [claim from analysis] | CONFIRMED/OUTDATED/INCORRECT/MISSING | [detail] |

Corrections: [what analysis got wrong, if any]
Missing context: [what analysis didn't cover]

## Codebase Patterns

[Key patterns the fix must follow]
[Similar working implementations found]
[Dependency chain relevant to fix]

## Risk Profile

| Dimension | Level | Evidence |
|-----------|-------|----------|
| Correctness | | |
| Security | | |
| Performance | | |

Blast radius: [N files, M code paths affected]

## Fix Plan

### Step 1: [title]
- **Area:** path:line, functionName
- **Problem:** [what's wrong]
- **Direction:** [how to fix]
- **Constraints:** [limits]
- **Gate:** [verification]

### Step 2: ...

## Tests Needed

- [ ] [test scenario]
- [ ] [regression test]

## Band-Aid Disclosure (if fix_type = band_aid)

Why root cause fix is not possible: [explanation]
Root cause alternative would be: [what ideal fix looks like]
Risk of keeping band_aid: [what could go wrong long-term]
```

Announce:
```
Plan saved: .fd/plans/{SLUG}.md
```

---

## STEP 9 — Done

```
Plan selesai: .fd/plans/{SLUG}.md

Fix type: {root_cause|mitigation|band_aid}
Approach: {patch|targeted_fix|refactor}
Risk: {low|medium|high}
Steps: {N} steps

Next: /fd:fix {NN}
Tip: /clear dulu kalau context udah berat
```

</process>

<rules>
## Hard Rules

1. **Verify before planning.** Analysis is hypothesis, not truth.
2. **Every claim needs file:line reference to CURRENT code.** Not what analysis said — what code says NOW.
3. **ast-grep for semantic verification.** Don't just text-match — understand code structure.
4. **Band-aid detection is STRICT.** Don't relabel band-aids as root cause fixes.
5. **Use exact names from codebase.** Copy identifiers from actual code, don't invent.
6. **Fix at origin, not symptom.** Fix producers before consumers.
7. **Align with existing patterns.** The fix must look like it belongs in this codebase.
8. **Mark unknowns.** `unknown` > wrong assessment.

## Anti-Patterns (STOP if you catch yourself)

| Thought | Reality |
|---------|---------|
| "Just add a null check" | That's a band-aid. Why is it null? |
| "Add a try-catch around it" | That hides the bug. Fix the cause. |
| "Add a default value" | The real question is why value is missing |
| "The analysis said X so X" | Verify against actual code first |
| "This is too risky to fix properly" | Risk is not an excuse for band-aids |
| "Rewrite the whole module" | Minimum necessary change. Surgical. |
| "Add a feature flag" | That's mitigation, label it honestly |
| "Classified as root_cause but adds null check" | That's a band_aid. Re-classify. |
</rules>
