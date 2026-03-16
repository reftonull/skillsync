# Implementation Plan: Batch Skill Import

**Branch**: `more-than-just-skills` | **Date**: 2026-03-16 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/001-batch-skill-import/spec.md`

## Summary

Extend `AddFeature` so that when the given path (local or GitHub) does
not contain a `SKILL.md` at its root, it enumerates immediate children
and imports each child that does contain a `SKILL.md`. The single-skill
import becomes the n=1 case of the same code path. `AddFeature.Result`
changes to report multiple outcomes. `AddCommand` adapts its output
accordingly.

## Technical Context

**Language/Version**: Swift 6.0
**Primary Dependencies**: swift-dependencies, swift-argument-parser
**Storage**: Filesystem (`~/.skillsync/skills/`)
**Testing**: swift-testing + swift-snapshot-testing, InMemoryFileSystem
**Target Platform**: macOS 15+
**Project Type**: CLI tool + core library
**Constraints**: No network calls in batch detection logic; Git
sparse-checkout is the only network path (GitHub import)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Agent-Native, Human-Friendly | PASS | Per-skill output lines; structured summary |
| II. Test-First (NON-NEGOTIABLE) | PASS | Tests first against Feature layer with InMemoryFileSystem |
| III. Dependency Injection Everywhere | PASS | No new external effects; reuses existing clients |
| IV. Simplicity Over Abstraction | PASS | Extends AddFeature in-place — no new types beyond result changes |
| V. Deterministic CLI | PASS | Children enumerated in sorted order |

## Design

### AddFeature changes

**Detection logic** (applies to both local and GitHub):

1. Check if the path contains `SKILL.md` at its root.
2. If yes: single-skill import (existing behavior, returns one result).
3. If no: enumerate immediate child directories, filter to those
   containing `SKILL.md`, import each. Children without `SKILL.md`
   are reported as skipped.

**Result type change**:

The current `Result` returns a single skill. Change to return an array
of per-skill outcomes:

```
Result
  skills: [SkillResult]

SkillResult
  enum Status: imported | skippedExists | skippedInvalid(reason)
  skillName: String
  skillRoot: URL?          (nil for skipped)
  contentHash: String?     (nil for skipped)
```

Single-skill import returns a one-element array. This is the only
breaking change — callers must adapt to the array.

**Error handling**: The feature no longer throws for "skill already
exists" or "missing SKILL.md in child" — those become skip statuses in
the result array. It still throws for hard errors: source path not
found, source not a directory, no skills found at all (empty parent
with zero valid children).

**GitHub batch**: The `GitHubSkillClient.fetch` already does a sparse
checkout of a path and returns all files recursively. For a parent
directory, the fetched files will have paths like
`child-a/SKILL.md`, `child-a/scripts/run.sh`, `child-b/SKILL.md`.
The feature groups files by top-level directory, checks each group
for a `SKILL.md` key, and imports each group as a separate skill
with `skill-path` metadata set to `<parent>/<child>`.

### AddCommand changes

- When result contains one skill: output matches current format.
- When result contains multiple: per-skill line + summary count.

### No new files needed beyond tests

All changes are in:
- `Sources/SkillSyncCore/Features/AddFeature.swift`
- `Sources/SkillSyncCLI/Commands/AddCommand.swift`
- `Tests/SkillSyncCoreTests/AddFeatureTests.swift`
- `Tests/SkillSyncCLITests/AddCommandTests.swift`

## Project Structure

### Source Code (repository root)

```text
Sources/SkillSyncCore/Features/
└── AddFeature.swift           # Modified — batch detection, array result

Sources/SkillSyncCLI/Commands/
└── AddCommand.swift           # Modified — multi-skill output

Tests/SkillSyncCoreTests/
└── AddFeatureTests.swift      # Modified — batch test cases added

Tests/SkillSyncCLITests/
└── AddCommandTests.swift      # Modified — batch output snapshots
```

## Complexity Tracking

No constitution violations. No complexity justification needed.
