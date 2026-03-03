---
name: fd:discuss-phase
description: Gather phase context through adaptive questioning before planning (Fucking Done)
argument-hint: "<feature> <phase>"
allowed-tools:
  - Read
  - Write
  - Bash
  - Glob
  - Grep
  - AskUserQuestion
---

<objective>
Extract implementation decisions that the `/fd:run` lead agent and its teammates need — they will use CONTEXT.md to know what to investigate and what choices are locked.

**How it works:**
1. Analyze the phase to identify gray areas (UI, UX, behavior, etc.)
2. Present gray areas — user selects which to discuss
3. Deep-dive each selected area until satisfied
4. Create CONTEXT.md with decisions that guide research and planning

**Output:** `{phase}-CONTEXT.md` — decisions clear enough that downstream agents can act without asking the user again
</objective>

<execution_context>
@/root/.claude/fucking-done/workflows/discuss-phase.md
@/root/.claude/fucking-done/templates/context.md
</execution_context>

<context>
Arguments: $ARGUMENTS (required: `<feature> <phase>`)

**Parse arguments:**
- First token = feature name (FEATURE)
- Second token = phase number (PHASE)
- Set PLANNING_DIR=`.fd/planning/$FEATURE`
- Resolve PHASE_DIR: try existing dir via `ls -d`, fallback to deriving slug from ROADMAP.md
- Validate: feature directory `.fd/planning/$FEATURE` must exist (error if not)
- Validate: phase number must be present (error if missing)
</context>

<process>
**Follow the workflow steps in discuss-phase.md. The steps are:**

**PHASE A — Load context (text output only, NO AskUserQuestion):**

1. **validate_phase** — Parse args, load STATE.md + ROADMAP.md via Read tool, validate phase exists
2. **check_existing** — If CONTEXT.md exists: show summary, say "gw bakal review dan update", then continue. **NEVER offer to skip.** If not exists: continue.
3. **analyze_phase** — Identify domain, generate 3-4 phase-specific gray areas
4. **present_gray_areas** — Output phase boundary + numbered gray areas as plain text. Ask freeform: "Mau bahas yang mana? Reply nomornya."

**End your response here. Wait for user to reply.**

**PHASE B — Discussion (AskUserQuestion safe to use after user replies):**

5. **discuss_areas** — Parse user's number selection. For each selected area: ask 4 questions with AskUserQuestion (give opinion + concrete options each time), then check "lanjut atau next?". After all areas: "mau gw bikin context-nya?"
6. **write_context** — Write `$PHASE_DIR/$PADDED_PHASE-CONTEXT.md`
7. **confirm_creation** — Show summary + next steps

**WHY THIS SPLIT: AskUserQuestion silently fails when called in the same response as Read tool calls after command invocation (github.com/anthropics/claude-code/issues/9846). Phase A uses only text + Read tools. Phase B uses AskUserQuestion after user has replied.**
</process>

<success_criteria>
- Gray areas identified through intelligent analysis
- User chose which areas to discuss (freeform reply in Phase A)
- Each selected area explored with 4+ questions via AskUserQuestion (Phase B)
- Claude gave opinion on every question (not neutral)
- Scope creep redirected to deferred ideas
- CONTEXT.md captures decisions, not vague vision
- User knows next steps
</success_criteria>
