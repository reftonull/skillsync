# Quickstart: Agent Registry Implementation

## Prerequisites

- Read `research.md` for format and bundling decisions
- Read `data-model.md` for the entity model

## Step-by-step

### 1. Add TOMLDecoder dependency

Add `dduan/TOMLDecoder` (0.4.3+) to `Package.swift` — both to the package `dependencies` array and to the `SkillSyncCore` target's dependencies.

### 2. Migrate LoadSyncConfigFeature to TOMLDecoder

Define a `Decodable` struct matching `config.toml`'s shape. Replace the hand-rolled `parseTargets(from:)` and `parseObservationSettings(from:)` with `TOMLDecoder().decode(...)`. Keep `SaveSyncConfigFeature` (the writer) as-is — it's simple string rendering.

### 3. Migrate UpdateMetaFeature.read to TOMLDecoder

Define a `Decodable` struct for `.meta.toml`'s `[skill]` and `[upstream]` sections. Replace the hand-rolled `parse(content:)` with `TOMLDecoder().decode(...)`. Keep the line-level writer (`run(metaURL:updates:)`) as-is — it needs to preserve file structure for incremental updates.

### 4. Create the AgentRegistryEntry model

New file: `Sources/SkillSyncCore/Models/AgentRegistryEntry.swift`

Struct with 5 fields (id, displayName, globalSkillsPath, projectDirectory, defaultLinkMode). Conforms to `Decodable`, `Equatable`, `Sendable`. Use `CodingKeys` to map TOML kebab-case keys to Swift camelCase properties.

Include a `static let registry: [AgentRegistryEntry]` that decodes an embedded TOML string with all 9 agent entries (see `data-model.md` for the pattern).

### 5. Create the AgentRegistryClient dependency

New file: `Sources/SkillSyncCore/Dependencies/AgentRegistryClient.swift`

Following the swift-dependencies pattern (see `BuiltInSkillsClient.swift` for the exact template):
- `liveValue`: Reads from `AgentRegistryEntry.registry`.
- `testValue`: `fatalError` with a message to override in tests (same pattern as `BuiltInSkillsClient`).
- Interface: `entry(for:) -> AgentRegistryEntry?`, `allEntries() -> [AgentRegistryEntry]`, `projectDirectories() -> [String: String]` (maps tool id → project dir name).

### 6. Migrate TargetAddFeature

- Add `@Dependency(\.agentRegistryClient) var registry`
- Replace `KnownTools.defaultPaths[tool]` with `registry.entry(for: tool)?.globalSkillsPath`
- Replace `KnownTools.projectDirectories` iteration with `registry.projectDirectories()`
- Update error message for unknown tools to list all registered agents

### 7. Delete KnownTools.swift

Remove `Sources/SkillSyncCore/Models/KnownTools.swift`. All consumers now use `AgentRegistryClient`.

### 8. Update tests

- `TargetFeaturesTests`: Override `agentRegistryClient` in `withDependencies`. Use a test client with 3 agents (claude-code, codex, cursor) — existing assertions for "codex" still pass.
- `LoadSyncConfigFeatureTests`: Verify existing tests pass with new TOMLDecoder-based parsing.
- `UpdateMetaFeatureTests`: Verify existing tests pass with new TOMLDecoder-based read path.
- Add new test file `AgentRegistryTests.swift`: lookup by id, unknown id returns nil, allEntries returns full list, projectDirectories returns correct mapping.

### 9. Verify

```bash
swift build
swift test
```

All existing tests must pass. New tests must cover the registry lookup paths.
