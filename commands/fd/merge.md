---
name: fd:merge
description: Interactive merge assistant for FD worktrees. Lists worktrees, shows diffs, handles conflicts, and cleans up.
argument-hint: "[branch-slug] (optional, e.g. fix-auth-bug or feature-chat-widget)"
allowed-tools:
  - Read
  - Bash
  - Glob
  - Grep
  - AskUserQuestion
---

<objective>
Interactive merge assistant for FD worktrees created by `/fd:run` and `/fd:fix`.

Lists available worktrees, shows diff summaries, handles merge (squash or regular), resolves conflicts interactively, and cleans up worktree + branch after merge.

**Input:** Optional branch slug (e.g. `/fd:merge fix-auth-bug`). If omitted, lists all FD worktrees for selection.
**Output:** Merged code on current branch, cleaned up worktree.
</objective>

<process>

**BAHASA & GAYA:**
- Output ke user pakai Bahasa Indonesia. Santai.
- Git commands dan technical output tetap English.

---

## STEP 1 — List FD Worktrees

```bash
git worktree list | grep -E "fd[-/]"
```

If no FD worktrees found:
```
Tidak ada FD worktree yang aktif.
Worktree dibuat otomatis oleh /fd:run dan /fd:fix.
```
Stop.

Parse each worktree into:
- Path (e.g. `.claude/worktrees/fd-feature-chat-widget`)
- Branch (e.g. `fd/feature-chat-widget`)
- Type: `feature` or `fix` (derived from branch prefix)

---

## STEP 2 — Select Worktree

**If `$ARGUMENTS` provided:**
- Match against branch slugs (fuzzy match OK)
- If no match: show available worktrees, ask user to pick

**If no arguments:**
- Show summary per worktree:

```
FD Worktrees:

| # | Type | Branch | Commits | Files Changed |
|---|------|--------|---------|---------------|
| 1 | feature | fd/feature-chat-widget | 5 | 12 |
| 2 | fix | fd/fix-auth-bug | 2 | 3 |

Pilih nomor worktree untuk merge (atau 'cancel'):
```

For each worktree, gather stats:
```bash
BRANCH="fd/feature-{slug}"
git log --oneline main..$BRANCH | wc -l  # commit count
git diff --stat main..$BRANCH | tail -1   # files changed summary
```

---

## STEP 3 — Show Diff Summary

```bash
BRANCH="fd/{type}-{slug}"
git diff main..$BRANCH --stat
git log --oneline main..$BRANCH
```

Display:
```
Branch: $BRANCH
Commits: {N}
Files changed: {summary}

Commit history:
{git log output}
```

---

## STEP 4 — Dry-Run Merge

```bash
git merge --no-commit --no-ff $BRANCH 2>&1
MERGE_STATUS=$?
git merge --abort 2>/dev/null
```

### No Conflict (exit code 0):

```
Merge clean — tidak ada conflict.
Merge method:
1. Squash (recommended) — single clean commit
2. Regular merge — preserve all commits

Pilih method:
```

### Conflict Detected:

```
Conflict detected di {N} file(s):
```

```bash
git merge --no-commit --no-ff $BRANCH 2>&1
git diff --name-only --diff-filter=U  # conflicted files
git merge --abort
```

Show conflicted files. For each file:
```
File: path/to/file.ts
Conflict sections: {N}

Opsi:
1. Keep versi main
2. Keep versi branch ($BRANCH)
3. Saya suggest resolution
```

If user picks "suggest resolution":
- Read both versions of conflicted sections
- Suggest merged version
- Ask user to confirm

After all conflicts resolved, proceed to STEP 5.

---

## STEP 5 — Execute Merge

**Squash merge:**
```bash
git merge --squash $BRANCH
git commit -m "feat: merge $BRANCH

Squash merge of FD worktree.
$(git log --oneline main..$BRANCH | sed 's/^/- /')"
```

**Regular merge:**
```bash
git merge --no-ff $BRANCH -m "merge: $BRANCH into $(git branch --show-current)"
```

---

## STEP 6 — Cleanup

```bash
WORKTREE_PATH=$(git worktree list | grep "$BRANCH" | awk '{print $1}')
git worktree remove "$WORKTREE_PATH"
git branch -d "$BRANCH"
```

If branch delete fails (unmerged changes warning):
```
Branch $BRANCH belum fully merged. Force delete?
Warning: Ini akan hapus branch permanent.
```
Ask user before `git branch -D $BRANCH`.

---

## STEP 7 — Done

```
Merged dan cleanup selesai.

Branch: $BRANCH → $(git branch --show-current)
Method: {squash|regular}
Worktree: $WORKTREE_PATH (removed)

Commit: $(git log --oneline -1)
```

</process>

<rules>
## Hard Rules

1. **Never auto-merge without user confirmation.** Always show diff first.
2. **Never force-delete branches without asking.** Use `git branch -d` first.
3. **Abort merge on conflict if user doesn't want to resolve.** Don't leave dirty state.
4. **Squash is recommended default.** Keeps main branch clean.
5. **Clean up worktree AND branch.** Both must be removed.

## Anti-Patterns

| Thought | Reality |
|---------|---------|
| "Just merge it quick" | Show diff summary first. Always. |
| "Auto-resolve conflicts" | Ask user for each conflict. |
| "Skip cleanup" | Worktree + branch must be removed. |
| "Force push after merge" | Never force push. Regular push only. |
</rules>
