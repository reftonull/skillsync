# SkillSync Implementation Guide (Swift)

This guide turns `/Users/laksh/Developer/skillsync/docs/DESIGN.md` into an implementable Swift plan.

## Scope

Build a local-first CLI that:

1. Maintains canonical skills in `~/.skillsync/skills`.
2. Renders footer-injected copies in `~/.skillsync/rendered/<target-id>/`.
3. Symlinks target skill entries to rendered directories.
4. Auto-detects content changes during sync and bumps version/hash.
5. Supports observation logging and human-in-the-loop refinement.
6. Uses mark-and-prune lifecycle for skill removal (`skillsync rm`).
7. Syncs to configured `[[targets]]` managed by `skillsync target add/remove/list`.

## External References

- Agent Skills docs index: https://agentskills.io/llms.txt
- Agent Skills specification: https://agentskills.io/specification.md

## Implementation Snapshot (Current)

Implemented:

1. `init`, `new`, `add`, `rm`, `ls`, `export`, `sync`, `target add/remove/list`, `remote set`, `push`, `pull`, `version`, `info`, `observe`, `log`.
2. Direct editing of canonical skill files — no editing directory or locks.
3. `sync` auto-detects content changes, bumps `version`, and updates `content-hash`.

Planned:

1. Global locking and stricter atomic-write guarantees.

## Swift Stack

Recommended baseline:

1. Swift tools `6.0`.
2. CLI: [`swift-argument-parser`](https://github.com/apple/swift-argument-parser).
3. Testing: [`swift-testing`](https://github.com/swiftlang/swift-testing).
4. Dependency injection: [`swift-dependencies`](https://github.com/pointfreeco/swift-dependencies).
5. Assertion diffing: [`swift-custom-dump`](https://github.com/pointfreeco/swift-custom-dump).
6. Output snapshots: `InlineSnapshotTesting` from [`swift-snapshot-testing`](https://github.com/pointfreeco/swift-snapshot-testing).
7. Concurrency helpers: [`swift-concurrency-extras`](https://github.com/pointfreeco/swift-concurrency-extras).
8. TOML parser: choose one package and wrap it behind a small client protocol.

Current package direction already matches this (including `NonisolatedNonsendingByDefault`). Keep that aligned with pfw conventions.

## Package Layout (SPM)

```text
skillsync/
  Package.swift
  Sources/
    skillsync/
      main.swift
    SkillSyncCLI/
      SkillSync.swift
      Commands/
      Parsing/
    SkillSyncCore/
      App/
      Config/
      Store/
      Skill/
      Render/
      Sync/
      Observe/
      Refine/
      Prune/
      Dependencies/
      Models/
      Util/
  Tests/
    Internal/
      InMemoryFileSystem.swift
      AssertCommand.swift
      BaseSuite.swift
    SkillSyncCoreTests/
    SkillSyncCLITests/
  docs/
    DESIGN.md
    IMPLEMENTATION_GUIDE.md
    PLAN.md
```

## Concurrency + Command Scaffolding (pfw-style)

1. Keep root command and subcommands thin; put logic in core features.
2. Enable `NonisolatedNonsendingByDefault` in all targets (already present).
3. Prefer nonisolated command configuration/static metadata patterns used in pfw to avoid unnecessary actor isolation in parser plumbing.
4. Keep command `run()` methods async where needed, but route side effects through dependencies.

## Core Models

### `config.toml`

```toml
[skillsync]
version = "1"

[observation]
mode = "on"   # on | off

[[targets]]
id = "codex"
path = "~/.codex/skills"
source = "tool"
```

Target rows are the single source of truth for sync destinations. `source` is informational (`tool`, `path`, `project`).
`skillsync init` should create no default targets.

### `.meta.toml`

```toml
[skill]
created = "2026-02-06T00:00:00Z"
source = "hand-authored"
version = 1
content-hash = "sha256:..."
state = "active"   # active | pending_remove
```

`[[refinement]]` is optional/deferred. Version history is tracked by `version` + `content-hash`.
Stats (invocation counts) are derived from `logs/<name>.jsonl` at read time by `info` and `ls`.

### Observation log (`logs/<skill>.jsonl`)

Per line JSON:

```json
{"ts":"2026-02-06T20:10:11Z","signal":"positive","note":"Handled encrypted input","tool":"codex","session_id":"abc123","version":2}
```

Required fields:

1. `ts` RFC3339 UTC
2. `signal` in `positive|negative`
3. `version` skill version at log time

Optional:

1. `note`
2. `tool`
3. `session_id`

## Dependency Architecture (Point-Free Style)

Use `swift-dependencies` so all command behavior is deterministic in tests.

Dependencies to define:

1. `FileSystemClient`
2. `Clock`
3. `UUIDGenerator`
4. `DateClient` (RFC3339 encode/decode)
5. `TOMLClient` (decode/encode)
6. `LockClient`
7. `GitClient` (for git subprocess calls in `remote set` / `push` / `pull`)
8. `OutputClient` (`stdout` / `stderr`)
9. `PathClient` (home expansion, path joins, validation)
10. `BuiltInSkillsClient` (loads built-in skill templates for `init`; override in tests)

Pattern:

1. `SkillSyncCore` exposes feature reducers/services with dependencies.
2. `SkillSyncCLI` maps args to core calls and formats user output.
3. No live globals in features; everything injectable.

## FileSystem Strategy

### Live client

Backed by `FileManager` + system calls where needed:

1. Create directories
2. Read/write files
3. Atomic rename
4. Symlink create/read
5. `lstat` and canonical path checks

### Test client

Use in-memory FS in `Tests/Internal`.

Requirements:

1. Model files, directories, symlinks distinctly.
2. Preserve deterministic directory listing order.
3. Support failure injection (permission denied, exists, missing parent, etc.).
4. Provide snapshot-friendly tree description.
5. For pure unit tests of `InitFeature`, inject `BuiltInSkillsClient` fixtures so tests do not read from the real bundle.

Keep a separate integration layer for real symlink and lock behavior using temp directories.

## Command Semantics

### Foundation

1. `skillsync init`
- Create root dirs and default config.
- Ensure `.gitignore` contains default local-only entries (`config.toml`, `rendered/`, `logs/`).
- Seed built-in canonical skills from bundled templates.
- Idempotent.

2. `skillsync remote set [--name <remote>] <url>`
- Ensure store exists.
- Initialize git repository when missing.
- Add or update remote URL.

### Skill lifecycle

1. `skillsync new <name> [--description]`
- Validate skill name.
- Create `skills/<name>/SKILL.md` scaffold.
- Create `skills/<name>/.meta.toml`.

2. `skillsync add <path>`
- Import existing folder containing `SKILL.md`.
- Initialize `.meta.toml` if missing.

3. `skillsync add [--force] github <owner/repo> <skill-path> [<ref>]`
- Import a skill directory from GitHub into canonical store.
- Prompt for confirmation by default because remote content can be untrusted.
- `--force` skips confirmation.

4. `skillsync rm <name>`
- Mark `skill.state = pending_remove`.
- Physical deletion occurs during next successful prune step in `sync`.

5. `skillsync ls`
- Print skills, state, and summary stats.

6. `skillsync info <name>`
- Print metadata from `.meta.toml`:
  - version, state, content-hash, created, source, invocation totals.

7. `skillsync export <name> <path>`
- Copy canonical skill to external path.

### Target management + sync

1. `skillsync target add --tool <name>`
- Supported tool names: `claude-code`, `codex`, `cursor`.
- Known defaults:
  - `claude-code -> ~/.claude/skills`
  - `codex -> ~/.codex/skills`
  - `cursor -> ~/.cursor/skills`
- Append a `[[targets]]` row with `source = "tool"`.
- Error for unknown tool or duplicate resolved path.

2. `skillsync target add --path <path>`
- Resolve and normalize path.
- Generate id (`path-1`, `path-2`, ...).
- Append a `[[targets]]` row with `source = "path"`.
- Error for duplicate resolved path.

3. `skillsync target add --project`
- Walk upward from CWD to find project root:
  - Prefer first ancestor with `.git`.
  - Else top-most ancestor containing `.claude`, `.codex`, or `.cursor`.
- For each existing project-local tool dir, add `<tool-dir>/skills`.
- If `<tool-dir>` exists and `skills` does not, create `skills`.
- Append rows with `source = "project"`, skip duplicates by resolved path.

4. `skillsync target remove <id>`
- Remove matching target row.
- Error if id not found.

5. `skillsync target list`
- Print `<id> <path>` per target.

6. `skillsync sync`
- No flags.
- Load all configured `[[targets]]` and sync to all.
- Error if no targets configured.

### Git workflow

1. `skillsync push [--remote <name>] [-m <message>]`
- Run `git add -A`.
- Commit only if staged diff is non-empty.
- Push to remote branch (`--set-upstream <remote> HEAD`).

2. `skillsync pull`
- Run `git pull --ff-only` in `~/.skillsync`.
- If targets are configured, run `sync` immediately after pull.

### Sync + render behavior

Before rendering targets, for each active skill:

1. Recompute content hash and compare against stored `content-hash` in `.meta.toml`.
2. If changed, update `content-hash` and increment `version` in `.meta.toml`.

For each configured target:

1. Render each active skill to `~/.skillsync/rendered/<destination-id>/<skill>/`.
2. Copy all skill files into rendered location.
3. If observation mode is `on`, inject the static observation footer into rendered `SKILL.md`.
4. Symlink target-path skill entry to rendered skill directory.
5. Built-ins are not special-cased in sync. They are canonical skills seeded by `init`, so they flow through the same render/symlink path.
6. Prune stale managed links in that target.

Footer idempotency markers:

```markdown
<!-- skillsync:observation:start -->
---
After using this skill, run: skillsync observe <skill-name> --signal positive|negative [--note "..."]
<!-- skillsync:observation:end -->
```

Never duplicate footer blocks.

### Built-in skills

Built-ins are authored in the SkillSync codebase and synced alongside user skills to every configured target.
They appear as skill directories in each target path, for example `~/.claude/skills/skillsync-new/`, `~/.claude/skills/skillsync-check/`, and `~/.claude/skills/skillsync-refine/`.

1. `skillsync-new`
- Guides agent flow for creating a skill:
  - `skillsync new <name> [--description "..."]`
  - edit `SKILL.md` directly at the skill path
  - `skillsync sync`

2. `skillsync-check`
- Guides agent flow for checking performance:
  - `skillsync info <name>`
  - `skillsync log <name> --summary`
  - if performance is poor, ask user whether to refine
  - do not continue into refinement without explicit user consent

3. `skillsync-refine`
- Guides agent refinement workflow (only after user approval):
  - read observation history with `skillsync log <name>`
  - run `skillsync info <name> --json` and read `path`
  - edit `SKILL.md` at `<path>/SKILL.md`
  - `skillsync sync`

Split rationale: `skillsync-check` is cheap/read-only and surfaces status, while `skillsync-refine` is a longer workflow loaded only when needed. Built-in `SKILL.md` content should remain concise and progressive.

### Observe + info + log

1. `skillsync observe <name> --signal <positive|negative> [--note]`
- Append JSONL record.

2. `skillsync info <name>`
- Print skill metadata from `.meta.toml` (identity) and `logs/` (stats):
  - path, version, state, content-hash, created, source, invocation totals (derived from logs).
- Example:
  - `pdf`
  - `  path: /Users/blob/.skillsync/skills/pdf`
  - `  version: 3`
  - `  state: active`
  - `  content-hash: sha256:a1b2c3...`
  - `  created: 2026-02-06T00:00:00Z`
  - `  source: hand-authored`
  - `  invocations: 12 (positive: 7, negative: 5)`

3. `skillsync log <name> --summary`
- Print one-line usage summary from JSONL history (not from `.meta.toml` counters).
- Example: `pdf: 12 invocations, 7 positive, 5 negative (42% negative)`
- Zero-observation case: `pdf: 0 invocations`

4. `skillsync log <name>`
- Print full observation history.
- Example:
  - `2026-02-07T10:15:00Z  positive  "Handled encrypted input well"`
  - `2026-02-07T11:30:00Z  negative  "Failed on multi-page PDF"`

### Refine flow (no extra refine/review commands)

1. Agent reads context from:
- `skillsync info <name>`
- `skillsync log <name>` or `skillsync log <name> --summary`

2. Agent runs `skillsync info <name> --json`, reads `path`, and edits `SKILL.md` at `<path>/SKILL.md`.

3. Agent runs `skillsync sync` to apply changes. Sync auto-detects content changes and bumps version/hash.

## Atomicity and Locking

Hardening target:

1. Add global lock (`~/.skillsync/.lock`) for config/target/sync/prune operations.
2. Add temp-file + atomic rename flow for all mutating writes.

## Best-Effort Sync Contract

1. Continue syncing remaining targets even if one fails.
2. Exit `0` if all selected targets succeed.
3. Exit `1` if any selected target fails.
4. Always print per-target status lines:

```text
target=codex path=/Users/me/.codex/skills status=ok
target=cursor path=/Users/me/.cursor/skills status=failed error="permission denied"
target=custom-1 path=/tmp/skills status=ok
```

## Mark-and-Prune Rules

1. `skill.state=pending_remove`:
- During `sync`, remove managed links for that skill from selected targets.
- Remove rendered copies for that skill.
- Remove canonical `skills/<name>/` once prune completes.

2. Managed-link safety rule:
- Only delete entries that are symlinks pointing into `~/.skillsync/rendered/`.
- Never delete unmanaged user files/directories in target paths.

3. Stale rendered cleanup:
- Remove rendered destination directories that no longer map to any configured target.

## Testing Strategy (with `reference/pfw` patterns)

### Unit tests (`swift-testing`)

Cover:

1. Footer injection idempotency and replacement markers.
2. Observation/stat counter updates.
3. `rm` mark-and-prune transitions.
4. Target parsing/writing for `[[targets]]`.
5. `target add --project` root detection and `skills` auto-create.
6. Best-effort sync result aggregation.
7. Sync auto-detection of content changes and version/hash bumps.
8. Output formatting (`log --summary`, sync status lines, actionable errors).

Use `expectNoDifference` / `expectDifference` for structural assertions.

### Test harness conventions (PF-style)

1. `BaseSuite` traits:
- `.serialized` for global-state safety.
- `.dependencies { ... }` for deterministic defaults.

2. Deterministic defaults:
- incrementing UUIDs
- fixed date/clock
- in-memory FS
- captured stdout/stderr

3. CLI helpers:
- `assertCommand(args:stdout:stderr:exitCode:)`
- `assertCommandThrows(args:error:)`

4. Snapshot strategy:
- Inline snapshot for CLI output (`as: .lines`).
- Snapshot in-memory FS trees before/after command runs.

5. Failure injection:
- Explicit FS errors for permission denied, path exists, missing parent.
- Verify prune never removes unmanaged entries.

### Integration tests (real filesystem)

Use temp directories + live FS client for:

1. Symlink semantics on macOS.
2. Atomic replace behavior.
3. End-to-end flow:
- `init -> target add --path ... -> new -> edit files -> sync`
- `observe -> log --summary`
- `rm -> sync` prune validation.
4. Best-effort sync where one target fails and others succeed.

### CLI output tests and stdout capture

Match pfw style by injecting output dependencies instead of writing directly to process globals. This keeps tests fully hermetic and avoids live stdout side effects.

## Milestones

1. **M1: Package + command skeleton**
- SPM modules, argument parser tree, dependency keys.

2. **M2: Store/config + target management foundation**
- `init`, `config`, `[[targets]]` parser/writer, `target add/remove/list`.

3. **M3: Skill CRUD**
- `new`, `add`, `rm`, `ls`, `export`.

4. **M4: Render/sync pipeline**
- Rendered mirror, footer injection, symlink installs, best-effort reporting, prune.

5. **M5: Observe + refine**
- `observe`, `info`, `log`, static observation footer reminder, built-in check/refine split flow.

6. **M6: Hardening**
- Atomicity, integration tests, output snapshots, docs polish.

## Next Vertical Slice

Recommended immediate slice from current baseline:

1. Improve sync output formatting and machine-readable output contracts.
2. Add global locking for config/target/sync operations.

Deliverable: stronger operational hardening with the simplified direct-edit workflow.
