# Feature Specification: Data-Driven Agent Registry

**Created**: 2026-03-16
**Status**: Draft
**Order**: 1 of 6 (no dependencies)
**Input**: Replace the hardcoded `KnownTools.swift` dictionary with a data-driven agent registry, enabling trivial addition of new agents without code changes.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Add a New Agent Target (Priority: P1)

A developer uses Gemini CLI alongside Claude Code. They run `skillsync target add --tool gemini-cli` and their skills immediately sync to Gemini's skill directory. The agent was defined in a registry data file, not compiled into the binary.

**Why this priority**: SkillSync currently supports 3 agents. Competitors support 27-50+. This is table stakes.

**Independent Test**: Can be tested by adding a target for any registered agent and verifying the correct path is resolved.

**Acceptance Scenarios**:

1. **Given** an initialized store, **When** user runs `skillsync target add --tool gemini-cli`, **Then** a target is added with the path from the registry entry for gemini-cli.
2. **Given** an initialized store, **When** user runs `skillsync target add --tool unknown-agent`, **Then** the CLI reports the tool is not in the registry and lists available tools.
3. **Given** a registry with 10+ agents, **When** user runs `skillsync target add --tool` without a name, **Then** the CLI lists all available tools from the registry.

---

### User Story 2 - Registry is Data, Not Code (Priority: P1)

A contributor wants to add support for a new agent. They add an entry to the registry data file, rebuild, and it works. No Swift code changes required.

**Why this priority**: Reduces maintenance burden and contribution friction for expanding agent support.

**Independent Test**: Can be tested by adding a new entry to the registry file, rebuilding, and running `skillsync target add --tool <new-agent>`.

**Acceptance Scenarios**:

1. **Given** a registry data file with a new agent entry, **When** the binary is rebuilt, **Then** the new agent is available via `skillsync target add --tool`.
2. **Given** the registry file is missing or corrupt, **When** the CLI starts, **Then** it falls back to a compiled-in minimum set (claude-code, codex, cursor) and warns on stderr.

---

### Edge Cases

- What happens when two registry entries have the same identifier? First entry wins; warn on stderr.
- What happens when a registry entry has an invalid or empty path? Entry is skipped with a warning.
- What happens when the user's home directory differs from the registry's assumed `~` expansion? The `~` in paths MUST be expanded at runtime via `PathClient`, not at registry load time.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The agent registry MUST be defined in a data file bundled with the binary, not hardcoded in Swift source.
- **FR-002**: Each agent entry MUST specify: identifier (string), display name (string), global skills path (string with `~` expansion), project directory name (string), and default link mode (string: symlink/hardlink/copy).
- **FR-003**: The registry MUST include at minimum: claude-code, codex, cursor, gemini-cli, copilot, windsurf, amp, cline, opencode (9 agents). Aider is excluded — it does not support SKILL.md natively.
- **FR-004**: `skillsync target add --tool <name>` MUST validate against the registry and use the registered global skills path.
- **FR-005**: `skillsync target add --path <path>` MUST continue to work for agents not in the registry.
- **FR-006**: `skillsync target add --tool` with no argument or an unknown tool MUST list all registered agents with their identifiers and display names.
- **FR-007**: If the registry data file cannot be loaded, the CLI MUST fall back to a compiled-in minimum set and emit a warning.
- **FR-008**: The `KnownTools.swift` hardcoded dictionaries MUST be replaced by registry lookups.

### Key Entities

- **Agent Registry Entry**: identifier, display name, global skills path, project directory name, default link mode.
- **Agent Registry**: An ordered collection of registry entries loaded from a data file at CLI startup.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: SkillSync supports at least 9 agents via the registry at launch.
- **SC-002**: Adding a new agent to the registry requires modifying only the data file — zero Swift source changes.
- **SC-003**: All existing tests that reference `KnownTools` continue to pass after migration to the registry.
