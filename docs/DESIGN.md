# skillsync: Design Document

## What It Is

A dotfiles manager for AI agent skills. One canonical store, synced to any agents you use. Every skill automatically participates in an observation + refinement loop that makes it better over time.

**Not a package manager.** No registry, no publishing, no dependency resolution. You have skills on disk. This tool manages them.

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
│    │     ~/.skillsync/ (canonical)        │           │
│    │   CLI-owned committed skill state    │           │
│    └──────────────────────────────────────┘           │
│         ▲                                             │
│         │  skillsync commit (validate + commit)       │
│    ┌──────────────────────────────────────┐           │
│    │      ~/.skillsync/editing/           │           │
│    │   Single-editor working copy         │           │
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

**Hard rule:** Agents may edit files directly only under `~/.skillsync/editing/`. Committed state under `~/.skillsync/skills/` is updated only by CLI (`skillsync commit`). Only one active editor per skill is allowed at a time via per-skill lock files.

## The Store

```
~/.skillsync/
├── config.toml
├── skills/
│   ├── pdf/
│   │   ├── SKILL.md              # The actual skill
│   │   ├── scripts/
│   │   └── .meta.toml            # Observations + refinement history (internal)
│   └── code-review/
│       ├── SKILL.md
│       └── .meta.toml
├── editing/
│   ├── pdf/
│   │   ├── SKILL.md              # Agent-edited working copy
│   │   └── scripts/
│   └── code-review/
│       ├── SKILL.md
│       └── scripts/
├── locks/
│   ├── pdf.lock                  # Per-skill edit lock (timestamp + context)
│   └── code-review.lock
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
skillsync edit <name>
skillsync edit <name> --force
skillsync commit <name> --reason "<text>"
skillsync abort <name>
skillsync target add --tool <name>
skillsync target add --path <path>
skillsync target add --project
skillsync target remove <id>
skillsync target list
skillsync sync
skillsync diff <name>   # JSON output by default (no --json flag)
skillsync info <name>
skillsync export <name> <path>
skillsync version
```

Planned next:

```
skillsync config
skillsync observe <name> --signal <positive|negative> [--note "..."]
skillsync log <name>
skillsync log <name> --summary
```

Output shape for `skillsync info <name>`:

```
pdf
  version: 3
  state: active
  content-hash: sha256:a1b2c3...
  created: 2026-02-06T00:00:00Z
  source: hand-authored
  invocations: 12 (positive: 7, negative: 5)
```

Planned output shape for `skillsync log <name> --summary`:

```
pdf: 12 invocations, 7 positive, 5 negative (58%)
```

Planned output shape for `skillsync log <name>`:

```text
2026-02-07T10:15:00Z  positive  "Handled encrypted input well"
2026-02-07T11:30:00Z  negative  "Failed on multi-page PDF"
2026-02-07T14:00:00Z  negative  "Missed table extraction"
```

`info` is about identity and current state. `log` is usage history over time.

## Edit + Commit Model

`skillsync` uses two skill states:

1. Canonical (`~/.skillsync/skills/<name>/`): committed source of truth used for sync/render.
2. Editing (`~/.skillsync/editing/<name>/`): active working tree for the current lock holder.

Workflow:

1. `skillsync edit <name>` acquires a per-skill lock and creates or refreshes editing from canonical.
2. If lock exists, `skillsync edit <name> --force` breaks lock, resets edit copy from canonical, and acquires a new lock.
3. CLI prints the absolute edit path. Agents edit files directly there.
4. `skillsync diff <name>` returns JSON changes vs canonical for agent consumption.
5. `skillsync commit <name> --reason "<text>"` validates and atomically commits edit changes to canonical, then releases the lock.
6. `skillsync abort <name>` discards editing copy and releases the lock without committing.

`diff` JSON shape:

```json
{
  "skill": "pdf",
  "changes": [
    {
      "path": "SKILL.md",
      "status": "modified",
      "kind": "text",
      "old_text": "...",
      "new_text": "..."
    }
  ],
  "summary": { "added": 0, "modified": 1, "deleted": 0 }
}
```

`skillsync commit` responsibilities:

1. Validate allowed paths and block reserved/internal files.
2. Copy edit files to canonical with deterministic traversal.
3. Recompute `content-hash` and bump version.
4. Remove the active `editing/<name>` directory on success.
5. Release the edit lock on success.
6. Record refinement/change metadata from `--reason` is planned.

Lock behavior:

1. Only one editor can hold a skill lock at a time.
2. `skillsync edit <name>` fails with lock file path if lock already exists.
3. `skillsync edit <name> --force` is the explicit stale-lock takeover path.
4. `skillsync abort <name>` or `skillsync commit <name>` releases the lock.

## Agent Skills

These are the target built-ins that ship with skillsync and get synced alongside user skills. They require LLM judgment. Some supporting backend commands are still planned.

Built-in agent commands:
- `/skillsync-new <description>`
- `/skillsync-refine <skill-name>`

### Observation (Not a Standalone Skill)

Observation is handled by **footer injection during the render step in `skillsync sync`**. The CLI appends a small block to the rendered `SKILL.md` under `~/.skillsync/rendered/<destination-id>/<skill>/`. The canonical store copy under `~/.skillsync/skills/` stays clean.

Controlled by config:

```toml
[observation]
mode = "auto"       # "auto" | "remind" | "off"
threshold = 0.3     # negative rate to trigger nudge
min_invocations = 5 # minimum before nudging
```

**`remind` mode** appended footer:

```markdown
---
After completing this skill, remind the user:
"Rate this result: `skillsync observe <skill-name> --signal <positive|negative> [--note]`"
```

**`auto` mode** appended footer:

```markdown
---
After completing this skill, assess whether the user was satisfied.
Call: skillsync observe <skill-name> --signal <positive|negative> --note "<brief reason>"
Then call: skillsync log <skill-name> --summary
If negative rate exceeds threshold, mention:
"(<skill-name> has been struggling - <N>/<total> negative. `/skillsync-refine <skill-name>` when you have a moment.)"
Otherwise, briefly note what you logged: "(logged: positive)"
```

This means no separate observer skill consuming context. Every skill self-observes. The cost is a few lines of injected text. The agent never nags about refinement. It just surfaces stats as a trailing line on something already happening.

### `/skillsync-refine <skill-name>` (User-Invoked, Agent-Only)

The refinement skill. User entry point is agent-only. It uses `skillsync info`, `skillsync log`, and the existing `edit -> commit -> sync` workflow.

How it works:

The insight from practitioners (AGENTS.md pattern, Voyager skill libraries, Addy Osmani's compound loops): refinement is about appending corrections to a text file the agent reads next time. The novelty here is observation infrastructure with real data instead of relying on user memory.

Steps:

1. Call `skillsync info <name>` for skill identity/state (version/hash/stats/state/source).
2. Call `skillsync log <name>` or `skillsync log <name> --summary` for usage history.
3. Read the current `SKILL.md` from the store.
4. Analyze patterns in negative signals using log notes.
5. Propose a specific diff to `SKILL.md` addressing top failure clusters.
6. User reviews. Accepts, rejects, or edits.
7. On accept, call `skillsync edit <name>` (or `skillsync edit <name> --force` with user consent), apply changes, then call `skillsync commit <name> --reason "<text>"` and `skillsync sync`.

What it does not do: no automated refinement, no background runs, no RL training. It is a structured, human-in-the-loop edit cycle with data backing. The agent proposes. The user decides.

### `/skillsync-new <description>` (User-Invoked, Agent-Only)

Interactive skill authoring. Agent asks clarifying questions, then edits working files directly:

1. `skillsync new <name> --description "<one-line intent>"`
2. `skillsync edit <name>`
3. Agent writes `SKILL.md` and assets under `~/.skillsync/editing/<name>/`
4. `skillsync commit <name> --reason "initial authoring"`

This keeps creation and updates ergonomic for agents while preserving canonical safety/audit boundaries.

## .meta.toml

Every skill gets one. Auto-created on `skillsync add` and `skillsync new`. This is internal skill memory managed by CLI commands.

```toml
[skill]
created = "2026-02-06T00:00:00Z"
source = "hand-authored"
version = 3
content-hash = "sha256:e3b0c4..."
state = "active"   # active | pending_remove

[stats]
total-invocations = 47
positive = 38
negative = 9

# [[refinement]] is optional/deferred.
# Version history is tracked by version + content-hash.
```

## Config

```toml
[skillsync]
version = "1"

[observation]
mode = "auto"          # "auto" | "remind" | "off"
threshold = 0.3        # negative rate to nudge
min_invocations = 5

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
2. For each target, for each skill in the store:
   - Build/update rendered copy at `~/.skillsync/rendered/<destination-id>/<skill>/`
   - If observation mode != `off`, inject the configured footer into rendered `SKILL.md`
   - Symlink target path entry to rendered skill directory
3. Also place built-in agent skills (`skillsync-refine`, `skillsync-new`)
4. Prune stale managed links in configured targets
5. Print warnings if any skills have high negative rates

`sync` is best-effort: a failure on one target does not block syncing others. Final output reports per-target success/failure.

Footer injection means canonical `SKILL.md` stays pristine. Agent installs are always symlinks, but they point to rendered copies.

## Safety and Lifecycle Rules

1. Agents may directly edit only `~/.skillsync/editing/<name>/`.
2. `skillsync commit <name>` is the only command that can commit edit changes into canonical `~/.skillsync/skills/<name>/`.
3. `skillsync commit` rejects reserved/unsafe paths (`.meta.toml`, absolute paths, `..`, symlink escapes, and paths outside the skill root).
4. Only one active editor lock per skill is allowed. `edit` fails if a lock already exists.
5. `skillsync rm <name>` is mark-and-prune: it records intent immediately, and physical removal happens during `skillsync sync`.
6. Prune only removes managed links (entries pointing into `~/.skillsync/rendered/`) and stale rendered directories created by skillsync.

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
skillsync edit pdf
# agent edits ~/.skillsync/editing/pdf/SKILL.md and scripts/extract.py directly
skillsync commit pdf --reason "initial authoring"
```

Note: Flows 4-5 describe planned observe/refine backend commands.

### Flow 4: Observation Loop During Normal Use (Auto Footer)

1. Skill executes in agent session.
2. Agent logs result:

```bash
skillsync observe pdf --signal positive --note "Handled encrypted input"
skillsync log pdf --summary
```

3. If negative rate is high, agent nudges:

```text
/skillsync-refine pdf
```

### Flow 5: Refine Skill in Agent Session (`/skillsync-refine`)

1. Agent gathers context:

```bash
skillsync info pdf
skillsync log pdf --summary
skillsync log pdf
```

2. Agent proposes edit changes; user approves.
3. Agent applies refinement:

```bash
skillsync edit pdf
# if edit is locked and user approves takeover:
# skillsync edit pdf --force
# agent edits ~/.skillsync/editing/pdf/SKILL.md
skillsync commit pdf --reason "Improve encrypted-file handling"
```

4. Agent confirms:

```bash
skillsync log pdf --summary
```

## What This Doesn't Do

- No package registry. Get skills however you want.
- No dependency resolution. Skills are independent.
- No automated refinement. Human initiates, human approves.
- No cloud sync. Local-first. Put the store in git if you want history.
- No conflict detection between skills. User's problem.
