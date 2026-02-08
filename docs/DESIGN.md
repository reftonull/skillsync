# skillsync: Design Document

## What It Is

A dotfiles manager for AI agent skills. One canonical store, synced to any agents you use. Every skill automatically participates in an observation + refinement loop that makes it better over time.

**Not a package manager.** No registry, no publishing, no dependency resolution. You have skills on disk. This tool manages them.

Reference for skill format standards:
- Agent Skills docs index: https://agentskills.io/llms.txt
- Agent Skills specification: https://agentskills.io/specification.md

## Architecture

```
┌──────────────────────────────────────────────────────┐
│                      USER                             │
│                                                       │
│      Terminal                    Agent Session        │
│         │                             │               │
│         ▼                             ▼               │
│    ┌─────────┐                 ┌─────────────┐        │
│    │   CLI   │◄────────────────│ Agent Skills │       │
│    └────┬────┘   shell calls   └──────┬──────┘        │
│         │                             │               │
│         ▼                             ▼               │
│    ┌──────────────────────────────────────┐           │
│    │     ~/.skillsync/skills/ (canonical) │           │
│    │   Edit files directly here           │           │
│    └──────────────────────────────────────┘           │
│         │                                             │
│         ▼  skillsync sync (render + link)             │
│    ┌──────────────────────────────────────┐           │
│    │   ~/.skillsync/rendered/<destination-id>/ │       │
│    │   (footer-injected skill copies)     │           │
│    └──────────────────────────────────────┘           │
│         │                                             │
│         ▼  symlink                                   │
│    ┌──────────┬──────────┬──────────┐                 │
│    │ Claude   │ Cursor   │ Codex    │  ...            │
│    │ Code     │          │ CLI      │                 │
│    └──────────┴──────────┴──────────┘                 │
└──────────────────────────────────────────────────────┘
```

Agents edit skill files directly under `~/.skillsync/skills/<name>/`. Running `skillsync sync` auto-detects content changes, bumps version and content hash, then renders and symlinks to targets.

## The Store

```
~/.skillsync/
├── .gitignore
├── config.toml
├── skills/
│   ├── pdf/
│   │   ├── SKILL.md              # The actual skill (edit directly)
│   │   ├── scripts/
│   │   └── .meta.toml            # Observations + refinement history (internal)
│   └── code-review/
│       ├── SKILL.md
│       └── .meta.toml
├── rendered/
│   ├── claude-code/
│   │   ├── pdf/
│   │   │   ├── SKILL.md          # Footer-injected rendered copy
│   │   │   └── scripts/...
│   │   └── code-review/...
│   └── codex/...
└── logs/
    ├── pdf.jsonl                 # Observation log
    └── code-review.jsonl
```

## CLI (Deterministic, No LLM)

Implemented today:

```
skillsync init
skillsync new <name> [--description "..."]
skillsync add <path>
skillsync rm <name>
skillsync ls
skillsync target add --tool <name>
skillsync target add --path <path>
skillsync target add --project
skillsync target remove <id>
skillsync target list
skillsync sync
skillsync info <name>
skillsync observe <name> --signal <positive|negative> [--note "..."]
skillsync log <name>
skillsync log <name> --summary
skillsync export <name> <path>
skillsync version
```

Planned next:

```
skillsync config
```

Output shape for `skillsync info <name>`:

```
pdf
  path: /Users/blob/.skillsync/skills/pdf
  version: 3
  state: active
  content-hash: sha256:a1b2c3...
  created: 2026-02-06T00:00:00Z
  source: hand-authored
  invocations: 12 (positive: 7, negative: 5)
```

Output shape for `skillsync log <name> --summary`:

```
pdf: 12 invocations, 7 positive, 5 negative (42% negative)
```

For zero observations:

```
pdf: 0 invocations
```

Output shape for `skillsync log <name>`:

```text
2026-02-07T10:15:00Z  positive  "Handled encrypted input well"
2026-02-07T11:30:00Z  negative  "Failed on multi-page PDF"
2026-02-07T14:00:00Z  negative  "Missed table extraction"
```

`info` is about identity and current state. `log` is usage history over time.

## Built-in Skills

Built-ins are seeded by `skillsync init` into canonical `~/.skillsync/skills/` from bundled templates.
They are first-class skills that can be edited directly and refined like any user-authored skill.
During `skillsync sync`, built-ins are synced like any other canonical skill.

They appear in targets as skill directories such as:

- `~/.claude/skills/skillsync-new/`
- `~/.claude/skills/skillsync-check/`
- `~/.claude/skills/skillsync-refine/`

Built-ins:

1. `skillsync-new`
- Teaches agents how to create a new skill:
  - `skillsync new <name> [--description "..."]`
  - edit `SKILL.md` directly at the skill path
  - `skillsync sync`

2. `skillsync-check`
- Teaches agents how to check a skill's performance:
  - `skillsync info <name>` for version/stats/state
  - `skillsync log <name> --summary` for quick performance signal
  - if performance looks poor, tell the user and ask whether they want refinement
  - do not proceed with refinement unless the user explicitly consents

3. `skillsync-refine`
- Teaches agents how to refine a skill after user approval:
  - read observation history with `skillsync log <name>`
  - run `skillsync info <name> --json` and read `path`
  - edit `SKILL.md` at `<path>/SKILL.md`
  - `skillsync sync`

The split is intentional for progressive disclosure: `skillsync-check` is cheap/read-only, while `skillsync-refine` is loaded only after user approval. Built-in `SKILL.md` content should stay concise.

### Observation Footer Injection

Observation is handled by footer injection during `skillsync sync` into rendered copies only (`~/.skillsync/rendered/<target-id>/<skill>/SKILL.md`). Canonical skills under `~/.skillsync/skills/` stay unchanged.

Config:

```toml
[observation]
mode = "on"   # "on" | "off"
```

When `mode = "on"`, inject:

```markdown
<!-- skillsync:observation:start -->
---
After using this skill, run: skillsync observe <skill-name> --signal positive|negative [--note "..."]
<!-- skillsync:observation:end -->
```

When `mode = "off"`, no footer is injected.

## .meta.toml

Every skill gets one. Auto-created on `skillsync add` and `skillsync new`. This is internal skill memory managed by CLI commands.

```toml
[skill]
created = "2026-02-06T00:00:00Z"
source = "hand-authored"
version = 3
content-hash = "sha256:e3b0c4..."
state = "active"   # active | pending_remove

# [[refinement]] is optional/deferred.
# Version history is tracked by version + content-hash.
# Stats (invocation counts) are derived from logs/ at read time.
```

## Config

```toml
[skillsync]
version = "1"

[observation]
mode = "on"            # "on" | "off"

[[targets]]
id = "codex"
path = "~/.codex/skills"
source = "tool"

[[targets]]
id = "project-claude"
path = "~/Developer/my-app/.claude/skills"
source = "project"
```

Targets are explicitly managed by `skillsync target ...`.
`skillsync sync` always uses all configured `[[targets]]` entries.
`skillsync init` creates the observation config but no default targets.

## Sync Behavior

`skillsync sync`:

1. Load configured targets from `[[targets]]` in `config.toml`.
2. For each active skill, auto-detect content changes: recompute content hash and bump version if changed.
3. For each target, for each skill in the store:
   - Build/update rendered copy at `~/.skillsync/rendered/<destination-id>/<skill>/`
   - If observation mode is `on`, inject the static observation footer into rendered `SKILL.md`
   - Symlink target path entry to rendered skill directory
4. Prune stale managed links in configured targets

`sync` is best-effort: a failure on one target does not block syncing others. Final output reports per-target success/failure.

Footer injection means canonical `SKILL.md` stays pristine. Agent installs are always symlinks, but they point to rendered copies.

## Safety and Lifecycle Rules

1. Agents edit skill files directly under `~/.skillsync/skills/<name>/`.
2. `skillsync sync` auto-detects content changes and bumps version/hash.
3. Do not modify `.meta.toml` — it is managed by skillsync.
4. `skillsync rm <name>` is mark-and-prune: it records intent immediately, and physical removal happens during `skillsync sync`.
5. Prune only removes managed links (entries pointing into `~/.skillsync/rendered/`) and stale rendered directories created by skillsync.

## Example Flows

### Flow 1: First-Time Setup + Target Configuration (CLI)

1. Initialize store:

```bash
skillsync init
```

2. Add known tool targets:

```bash
skillsync target add --tool codex
skillsync target add --tool cursor
skillsync target add --tool claude-code
```

3. Optionally add custom directories:

```bash
skillsync target add --path ~/.codex/skills
skillsync target add --path ~/.cursor/skills
```

4. Optionally add project-local tool targets:

```bash
skillsync target add --project
```

5. Sync:

```bash
skillsync sync
```

### Flow 2: Create Skill from Existing Folder (CLI)

```bash
skillsync add /path/to/pdf-skill
skillsync ls
skillsync sync
```

### Flow 3: Create New Skill in Agent Session (`/skillsync-new`)

1. User runs:

```text
/skillsync-new "Extract and summarize PDF text"
```

2. Agent authors content and executes:

```bash
skillsync new pdf --description "Extract and summarize PDF text"
# agent edits ~/.skillsync/skills/pdf/SKILL.md directly
skillsync sync
```

Note: Flows 4-6 describe observe/check/refine behavior in agent sessions.

### Flow 4: Observation Loop During Normal Use

1. Skill executes in agent session.
2. Footer reminder in rendered `SKILL.md` tells agent to log usage.
3. Agent logs result:

```bash
skillsync observe pdf --signal positive --note "Handled encrypted input"
```

### Flow 5: Check Skill in Agent Session (`/skillsync-check`)

```text
/skillsync-check pdf
```

1. Agent gathers context:

```bash
skillsync info pdf
skillsync log pdf --summary
```

2. If performance looks poor, agent asks user whether to refine.

### Flow 6: Refine Skill in Agent Session (`/skillsync-refine`)

1. User approves refinement after `/skillsync-check`.
2. Agent runs:

```bash
skillsync log pdf --json
# agent reads ~/.skillsync/skills/pdf/SKILL.md and makes targeted edits
skillsync sync
```

## What This Doesn't Do

- No package registry. Get skills however you want.
- No dependency resolution. Skills are independent.
- No automated refinement. Human initiates, human approves.
- No cloud sync. Local-first. Put the store in git if you want history.
- No conflict detection between skills. User's problem.
