# Implementation Plan: Data-Driven Agent Registry

**Branch**: `agent-registry` | **Date**: 2026-03-16 | **Spec**: [spec.md](spec.md)

## Summary

Replace the hardcoded `KnownTools.swift` enum with a data-driven agent registry defined as an embedded TOML string decoded via `TOMLDecoder`. This enables adding new agents without Swift API changes and expands support from 3 to 9 agents. The registry is accessed via an injectable `AgentRegistryClient` dependency, consistent with the project's DI architecture. As a preparatory step, the hand-rolled TOML parsers in `LoadSyncConfigFeature` and `UpdateMetaFeature` are also migrated to `TOMLDecoder`.

## Technical Context

**Language/Version**: Swift 6.0, strict concurrency
**Primary Dependencies**: swift-dependencies, swift-argument-parser, TOMLDecoder (dduan/TOMLDecoder 0.4.3+)
**Storage**: Static TOML string in Swift source, decoded via TOMLDecoder (same embedding pattern as BuiltInSkill.swift)
**Testing**: swift-testing + swift-snapshot-testing, InMemoryFileSystem, dependency overrides
**Target Platform**: macOS 15+ (Linux via conditional swift-crypto)
**Project Type**: CLI tool (library + executable)
**Performance Goals**: N/A (registry is loaded once at command startup; <10 entries)
**Constraints**: One new package dependency (TOMLDecoder). Must use swift-dependencies DI pattern.
**Scale/Scope**: 9 agent entries at launch. Trivially extensible to 50+.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|---|---|---|
| I. Agent-Native, Human-Friendly | Pass | CLI output lists agents with id + display name. Error messages are actionable. |
| II. Test-First (NON-NEGOTIABLE) | Pass | Tests written against Feature layer with injected `AgentRegistryClient`. No `Bundle.module` in tests. |
| III. Dependency Injection Everywhere | Pass | `AgentRegistryClient` is a new injectable dependency. Static array access confined to `liveValue`. |
| IV. Simplicity Over Abstraction | Pass | Single struct + TOML string + one dependency client. No protocol hierarchies, no generic registry patterns. |
| V. Deterministic CLI | Pass | Registry is static data loaded at startup. No network, no randomness. Test client returns a fixed set. |

No violations. No complexity tracking needed.

## Project Structure

### Documentation (this feature)

```text
specs/agent-registry/
├── plan.md              # This file
├── research.md          # Format, bundling, and agent path decisions
├── data-model.md        # AgentRegistryEntry model and TOML schema
├── quickstart.md        # Step-by-step implementation guide
└── contracts/
    └── cli-contract.md  # Updated CLI output for target add
```

### Source Code (repository root)

```text
Sources/SkillSyncCore/
├── Models/
│   ├── AgentRegistryEntry.swift   # NEW: Decodable struct + static TOML registry (9 entries)
│   └── KnownTools.swift           # DELETE after migration
├── Dependencies/
│   └── AgentRegistryClient.swift  # NEW: Injectable client (live decodes TOML, test fatalError)
└── Features/
    ├── TargetAddFeature.swift     # MODIFY: Replace KnownTools lookups with AgentRegistryClient
    ├── LoadSyncConfigFeature.swift # MODIFY: Replace hand-rolled parser with TOMLDecoder
    └── UpdateMetaFeature.swift    # MODIFY: Replace hand-rolled read() parser with TOMLDecoder

Package.swift                      # MODIFY: Add TOMLDecoder dependency

Tests/SkillSyncCoreTests/
├── TargetFeaturesTests.swift      # MODIFY: Override agentRegistryClient dependency
└── AgentRegistryClientTests.swift # NEW: Registry lookup, unknown id, fallback tests
```

**Structure Decision**: No new directories. One new model file, one new dependency client, one new test file. One deletion (`KnownTools.swift`). Four modifications (`Package.swift`, `TargetAddFeature.swift`, `LoadSyncConfigFeature.swift`, `UpdateMetaFeature.swift` read path).
