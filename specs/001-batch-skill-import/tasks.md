# Tasks: Batch Skill Import

**Input**: Design documents from `specs/001-batch-skill-import/`
**Prerequisites**: plan.md, spec.md, data-model.md, contracts/, research.md

**Tests**: TDD approach — tests written first per Constitution Principle II.

## Path Conventions

- Features: `Sources/SkillSyncCore/Features/`
- CLI commands: `Sources/SkillSyncCLI/Commands/`
- Feature tests: `Tests/SkillSyncCoreTests/`
- CLI tests: `Tests/SkillSyncCLITests/`

---

## Phase 1: Result Type + Refactor Existing

**Purpose**: Change `AddFeature.Result` to the array-based shape and
get all existing tests passing again. No new behavior yet.

- [x] T001 Add `SkillResult` struct, `Status` enum, new `Result` with `skills: [SkillResult]`, and `noSkillsFound` error case in `Sources/SkillSyncCore/Features/AddFeature.swift`
- [x] T002 Update `runLocalImport` and `runGitHubImport` to return the new `Result(skills: [...])` wrapping in `Sources/SkillSyncCore/Features/AddFeature.swift`
- [x] T003 Update all 6 existing tests to assert against the new result shape in `Tests/SkillSyncCoreTests/AddFeatureTests.swift`
- [x] T004 Update `AddCommand` to read `result.skills` and adapt output in `Sources/SkillSyncCLI/Commands/AddCommand.swift`
- [x] T005 Update existing CLI tests for new output shape in `Tests/SkillSyncCLITests/AddCommandTests.swift`

**Checkpoint**: `swift test` passes. Zero behavioral change.

---

## Phase 2: Batch Import

**Purpose**: Add batch detection and import for both local and GitHub.
4 new tests cover the meaningful behavioral boundaries.

### Tests (write first, verify they fail)

- [x] T006 Test: local parent with mixed children — 2 valid skills, 1 invalid (no SKILL.md), 1 already exists in canonical store. Verify: 2 imported in sorted order, 1 skippedExists, 1 skippedInvalid. Single test covers batch detection, sorted enumeration, skip semantics, and result array shape. In `Tests/SkillSyncCoreTests/AddFeatureTests.swift`
- [x] T007 Test: GitHub parent with 2 skill children (mock returns flat file dict with `a/SKILL.md`, `a/companion.txt`, `b/SKILL.md`). Verify: both imported, each has `skill-path` metadata of `parent/a` and `parent/b` (not `parent/`), companion files preserved. In `Tests/SkillSyncCoreTests/AddFeatureTests.swift`
- [x] T008 Test: local parent with zero valid children (empty or only non-skill dirs) throws `noSkillsFound`. In `Tests/SkillSyncCoreTests/AddFeatureTests.swift`
- [x] T009 Test: local directory with `SKILL.md` at root AND child directories containing `SKILL.md` — imports as single skill, children ignored. Verifies root `SKILL.md` takes precedence. In `Tests/SkillSyncCoreTests/AddFeatureTests.swift`

### Implementation

- [x] T010 Add batch detection to `runLocalImport`: no `SKILL.md` at root → enumerate immediate children, iterate sorted, import each valid child, catch exists/invalid as skip statuses, throw `noSkillsFound` if zero valid. In `Sources/SkillSyncCore/Features/AddFeature.swift`
- [x] T011 Add batch detection to `runGitHubImport`: no root `SKILL.md` in fetched files → group by first path component, import each group as separate skill with corrected `skill-path`. In `Sources/SkillSyncCore/Features/AddFeature.swift`

**Checkpoint**: `swift test` passes. All 4 new tests green.

---

## Phase 3: CLI Output

**Purpose**: Format batch results for humans and agents.

- [x] T012 Write CLI snapshot test for batch output (mixed imported + skipped) in `Tests/SkillSyncCLITests/AddCommandTests.swift`
- [x] T013 Update `AddCommand.run()` batch formatting: per-skill status lines + summary count in `Sources/SkillSyncCLI/Commands/AddCommand.swift`
- [x] T014 Run `swift format -r Sources/ Tests/` and verify `--strict` lint passes

**Checkpoint**: Full feature complete. All tests green, formatted.

---

## Dependencies

- Phase 1 → Phase 2 → Phase 3 (sequential)
- MVP: Phase 1 + Phase 2 unblocks the spec-kit use case

## Test Summary

- **4 new feature tests** (T006-T009) covering the 4 meaningful boundaries
- **6 existing tests** updated for result shape (T003)
- **1 new CLI test** (T012)
- **Total: 11 tests** for AddFeature (was 6, +5 new behaviors)
