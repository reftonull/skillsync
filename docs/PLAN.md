# SkillSync Plan

## How This File Is Used

This is the working implementation tracker. It is updated as work progresses.

Status key:
- `todo`
- `in-progress`
- `done`

## Current Status

- `done` Bootstrap Swift package/scaffold
- `done` Add PF-style CLI test harness
- `done` Implement `skillsync init` with TDD (core + CLI tests)
- `done` Implement `skillsync new` with deterministic whole-skill `content-hash` and TDD
- `done` Implement `skillsync add` import flow with metadata initialization/refresh and TDD
- `done` Implement `skillsync rm` mark-and-prune state transition with TDD
- `done` Implement `skillsync ls` summaries from `.meta.toml` with TDD
- `done` Implement `skillsync export` recursive copy flow with TDD
- `done` Implement sync/render baseline (rendered mirror, footer injection, managed symlink install, best-effort target statuses)
- `done` Refactor sync destination management into `skillsync target` (`add`/`remove`/`list`) backed by `[[targets]]`
- `removed` ~~Implement `skillsync edit` + `skillsync commit` + `skillsync abort`~~ (replaced by direct editing)
- `removed` ~~Update `init` to create `editing/` and `locks/` directories~~ (no longer needed)
- `removed` ~~Ensure successful `commit` removes `editing/<skill>` and lock~~ (no longer needed)
- `done` Remove `skillsync write` command/feature/tests and migrate remaining setup paths
- `done` Move docs to tracked `docs/` directory and align workflow terminology
- `removed` ~~Implement `skillsync diff <name>` with JSON default output~~ (replaced by direct editing)
- `done` Add sync version/hash auto-detection (sync bumps version and content-hash when content changes)
- `done` Implement `skillsync info <name>` with TDD (core + CLI tests)
- `done` Implement `skillsync observe <name> --signal <positive|negative> [--note]` with TDD (core + CLI tests)
- `done` Implement `skillsync log <name> [--summary]` with TDD (core + CLI tests)
- `done` Seed built-in skills during `init` from bundled templates
- `done` Add `BuiltInSkillsClient` dependency seam so `InitFeature` can be unit-tested with injected fixtures

## Milestones

1. Foundation
- `done` Package structure and root command
- `done` Version command
- `done` `init` command
- `done` `init` seeds built-in canonical skills (`skillsync-new`, `skillsync-check`, `skillsync-refine`)

2. Target Management
- `done` Add `skillsync target add --tool <name>` with known defaults + duplicate-path protection
- `done` Add `skillsync target add --path <path>` with generated ids + duplicate-path protection
- `done` Add `skillsync target add --project` project-root discovery + local `<tool>/skills` creation
- `done` Add `skillsync target remove <id>`
- `done` Add `skillsync target list`
- `done` Move config destination model to `[[targets]]`
- `done` Simplify `skillsync sync` to zero-arg config-driven target sync

3. Direct Editing Workflow (replaced edit/commit)
- `removed` ~~edit, commit, abort, diff commands~~ (replaced by direct editing + sync)
- `done` Sync auto-detects content changes and bumps version/hash

4. Sync/Render Hardening
- `done` Rendered mirror pipeline
- `done` Observation footer injection markers
- `done` Best-effort per-target sync reporting
- `done` Prune stale managed links during sync
- `done` Simplify observation modes to on/off (remove auto/remind, threshold, min_invocations)
- `done` Built-ins sync via canonical store seeding (`init`) + normal sync pipeline
- `done` Author built-in skill content (SKILL.md for skillsync-new, skillsync-check, skillsync-refine)
- `removed` ~~Ensure sync/render never reads from editing~~ (editing directory removed)
- `todo` Improve sync output formatting consistency (`path` + `configured_path` behavior documented)

5. Observe + Refine
- `done` `skillsync observe <name> --signal <positive|negative> [--note]`
- `done` `skillsync info <name>` (version, hash, stats, state)
- `done` `skillsync log <name>` / `--summary`
- `done` Observation footer injects static observe reminder when mode is `on`
- `note` Refinement uses direct editing of canonical files + `sync`

6. Hardening
- `todo` Locking + atomic writes across all mutating operations
- `removed` ~~Per-skill single-editor lock files~~ (no longer needed)
- `todo` Integration tests for symlink + prune behavior
- `todo` Exit code + machine-readable output contract
- `todo` Improve stdout UX and parseability (consistent structured lines and `--json` where needed)
