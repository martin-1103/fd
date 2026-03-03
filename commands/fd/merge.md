---
name: fd:merge
description: Merge assistance for FD worktrees. Scans worktrees, detects conflicts, assists cherry-pick, pushes to remote, and cleans up.
argument-hint: "[branch-slug] (optional, e.g. fix-auth-bug or feature-chat-widget)"
allowed-tools:
  - Read
  - Bash
  - Glob
  - Grep
  - AskUserQuestion
---

<objective>
Merge assistance for worktrees created by `/fd:run`, `/fd:fix`, and error-analyzer autofix.

**You assist, user decides.** Every action — push, merge, cherry-pick, delete — is offered, not assumed. User confirms before execution.

**Git-host agnostic.** Works with GitLab, GitHub, Gitea, etc. Uses `git push` + remote MR URL, no host-specific CLI dependency.

**Supported worktree sources:**

| Source | Branch prefix | Worktree path |
|--------|--------------|---------------|
| `/fd:run` | `fd/feature-*` | `.claude/worktrees/fd-feature-*` |
| `/fd:fix` | `fd/fix-*` | `.claude/worktrees/fd-fix-*` |
| error-analyzer | `autofix/*` | `/var/pile/worktrees/autofix-*` |

**Input:** Optional branch slug. If omitted, shows all managed worktrees.
**Output:** Guided merge workflow — user in control at every step.
</objective>

<process>

**BAHASA & GAYA:**
- Output ke user pakai Bahasa Indonesia. Santai.
- Git commands dan technical output tetap English.

---

## STEP 1 — Scan Worktrees

```bash
git worktree list
```

Filter for managed worktrees — branches matching any of:
- `fd/feature-*` (from `/fd:run`)
- `fd/fix-*` (from `/fd:fix`)
- `autofix/*` (from error-analyzer)

Derive type from branch prefix:
- `fd/feature-*` → `feature`
- `fd/fix-*` → `fix`
- `autofix/*` → `autofix`

If none found:
```
Tidak ada managed worktree yang aktif.
Worktree dibuat otomatis oleh /fd:run, /fd:fix, dan error-analyzer.
```
Stop.

---

## STEP 2 — Show Dashboard

Show summary of ALL FD worktrees regardless of argument:

```bash
CURRENT=$(git branch --show-current)
# Per worktree:
git log --oneline $CURRENT..$BRANCH | wc -l
git diff --stat $CURRENT..$BRANCH | tail -1
```

Display:
```
Current branch: $CURRENT

FD Worktrees:

| # | Type | Branch | Commits | Files Changed |
|---|------|--------|---------|---------------|
| 1 | feature | fd/feature-auth | 5 | 8 |
| 2 | feature | fd/feature-chat | 8 | 12 |
| 3 | fix | fd/fix-login-bug | 2 | 3 |
| 4 | autofix | autofix/pat-42-null-ref | 1 | 2 |
```

### Cross-Worktree Conflict Detection

Check if multiple worktrees touch the same files:

```bash
# Get changed files per worktree branch
FILES_A=$(git diff --name-only $CURRENT..fd/feature-auth)
FILES_B=$(git diff --name-only $CURRENT..fd/feature-chat)
# Intersection = potential conflict
comm -12 <(echo "$FILES_A" | sort) <(echo "$FILES_B" | sort)
```

If overlapping files found:
```
⚠️ Potential conflict: fd/feature-auth dan fd/feature-chat sama-sama modify:
  - src/services/auth.service.ts
  - src/middleware/session.ts

Merge order matters — mau saya bantu tentuin urutan?
```

If `$ARGUMENTS` provided, auto-select matching worktree. Otherwise ask:
```
Mau kerjain yang mana dulu?
```

---

## STEP 3 — Branch Detail

For selected worktree:

```bash
git log --oneline $CURRENT..$BRANCH
git diff --stat $CURRENT..$BRANCH
```

Display:
```
Branch: $BRANCH
Worktree: $WORKTREE_PATH
Base: $CURRENT
Commits: {N}

{git log --oneline output}

{diff stat output}
```

Then ask:
```
Mau ngapain dengan branch ini?

1. Push ke remote (buat MR)
2. Merge langsung ke $CURRENT
3. Cherry-pick — pilih commits tertentu aja
4. Lihat diff lengkap dulu
5. Skip — kerjain worktree lain
```

---

## STEP 4 — Execute User's Choice

### 4A. Push ke Remote (MR workflow)

```
Mau saya push branch $BRANCH ke remote?
```

If yes:
```bash
git push -u origin $BRANCH
```

Git remote biasanya print URL untuk create MR. Display:
```
Branch pushed. Buka link di atas untuk buat Merge Request.

Kalau MR sudah di-merge nanti, jalankan /fd:merge lagi untuk cleanup.
Atau mau saya cleanup worktree sekarang? (branch tetap di remote)
```

### 4B. Merge Langsung

```
Merge method:
1. Squash — 1 commit bersih di $CURRENT
2. Regular — preserve semua commits, merge commit ditambah
```

User picks, then:

**Squash:**
```bash
git merge --squash $BRANCH
```

**Regular:**
```bash
git merge --no-ff $BRANCH
```

**If conflict:**
```
Conflict di {N} file(s):
{list conflicted files}

Per file, mau saya bantu resolve?
1. Ya — saya tunjukin kedua versi, bantu merge
2. Abort — `git merge --abort`, kita coba cara lain
```

If user wants help resolving:
- Read both versions of conflicted file
- Show ours vs theirs for each conflict section
- Suggest resolution, ask user to confirm
- After all resolved: `git add` resolved files

**If clean merge:**

Suggest commit message, ask user to confirm or edit.

### 4C. Cherry-Pick

Show commit list:
```bash
git log --oneline $CURRENT..$BRANCH
```

```
Commits di $BRANCH:

| # | Hash | Message |
|---|------|---------|
| 1 | a1b2c3d | feat: add auth middleware |
| 2 | e4f5g6h | feat: add login endpoint |
| 3 | i7j8k9l | test: auth integration tests |
| 4 | m0n1o2p | fix: token refresh logic |
| 5 | q3r4s5t | chore: update deps |

Mau ambil yang mana? (nomor, range, atau "all except")
Contoh: "1,2,4" atau "1-3" atau "all except 5"
```

Parse user selection, then:
```
Saya akan cherry-pick commits berikut ke $CURRENT:
{list selected commits}

Lanjut?
```

If yes:
```bash
git cherry-pick $HASH1 $HASH2 $HASH3
```

If conflict during cherry-pick:
```
Conflict di cherry-pick commit {hash}: {message}

Mau saya bantu resolve, atau skip commit ini?
1. Bantu resolve
2. Skip — `git cherry-pick --skip`
3. Abort semua — `git cherry-pick --abort`
```

### 4D. Lihat Diff

```bash
git diff $CURRENT..$BRANCH
```

Show diff, then loop back to STEP 3 options.

### 4E. Skip

Loop back to STEP 2 to pick another worktree.

---

## STEP 5 — Cleanup

After merge/cherry-pick/push, offer cleanup:

```
Mau saya cleanup worktree ini?

Worktree: $WORKTREE_PATH
Branch: $BRANCH

1. Hapus worktree + branch lokal
2. Hapus worktree aja (keep branch)
3. Nanti — skip cleanup
```

If option 1:
```bash
git worktree remove "$WORKTREE_PATH"
git branch -d "$BRANCH"
```

If `branch -d` fails (not fully merged, e.g. after squash):
```
Branch belum "fully merged" (normal kalau pakai squash).
Data sudah ada di squash commit. Force delete branch?
```
If yes → `git branch -D "$BRANCH"`.

If option 2:
```bash
git worktree remove "$WORKTREE_PATH"
```

---

## STEP 6 — Next

After cleanup (or skip), check if more FD worktrees exist:

```bash
git worktree list | grep -E "fd[-/]|autofix"
```

If more worktrees:
```
Masih ada {N} FD worktree lain. Mau lanjut ke yang berikutnya?
```

If yes → loop back to STEP 2.
If no → done.

---

## STEP 7 — Done

```
Selesai.

Summary:
{For each worktree handled:}
- $BRANCH: {pushed | merged (squash) | merged (regular) | cherry-picked N commits | skipped}
  {cleanup: removed | kept}
```

</process>

<rules>
## Hard Rules

1. **Offer, don't instruct.** "Mau saya push?" bukan "Jalankan git push."
2. **Confirm every destructive action.** Push, merge, delete — always ask first.
3. **Never auto-resolve conflicts.** Show both sides, suggest, user confirms.
4. **Never force-push.** Regular push only.
5. **Never force-delete without asking.** `git branch -d` first, `-D` only after explicit confirmation with explanation.
6. **Abort cleanly on cancel.** No dirty git state left behind.
7. **Git-host agnostic.** No `gh` or `glab` CLI dependency. Use `git push` + remote URL.

## Anti-Patterns

| Thought | Reality |
|---------|---------|
| "Just merge it quick" | Show dashboard first. User decides order and method. |
| "I know the best merge strategy" | Present options. User picks. |
| "Auto-resolve this conflict" | Show both sides. User decides. |
| "Cleanup is obvious" | Ask before deleting anything. |
| "Push langsung aja" | Ask first. User mungkin belum mau push. |
| "Cherry-pick semua" | Show list. User pilih mana yang mau diambil. |
</rules>
