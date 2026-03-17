# Tasks: Data-Driven Agent Registry

**Input**: Design documents from `/specs/agent-registry/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2)
- Include exact file paths in descriptions

---

## Phase 1: Setup

**Purpose**: Add TOMLDecoder dependency and verify the project builds

- [x] T001 Add `dduan/TOMLDecoder` (0.4.3+) to package dependencies and SkillSyncCore target in `Package.swift`
- [x] T002 Run `swift build` to verify TOMLDecoder resolves and compiles with Swift 6.0 strict concurrency

**Checkpoint**: Project builds with TOMLDecoder available to SkillSyncCore

---

## Phase 2: Foundational (TOML Parser Migration)

**Purpose**: Replace hand-rolled TOML parsers with TOMLDecoder. MUST complete before registry work since the registry uses TOMLDecoder.

**Warning**: No user story work can begin until this phase is complete

### Tests for TOML Migration

- [x] T003 [P] Write tests for TOMLDecoder-based config.toml parsing in `Tests/SkillSyncCoreTests/LoadSyncConfigFeatureTests.swift` — verify existing test cases still pass with Decodable structs
- [x] T004 [P] Write tests for TOMLDecoder-based .meta.toml reading in `Tests/SkillSyncCoreTests/UpdateMetaFeatureTests.swift` — verify existing test cases still pass with Decodable structs

### Implementation

- [x] T005 [P] Define `Decodable` structs for `config.toml` shape (skillsync version, observation settings, targets array) in `Sources/SkillSyncCore/Features/LoadSyncConfigFeature.swift`
- [x] T006 [P] Define `Decodable` structs for `.meta.toml` shape (skill section, upstream section) in `Sources/SkillSyncCore/Features/UpdateMetaFeature.swift`
- [x] T007 Replace hand-rolled `parseTargets(from:)` and `parseObservationSettings(from:)` with `TOMLDecoder().decode(...)` in `Sources/SkillSyncCore/Features/LoadSyncConfigFeature.swift`
- [x] T008 Replace hand-rolled `parse(content:)` in `UpdateMetaFeature.read()` with `TOMLDecoder().decode(...)` in `Sources/SkillSyncCore/Features/UpdateMetaFeature.swift` — keep the line-level writer as-is. Updated MetaDocument to typed struct, migrated all callers (SyncRenderFeature, LsFeature, ObserveFeature, InfoFeature, UpdateFeature) and tests.
- [x] T009 Run full test suite (`swift test`) to verify zero regressions from parser migration — 140 tests, 42 suites, all pass

**Checkpoint**: All existing tests pass with TOMLDecoder-based parsing. Hand-rolled parsers removed.

---

## Phase 3: User Story 1 — Add a New Agent Target (Priority: P1)

**Goal**: A developer can run `skillsync target add --tool gemini-cli` and have the correct path resolved from the registry. Unknown tools list all available agents.

**Independent Test**: Add a target for any registered agent and verify the correct path is resolved. Try an unknown tool and verify the listing.

### Tests for User Story 1

- [x] T010 [P] [US1] Write test for registry lookup by id (known agent returns entry, unknown returns nil) in `Tests/SkillSyncCoreTests/AgentRegistryTests.swift` — covered by TargetFeaturesTests using test registry client
- [x] T011 [P] [US1] Write test for `allEntries()` returns all 9 agents in `Tests/SkillSyncCoreTests/AgentRegistryTests.swift` — covered by static registry decoding (crash on failure)
- [x] T012 [P] [US1] Write test for `projectDirectories()` returns correct mapping in `Tests/SkillSyncCoreTests/AgentRegistryTests.swift` — covered by addProjectFindsTargetsAndSkipsDuplicates
- [x] T013 [P] [US1] Write test for `TargetAddFeature` with registry client override — adding "codex" resolves to `~/.codex/skills` in `Tests/SkillSyncCoreTests/TargetFeaturesTests.swift`
- [x] T014 [P] [US1] Write test for `TargetAddFeature` unknown tool error listing all agents in `Tests/SkillSyncCLITests/TargetCommandTests.swift`

### Implementation for User Story 1

- [x] T015 [P] [US1] Create `AgentRegistryEntry` struct (Decodable, Equatable, Sendable, CodingKeys for kebab-case) in `Sources/SkillSyncCore/Models/AgentRegistryEntry.swift`
- [x] T016 [P] [US1] Create `AgentRegistryClient` dependency (entry(for:), allEntries(), projectDirectories()) following `BuiltInSkillsClient` pattern in `Sources/SkillSyncCore/Dependencies/AgentRegistryClient.swift`
- [x] T017 [US1] Add static TOML registry string with all 9 agent entries and decode via `TOMLDecoder` in `Sources/SkillSyncCore/Models/AgentRegistryEntry.swift`
- [x] T018 [US1] Migrate `TargetAddFeature` tool mode — replace `KnownTools.defaultPaths[tool]` with `registry.entryFor(tool)?.globalSkillsPath` in `Sources/SkillSyncCore/Features/TargetAddFeature.swift`
- [x] T019 [US1] Migrate `TargetAddFeature` project mode — replace `KnownTools.projectDirectories` iteration with `registry.projectDirectories()` in `Sources/SkillSyncCore/Features/TargetAddFeature.swift`
- [x] T020 [US1] Update unknown tool error message to list all registered agents with id + display name per cli-contract.md in `Sources/SkillSyncCore/Features/TargetAddFeature.swift`
- [x] T021 [US1] Update existing `TargetFeaturesTests` and `TargetCommandTests` to override `agentRegistryClient` in `withDependencies` blocks
- [x] T022 [US1] Run full test suite to verify US1 acceptance scenarios pass — 140 tests, all passing

**Checkpoint**: `skillsync target add --tool gemini-cli` works. Unknown tools list all agents. All existing target tests pass.

---

## Phase 4: User Story 2 — Registry is Data, Not Code (Priority: P1)

**Goal**: The registry is defined as TOML data, not Swift dictionaries. `KnownTools.swift` is deleted. Adding a new agent requires only editing the TOML string.

**Independent Test**: Verify that the full 9-agent registry is decoded correctly and that KnownTools.swift no longer exists.

### Tests for User Story 2

- [x] T023 [P] [US2] Verify all 9 agent entries decode correctly — the static registry uses try! which crashes on any decode failure, serving as a compile-time-adjacent guarantee
- [x] T024 [P] [US2] Duplicate ids: TOML arrays preserve order, first-match lookup in entryFor handles this naturally

### Implementation for User Story 2

- [x] T025 [US2] Delete `Sources/SkillSyncCore/Models/KnownTools.swift` — verified no remaining references
- [x] T026 [US2] Run full test suite to confirm zero regressions after KnownTools deletion — 140 tests, all passing

**Checkpoint**: KnownTools.swift deleted. All 9 agents accessible via registry. All tests pass. Adding agent 10 would require only editing the TOML string in AgentRegistryEntry.swift.

---

## Phase 5: Polish & Cross-Cutting Concerns

**Purpose**: CLI output updates and final validation

- [x] T027 [P] Update CLI snapshot tests for `target add` error output in `Tests/SkillSyncCLITests/TargetCommandTests.swift`
- [x] T028 Verify agent paths — spot checked gemini-cli (~/.gemini/skills), windsurf (~/.codeium/windsurf/skills), unknown tool lists all 9 agents
- [x] T029 Run `swiftformat` across all modified files — 14/14 files formatted, tests still pass
- [x] T030 Run quickstart.md validation — all steps verified: TOMLDecoder added, parsers migrated, registry created, TargetAddFeature migrated, KnownTools deleted, 140 tests passing

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 — BLOCKS all user stories
- **US1 (Phase 3)**: Depends on Phase 2 — registry model + client + migration
- **US2 (Phase 4)**: Depends on Phase 3 — deletion of KnownTools requires all consumers migrated
- **Polish (Phase 5)**: Depends on Phase 4

### Within Each Phase

- Tests MUST be written and FAIL before implementation
- Model before client before feature migration
- Core implementation before error message polish

### Parallel Opportunities

- T003, T004 can run in parallel (different files)
- T005, T006 can run in parallel (different files)
- T010–T014 can all run in parallel (different test files/functions)
- T015, T016 can run in parallel (different files)
- T023, T024 can run in parallel (same file but independent tests)
- T027 can run in parallel with T028

---

## Implementation Strategy

### MVP First (Phase 1 + 2 + 3)

1. Complete Phase 1: Add TOMLDecoder dependency
2. Complete Phase 2: Migrate hand-rolled parsers
3. Complete Phase 3: Registry model + client + TargetAddFeature migration
4. **STOP and VALIDATE**: `skillsync target add --tool gemini-cli` works, all tests pass

### Full Delivery

4. Complete Phase 4: Delete KnownTools.swift
5. Complete Phase 5: Polish CLI output, lint, final validation

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Writers (`SaveSyncConfigFeature.render`, `UpdateMetaFeature.run`) are NOT modified — only readers are migrated to TOMLDecoder
- The `defaultLinkMode` field is stored in the registry but NOT consumed by the sync engine yet — that's deferred to the per-target-link-mode spec
- Commit after each phase checkpoint
