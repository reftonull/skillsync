<!--
  Sync Impact Report
  Version change: 0.0.0 → 1.0.0 (initial ratification)
  Added principles:
    - I. Agent-Native, Human-Friendly
    - II. Test-First (NON-NEGOTIABLE)
    - III. Dependency Injection Everywhere
    - IV. Simplicity Over Abstraction
    - V. Deterministic CLI
  Added sections:
    - Technology & Constraints
    - Development Workflow
  Templates:
    - plan-template.md: ✅ Constitution Check section already present, aligns with principles
    - spec-template.md: ✅ User story + acceptance criteria structure aligns with TDD principle
    - tasks-template.md: ✅ Test-first ordering and [P] parallelism markers align with principles
  Follow-up TODOs: none
-->

# SkillSync Constitution

## Core Principles

### I. Agent-Native, Human-Friendly

SkillSync MUST be usable by both AI agents and humans. The CLI,
file formats, and workflows are designed so that an agent can
operate SkillSync without special accommodation — but a human
typing commands in a terminal MUST have an equally clear experience.

- Command output MUST be parseable by agents (structured where
  possible) and readable by humans (clear labels, no junk).
- Skill files (`SKILL.md`, `.meta.toml`) use plain text formats
  that agents can read and write without libraries.
- Error messages MUST state what went wrong and what to do about it.
- Built-in skills exist so that agents can learn to use SkillSync
  by reading skills — SkillSync bootstraps itself.

### II. Test-First (NON-NEGOTIABLE)

Every feature MUST have tests written and failing before the
implementation that makes them pass. Red-Green-Refactor is the
only accepted development cycle.

- Tests are written against the Feature layer, not the CLI layer,
  using in-memory dependencies for full determinism.
- CLI commands are tested separately via snapshot tests on their
  formatted output.
- No feature merges without passing tests that cover the new
  behavior.
- Test names describe the behavior under test, not the method name.

### III. Dependency Injection Everywhere

All external effects (filesystem, git, network, clock, output)
MUST flow through injectable clients using the swift-dependencies
pattern. No feature may call `FileManager`, `Process`, or `print`
directly.

- Live implementations exist for production; test implementations
  use `InMemoryFileSystem` or equivalent fakes.
- Tests MUST override every dependency they touch via
  `withDependencies { ... }`.
- New external integrations MUST introduce a new client type with
  a `testValue` that fails fast if not explicitly overridden.

### IV. Simplicity Over Abstraction

Start with the simplest implementation that satisfies the current
requirement. Do not build for hypothetical futures.

- Prefer three similar lines over a premature abstraction.
- Features are standalone structs with `run(_ input:) -> Result` —
  no inheritance, no protocol hierarchies, no middleware chains.
- If a change touches only one call site, inline it. Extract only
  when a second caller appears.
- Complexity MUST be justified in the PR description when it
  exceeds the obvious minimum.

### V. Deterministic CLI

SkillSync MUST produce the same output given the same inputs and
filesystem state. No network calls, LLM invocations, or
non-deterministic behavior in the core pipeline.

- `sync` reads the canonical store and writes rendered copies +
  symlinks. Nothing else.
- Git operations are the only permitted network side-effect and
  are confined to `push` / `pull` commands.
- Timestamps, UUIDs, and paths are injected dependencies so that
  tests are reproducible.
- Best-effort target sync: one target failing MUST NOT block
  others. Per-target status is always reported.

## Technology & Constraints

- **Language**: Swift 6.0, strict concurrency (`Sendable` by
  default, `NonisolatedNonsendingByDefault`).
- **Platform**: macOS 15+ (Linux support via conditional
  swift-crypto).
- **CLI framework**: swift-argument-parser.
- **DI framework**: swift-dependencies (Point-Free).
- **Testing**: swift-testing + swift-snapshot-testing with inline
  snapshots. Record policy: `.missing` only.
- **Formatting**: swift-format, 120-char line length, enforced in
  CI via `--strict` lint.
- **Canonical store**: `~/.skillsync/` — all skills, config, and
  rendered copies live here.
- **Skill format**: `<name>/SKILL.md` directories following the
  agentskills.io specification.

## Development Workflow

1. **Branch from main** with a descriptive name.
2. **Write tests first** against the Feature struct using
   in-memory dependencies.
3. **Implement** until tests pass. Run `swift format` before
   committing.
4. **Add CLI-layer tests** if the command has user-visible output
   changes, using inline snapshot assertions.
5. **PR review** checks: tests pass, swift-format lint clean,
   constitution principles upheld.
6. **Merge to main** — squash preferred for single-feature
   branches.

## Governance

This constitution is the authoritative source for development
standards in SkillSync. All PRs and code reviews MUST verify
compliance with these principles.

- **Amendments** require a documented rationale, a version bump
  following semver, and updated propagation to templates.
- **Violations** during review MUST be resolved before merge
  unless explicitly justified in a Complexity Tracking table
  (see plan template).
- **Runtime guidance** for agents lives in built-in skills and
  CLAUDE.md — this constitution governs the development process
  itself.

**Version**: 1.0.0 | **Ratified**: 2026-03-16 | **Last Amended**: 2026-03-16
