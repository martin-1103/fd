# FD (Fucking Done) — Command Reference

## Overview

FD is a collection of Claude Code slash commands for two workflows:

1. **Build** — Plan and build new features from scratch
2. **Fix** — Analyze, plan, and fix bugs with evidence-driven process

---

## Build Workflow

For building new features. Uses `.fd/` for project-level and `.fd/planning/<feature>/` for feature-level.

```
/fd:init → /fd:feature → /fd:discuss-phase → /fd:run → /fd:merge
```

| Command | Purpose | Input | Output |
|---------|---------|-------|--------|
| `/fd:init` | Initialize project with deep context gathering | (none) | `.fd/PROJECT.md`, `.fd/config.json` |
| `/fd:map-codebase` | Analyze existing codebase with parallel agents | (none) | `.fd/codebase/` (7 docs) |
| `/fd:feature <name>` | Plan a feature (research, requirements, roadmap) | Feature name (e.g. `auth-system`) | `.fd/planning/<name>/` |
| `/fd:discuss-phase <feature> <phase>` | Gather phase context through adaptive Q&A | Feature + phase number | Phase context for planning |
| `/fd:run <name>` | Plan, execute, and verify all phases | Feature name | Built feature with verification |
| `/fd:merge [slug]` | Merge FD worktree back to main | Branch slug (optional) | Merged code, cleaned worktree |

### Example

```
/fd:init
/fd:feature chat-widget
/fd:discuss-phase chat-widget 1
/fd:run chat-widget
```

---

## Fix Workflow

For debugging and fixing bugs. Uses `.fd/` directory.

```
/fd:analyze → /fd:planner → /fd:fix → /fd:merge
```

| Command | Purpose | Input | Output |
|---------|---------|-------|--------|
| `/fd:analyze <input>` | Root cause investigation | Error log, screenshot, URL, file path, or description | `.fd/bugs/{NN}-{slug}.md` |
| `/fd:planner <NN>` | Create evidence-driven fix plan | Bug number from analyze | `.fd/plans/{NN}-{slug}.md` |
| `/fd:fix <NN>` | Execute fix with review loop | Plan number from planner | `.fd/fixes/{NN}-{slug}.md` |
| `/fd:merge [slug]` | Merge FD worktree back to main | Branch slug (optional) | Merged code, cleaned worktree |

### Example

```
/fd:analyze "TypeError: Cannot read property 'x' of undefined"
# → saves .fd/bugs/01-auth-null-token.md

/fd:planner 01
# → saves .fd/plans/01-auth-null-token.md

/fd:fix 01
# → executes fix, reviews, saves .fd/fixes/01-auth-null-token.md
```

### Fix Pipeline Details

**`/fd:analyze`** accepts any combination of:
- Stack trace / error log (paste directly)
- Screenshot path (`.png`, `.jpg`, `.webp`)
- URL (opens with Playwright to capture errors)
- File path to suspect code
- Natural language description

**`/fd:planner`** does:
- Verifies analysis claims against actual code (ast-grep)
- Detects band-aid vs root cause fixes (strict)
- Assesses risk with evidence
- Produces surgical fix plan

**`/fd:fix`** does:
- Executes plan steps with sonnet subagents
- Reviews with opus against 7 dimensions (Performance, Code Quality, Security, AI-Readable, Well-Organized, Correctness, Verification)
- Loops until all 7 pass (max 5 iterations)
- Saves fix report with full review history

### Directory Structure

```
.fd/
├── PROJECT.md          ← /fd:init (project-level)
├── config.json         ← /fd:init (workflow preferences)
├── codebase/           ← /fd:map-codebase or /fd:init brownfield
│   ├── STACK.md
│   ├── INTEGRATIONS.md
│   ├── ARCHITECTURE.md
│   ├── STRUCTURE.md
│   ├── CONVENTIONS.md
│   ├── TESTING.md
│   └── CONCERNS.md
├── planning/
│   └── <feature>/      ← /fd:feature (per-feature)
│       ├── REQUIREMENTS.md
│       ├── ROADMAP.md
│       ├── STATE.md
│       ├── research/
│       └── phases/
├── bugs/
│   ├── 01-auth-null-token.md
│   └── 02-sftp-race-condition.md
├── plans/
│   ├── 01-auth-null-token.md
│   └── 02-sftp-race-condition.md
└── fixes/
    ├── 01-auth-null-token.md
    └── 02-sftp-race-condition.md
```

---

## Tips

- Run `/clear` between commands if context gets heavy
- Each command reads from filesystem, so they work across sessions
- Bug numbers auto-increment — no need to track manually
- Fix workflow is strictly sequential: analyze → planner → fix
- Build workflow can re-run phases independently
- Both build and fix workflows create worktrees — use `/fd:merge` to merge back
