# FD (Fucking Done) — Installation Guide

Multi-agent project management framework untuk Claude Code. Dua workflow utama: **Build** (bikin fitur baru) dan **Fix** (debug & fix bug).

## Struktur File

```
~/.claude/
├── commands/fd/              ← Slash commands (user-facing)
│   ├── README.md
│   ├── analyze.md
│   ├── discuss-phase.md
│   ├── feature.md
│   ├── fix.md
│   ├── init.md
│   ├── map-codebase.md
│   ├── merge.md
│   ├── planner.md
│   └── run.md
├── agents/                   ← Background worker agents
│   ├── fd-codebase-mapper.md
│   ├── fd-executor.md
│   ├── fd-phase-researcher.md
│   ├── fd-plan-checker.md
│   ├── fd-planner.md
│   ├── fd-project-researcher.md
│   ├── fd-research-synthesizer.md
│   ├── fd-roadmapper.md
│   └── fd-verifier.md
├── skills/                   ← Claude Code skills
│   └── error-analyzer/
│       ├── SKILL.md
│       ├── scripts/ea.sh
│       └── resources/api-reference.md
└── fucking-done/             ← Core system (templates, references, workflows)
    ├── references/           ← Configuration & policy docs
    ├── templates/            ← File templates for project artifacts
    └── workflows/            ← Workflow definitions
```

## Cara Install

### Linux / macOS

#### 1. Copy semua file ke `~/.claude/`

```bash
# Core system
cp -r fucking-done/ ~/.claude/fucking-done/

# Commands
mkdir -p ~/.claude/commands/
cp -r commands/fd/ ~/.claude/commands/fd/

# Agents
mkdir -p ~/.claude/agents/
cp agents/fd-*.md ~/.claude/agents/

# Skills
mkdir -p ~/.claude/skills/
cp -r skills/error-analyzer/ ~/.claude/skills/error-analyzer/
chmod +x ~/.claude/skills/error-analyzer/scripts/ea.sh
```

**Upgrading from older version?** Remove stale files:

```bash
rm -f ~/.claude/commands/fd/new-project.md
```

#### 2. Verify installation

```bash
ls ~/.claude/commands/fd/
ls ~/.claude/agents/fd-*.md
ls ~/.claude/fucking-done/
ls ~/.claude/skills/error-analyzer/
```

#### 3. Restart Claude Code

Setelah copy, restart Claude Code supaya commands dan agents ke-detect.

---

### Windows

Claude Code support Windows native. Folder `.claude/` ada di `%USERPROFILE%\.claude\` (biasanya `C:\Users\USERNAME\.claude\`).

#### 1. Copy semua file (PowerShell)

```powershell
# Core system
Copy-Item -Recurse -Force fucking-done\ "$env:USERPROFILE\.claude\fucking-done\"

# Commands
New-Item -ItemType Directory -Force "$env:USERPROFILE\.claude\commands\fd" | Out-Null
Copy-Item -Recurse -Force commands\fd\* "$env:USERPROFILE\.claude\commands\fd\"

# Agents
New-Item -ItemType Directory -Force "$env:USERPROFILE\.claude\agents" | Out-Null
Copy-Item -Force agents\fd-*.md "$env:USERPROFILE\.claude\agents\"

# Skills
New-Item -ItemType Directory -Force "$env:USERPROFILE\.claude\skills\error-analyzer" | Out-Null
Copy-Item -Recurse -Force skills\error-analyzer\* "$env:USERPROFILE\.claude\skills\error-analyzer\"
```

**Upgrading from older version?** Remove stale files:

```powershell
Remove-Item -Force "$env:USERPROFILE\.claude\commands\fd\new-project.md" -ErrorAction SilentlyContinue
```

#### 2. Verify installation

```powershell
dir "$env:USERPROFILE\.claude\commands\fd\"
dir "$env:USERPROFILE\.claude\agents\fd-*.md"
dir "$env:USERPROFILE\.claude\fucking-done\"
dir "$env:USERPROFILE\.claude\skills\error-analyzer\"
```

#### 3. Restart Claude Code

Setelah copy, restart Claude Code supaya commands dan agents ke-detect.

---

## Path yang Perlu Diperhatikan

File-file berikut mengandung **hardcoded absolute path** ke `/root/.claude/fucking-done/`:

| File | Tipe |
|------|------|
| `agents/fd-executor.md` | Agent |
| `agents/fd-planner.md` | Agent |
| `agents/fd-research-synthesizer.md` | Agent |
| `agents/fd-roadmapper.md` | Agent |
| `commands/fd/discuss-phase.md` | Command |
| `commands/fd/init.md` | Command |
| `commands/fd/run.md` | Command |
| `fucking-done/templates/phase-prompt.md` | Template |
| `fucking-done/templates/codebase/structure.md` | Template |
| `fucking-done/references/verification-patterns.md` | Reference |

**Kalau home directory kamu bukan `/root/`**, kamu perlu find-and-replace path ini.

**Linux / macOS:**

```bash
# Contoh: ganti /root/ ke /home/username/
find ~/.claude/commands/fd/ ~/.claude/agents/ ~/.claude/fucking-done/ \
  -name "*.md" -exec sed -i 's|/root/.claude/fucking-done|/home/USERNAME/.claude/fucking-done|g' {} +
```

**Windows (PowerShell):**

```powershell
# Ganti USERNAME dengan username kamu
$claudeDir = "$env:USERPROFILE\.claude"
$old = "/root/.claude/fucking-done"
$new = "/Users/USERNAME/.claude/fucking-done"

Get-ChildItem -Recurse -Include "*.md" "$claudeDir\commands\fd", "$claudeDir\agents", "$claudeDir\fucking-done" |
  ForEach-Object { (Get-Content $_.FullName -Raw) -replace [regex]::Escape($old), $new | Set-Content $_.FullName -NoNewline }
```

Ganti `USERNAME` dengan username kamu.

## Cara Pakai

### Build Workflow — Bikin fitur baru

```
/fd:init → /fd:feature → /fd:discuss-phase → /fd:run → /fd:merge
```

| Command | Fungsi | Input | Output |
|---------|--------|-------|--------|
| `/fd:init` | Init project, deep context gathering | (none) | `.fd/PROJECT.md`, `.fd/config.json` |
| `/fd:map-codebase` | Analyze codebase with parallel agents | (none) | `.fd/codebase/` (7 docs) |
| `/fd:feature <name>` | Plan a feature (research, requirements, roadmap) | Nama fitur | `.fd/planning/<name>/` |
| `/fd:discuss-phase <feature> <phase>` | Q&A untuk gather context phase | Feature + phase number | `{phase}-CONTEXT.md` di planning dir |
| `/fd:run <name>` | Plan, execute, verify semua phase | Nama fitur | Built feature + verification |
| `/fd:merge [slug]` | Merge worktree back ke main branch | Branch slug (optional) | Merged code, cleaned worktree |

**Contoh:**

```
/fd:init
/fd:feature chat-widget
/fd:discuss-phase chat-widget 1
/fd:run chat-widget
/fd:merge
```

### Fix Workflow — Debug & fix bug

```
/fd:analyze → /fd:planner → /fd:fix → /fd:merge
```

| Command | Fungsi | Input | Output |
|---------|--------|-------|--------|
| `/fd:analyze <input>` | Root cause investigation | Error log, screenshot, URL, file path, atau deskripsi | `.fd/bugs/{NN}-{slug}.md` |
| `/fd:planner <NN>` | Buat fix plan dari evidence | Bug number | `.fd/plans/{NN}-{slug}.md` |
| `/fd:fix <NN>` | Execute fix + review loop | Plan number | `.fd/fixes/{NN}-{slug}.md` |
| `/fd:merge [slug]` | Merge worktree back ke main branch | Branch slug (optional) | Merged code, cleaned worktree |

**Contoh:**

```
/fd:analyze "TypeError: Cannot read property 'x' of undefined"
/fd:planner 01
/fd:fix 01
/fd:merge
```

## Workflow Diagram

### Build Workflow

```
  /fd:init           /fd:feature          /fd:discuss-phase       /fd:run                    /fd:merge
  ┌─────────────┐   ┌──────────────┐   ┌──────────────────┐   ┌─────────────────────┐   ┌──────────────┐
  │ Setup       │   │ Research     │   │ Adaptive Q&A     │   │ For each phase:     │   │ Merge back   │
  │ PROJECT.md  │──▶│ Requirements │──▶│ per phase        │──▶│  1. Research        │──▶│ to main      │
  │ config.json │   │ Roadmap      │   │ (gather context) │   │  2. Plan            │   │ Push remote  │
  │ codebase/   │   └──────────────┘   └──────────────────┘   │  3. Check plan      │   │ Clean up     │
  └─────────────┘                                              │  4. Execute         │   └──────────────┘
                                                               │  5. Verify          │
                                                               └─────────────────────┘
```

### Fix Workflow

```
  /fd:analyze              /fd:planner                /fd:fix                    /fd:merge
  ┌─────────────┐        ┌──────────────────┐      ┌─────────────────────┐   ┌──────────────┐
  │ Investigate  │        │ Verify claims    │      │ Execute plan steps  │   │ Merge back   │
  │ root cause  │──────▶ │ via ast-grep     │────▶│ with sonnet agents  │──▶│ to main      │
  │ multi-input │        │ Detect band-aids │      │ Review with opus    │   │ Push remote  │
  │ (log, URL,  │        │ Produce fix plan │      │ Loop until 7/7 pass │   │ Clean up     │
  │  screenshot)│        └──────────────────┘      │ Save fix report     │   └──────────────┘
  └─────────────┘                                   └─────────────────────┘
```

## Dependencies: MCP Servers & Tools

FD butuh beberapa MCP servers dan built-in tools. **Tanpa ini, beberapa fitur tidak jalan.**

### MCP Servers (harus di-setup di Claude Code)

| MCP Server | Dipakai oleh | Fungsi |
|------------|-------------|--------|
| **Context7** (`mcp__context7__*`) | `fd-planner`, `fd-phase-researcher`, `fd-project-researcher`, `/fd:analyze` | Query dokumentasi library/framework yang up-to-date |
| **Playwright** (`mcp__plugin_playwright_*`) | `/fd:analyze` | Navigate URL, ambil screenshot, console errors, network requests (untuk debug web apps) |
| **Tavily** (`mcp__tavily__*`) | `/fd:analyze` | Web search & content extraction untuk research error/bug |
| **Exa** (`mcp__exa__*`) | `/fd:analyze` | Code-focused search, cari docs & code examples |

### Built-in Claude Code Tools

| Tool | Dipakai oleh | Fungsi |
|------|-------------|--------|
| `WebSearch` | `fd-phase-researcher`, `fd-project-researcher`, `/fd:analyze` | General web search |
| `WebFetch` | `fd-planner`, `fd-phase-researcher`, `fd-project-researcher`, `/fd:analyze` | Fetch & parse web page content |

### Mana yang wajib?

| Skenario | MCP yang dibutuhkan |
|----------|-------------------|
| Build workflow (`/fd:init`, `/fd:feature`, `/fd:run`) | **Context7** (strongly recommended) |
| Fix workflow — code-only bugs | Tidak ada (semua pakai built-in tools) |
| Fix workflow — web app bugs (URL input) | **Playwright** |
| Fix workflow — deep research | **Tavily** dan/atau **Exa** (optional, WebSearch sebagai fallback) |

### CLI Tools (harus terinstall di system)

#### 1. ast-grep (WAJIB untuk Fix workflow)

Semantic code search — cari struct, function, callers berdasarkan AST. Lebih akurat dari text grep.

Dipakai oleh: `fd-verifier`, `fd-planner`, `fd-phase-researcher`, `/fd:analyze`, `/fd:planner`

```bash
# Via npm (paling gampang)
npm i -g @ast-grep/cli

# Via cargo (Rust)
cargo install ast-grep --locked

# Via Homebrew (macOS)
brew install ast-grep

# Via pip
pip install ast-grep-cli
```

Repo: https://github.com/ast-grep/ast-grep

#### 2. aid — AI Distiller (OPTIONAL)

Extract code structure/API surface untuk context compression. Default disabled (`aid.enabled: false` di config). Skip otomatis kalau ga terinstall.

Dipakai oleh: `/fd:run`, `/fd:feature`

```bash
# Download binary dari GitHub releases
# https://github.com/janreges/ai-distiller/releases

# Linux x86_64
curl -L https://github.com/janreges/ai-distiller/releases/latest/download/aid-linux-amd64 -o ~/.local/bin/aid
chmod +x ~/.local/bin/aid
```

Repo: https://github.com/janreges/ai-distiller

#### 3. rg — ripgrep (WAJIB)

Fast text search. Fallback dari ast-grep. Dipakai hampir semua agent & command.

```bash
# Ubuntu/Debian
apt install ripgrep

# macOS
brew install ripgrep

# Cargo
cargo install ripgrep
```

Repo: https://github.com/BurntSushi/ripgrep

### MCP Servers (setup di Claude Code)

MCP servers jalan via `npx` — ga perlu install manual, cukup config di settings.

Tambahkan di `~/.claude/settings.json` atau project-level `.claude/settings.json`:

```json
{
  "mcpServers": {
    "context7": {
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp"]
    },
    "playwright": {
      "command": "npx",
      "args": ["-y", "@anthropic/mcp-playwright"]
    },
    "tavily": {
      "command": "npx",
      "args": ["-y", "tavily-mcp"],
      "env": {
        "TAVILY_API_KEY": "tvly-YOUR_API_KEY"
      }
    },
    "exa": {
      "command": "npx",
      "args": ["-y", "exa-mcp-server"],
      "env": {
        "EXA_API_KEY": "YOUR_API_KEY"
      }
    }
  }
}
```

#### Detail per MCP server

| Server | npm Package | API Key? | Dapet dari mana | Repo |
|--------|------------|----------|-----------------|------|
| **Context7** | `@upstash/context7-mcp` | Tidak perlu | — | https://github.com/nichochar/context7 |
| **Playwright** | `@anthropic/mcp-playwright` | Tidak perlu | — | https://github.com/anthropics/mcp-playwright |
| **Tavily** | `tavily-mcp` | Ya (`TAVILY_API_KEY`) | https://app.tavily.com/home → sign up → API Keys | https://github.com/tavily-ai/tavily-mcp |
| **Exa** | `exa-mcp-server` | Ya (`EXA_API_KEY`) | https://dashboard.exa.ai → sign up → API Keys | https://github.com/exa-labs/exa-mcp-server |

> **Prerequisite:** Node.js >= 18 harus terinstall supaya `npx` jalan.
>
> **Tavily** punya free tier (1000 searches/month). **Exa** punya free tier (1000 searches/month).

## Agent Reference

| Agent | Fungsi | Dipanggil oleh |
|-------|--------|----------------|
| `fd-codebase-mapper` | Analyze codebase per focus area | `/fd:map-codebase`, `/fd:init` |
| `fd-executor` | Execute plan dengan atomic commits | `/fd:run` |
| `fd-phase-researcher` | Research implementasi per phase | `/fd:run` |
| `fd-plan-checker` | Verify plan sebelum execute | `/fd:run` |
| `fd-planner` | Buat execution plan per phase | `/fd:run` |
| `fd-project-researcher` | Research domain ecosystem | `/fd:feature` |
| `fd-research-synthesizer` | Synthesize research outputs | `/fd:feature` |
| `fd-roadmapper` | Buat roadmap dari PROJECT.md | `/fd:feature` |
| `fd-verifier` | Verify phase goal tercapai | `/fd:run` |

## Troubleshooting

### Commands tidak muncul

- Pastikan file ada di `~/.claude/commands/fd/`
- Restart Claude Code
- Cek file permission: `chmod 644 ~/.claude/commands/fd/*.md`

### Agent not found

- Pastikan file ada di `~/.claude/agents/`
- Nama file harus exact match: `fd-executor.md`, bukan `fd_executor.md`

### Path error / file not found saat runtime

- Kemungkinan besar hardcoded path issue
- Cek apakah `/root/.claude/fucking-done/` exist
- Kalau bukan root user, jalankan sed replace di section "Path yang Perlu Diperhatikan"

### Context terlalu besar

- Jalankan `/clear` di antara commands
- Setiap command baca dari filesystem, jadi aman across sessions

### Bug number conflict

- Bug numbers auto-increment di `.fd/bugs/`
- Kalau mau reset, hapus isi `.fd/bugs/`, `.fd/plans/`, `.fd/fixes/`
