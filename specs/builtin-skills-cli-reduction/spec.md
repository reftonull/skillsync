# Feature Specification: Built-in Skills & CLI Reduction

**Created**: 2026-03-16
**Status**: Draft
**Order**: 5 of 6 (depends on: layered-stores)
**Input**: Remove the `add`, `update`, and `export` commands from the CLI and replace them with built-in skills that guide agents through the same workflows using CLI primitives. Add new `skillsync-import` and `skillsync-setup` built-in skills. Update existing `skillsync-new` to handle project skill creation and seeding from global skills.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Import via Built-in Skill (Priority: P1)

A developer asks their AI agent to import a skill from a GitHub repository. The agent loads the `skillsync-import` built-in skill, which instructs it to clone the repo, copy the relevant skill directory into the canonical store, and run `skillsync sync`. No dedicated import command exists in the CLI.

**Why this priority**: This validates the core design principle — complex workflows are handled by skills, not CLI commands. If import works as a skill, the pattern is proven.

**Independent Test**: Can be tested by having an agent follow the `skillsync-import` skill instructions to import a skill from a known GitHub repo, then verifying the skill exists in the store and syncs correctly.

**Acceptance Scenarios**:

1. **Given** the `skillsync-import` built-in skill is installed, **When** a user asks their agent to import a skill from a GitHub URL, **Then** the agent follows the skill's instructions to: clone/fetch the repo, identify the skill directory, copy it into `~/.skillsync/skills/<name>/`, create `.meta.toml`, and run `skillsync sync`.
2. **Given** the `skillsync-import` skill, **When** an agent imports from a local path, **Then** the skill instructs: copy the directory, create `.meta.toml`, run `skillsync sync`.
3. **Given** the `skillsync-import` skill, **When** an agent imports into a project store, **Then** the skill instructs: use `--project` flag and place files in `./.skillsync/skills/`.

---

### User Story 2 - First-Time Setup via Built-in Skill (Priority: P1)

A new user asks their AI agent to help set up SkillSync. The agent loads `skillsync-setup` and walks through: `skillsync init`, choosing targets, creating a first skill, and optionally setting up git sync.

**Why this priority**: First-time setup is the highest-friction moment. A skill-guided experience makes it approachable without building a TUI.

**Independent Test**: Can be tested by having an agent follow the skill instructions on a machine with no existing SkillSync state, verifying the result is a working setup.

**Acceptance Scenarios**:

1. **Given** SkillSync is installed but not initialized, **When** a user asks their agent to set up SkillSync, **Then** the agent follows `skillsync-setup` to run `skillsync init`, add targets for detected agents, and create a sample skill.
2. **Given** the setup skill, **When** the user wants git sync, **Then** the skill guides the agent through `skillsync remote set` and `skillsync push`.

---

### User Story 3 - Seed Project Skill from Global (Priority: P2)

A developer asks their agent to "create a project version of my code-review skill." The updated `skillsync-new` skill guides the agent to: create a project skill scaffold with `skillsync new code-review --project`, read the global version's content, and copy it into the new project skill.

**Why this priority**: A convenience workflow that demonstrates skills composing with CLI primitives.

**Independent Test**: Can be tested by having an agent follow the skill instructions to seed a project skill, then verifying the project skill has the same content as the global original.

**Acceptance Scenarios**:

1. **Given** a global skill "code-review" exists, **When** the user asks to create a project version, **Then** the agent follows `skillsync-new` to scaffold the project skill and populate it from the global version.
2. **Given** the project skill was seeded, **When** user edits the project version, **Then** the global version is unaffected.

---

### User Story 4 - Helpful Deprecation Messages (Priority: P2)

A user who previously used `skillsync add` runs it out of habit. The CLI tells them the command has been replaced and how to achieve the same result.

**Why this priority**: Prevents confusion during the transition. Users need clear guidance.

**Independent Test**: Run each removed command and verify the deprecation message.

**Acceptance Scenarios**:

1. **Given** the `add` command has been removed, **When** user runs `skillsync add`, **Then** the CLI displays: the command has been replaced by the `skillsync-import` built-in skill, and how to use it (ask your agent to import a skill).
2. **Given** the `update` command has been removed, **When** user runs `skillsync update`, **Then** a similar deprecation message is shown.
3. **Given** the `export` command has been removed, **When** user runs `skillsync export`, **Then** a similar deprecation message is shown, suggesting `cp` as the alternative.

---

### Edge Cases

- What happens when `skillsync init` is run but the built-in skills fail to seed (e.g., disk full)? Init succeeds with a warning that built-in skills could not be installed. The store is functional without them.
- What happens when a built-in skill's instructions reference a CLI command that doesn't exist in the user's version? The skill should reference only stable CLI primitives and include version requirements.
- What happens when a user manually deletes a built-in skill? It stays deleted. `skillsync init` only seeds built-ins on first run, not on every run.

## Requirements *(mandatory)*

### Functional Requirements

#### CLI Removal

- **FR-001**: The `add` command (local and GitHub import) MUST be removed from the CLI.
- **FR-002**: The `update` command MUST be removed from the CLI.
- **FR-003**: The `export` command MUST be removed from the CLI.
- **FR-004**: When a user runs a removed command, the CLI MUST display a message explaining the replacement and how to use it.

#### New Built-in Skills

- **FR-005**: A `skillsync-import` built-in skill MUST be created with instructions for agents to import skills from: GitHub repositories, local file paths, and URLs.
- **FR-006**: The `skillsync-import` skill MUST instruct agents to use only CLI primitives (`skillsync new`, filesystem operations, `skillsync sync`) — no removed commands.
- **FR-007**: The `skillsync-import` skill MUST cover both global and project store imports.
- **FR-008**: A `skillsync-setup` built-in skill MUST be created that guides agents through first-time setup: init, target configuration, first skill creation, and optional git sync setup.
- **FR-009**: The `skillsync-setup` skill MUST detect which agents are installed and suggest appropriate targets.

#### Updated Built-in Skills

- **FR-010**: The `skillsync-new` built-in skill MUST be updated to guide project skill creation (using `--project` flag).
- **FR-011**: The `skillsync-new` skill MUST guide seeding project skills from global skills (read global version, copy content into project skill).
- **FR-012**: The `skillsync-check` and `skillsync-refine` skills MUST be updated to handle project-scoped skills (using `--project` flag for observe/log/info).

#### Built-in Skill Seeding

- **FR-013**: `skillsync init` MUST seed all built-in skills (including new ones) into the global store on first initialization.
- **FR-014**: Built-in skills MUST be marked with `source = "built-in"` in their `.meta.toml`.

### Key Entities

- **Built-in Skill**: A skill bundled with the binary, seeded into the store on `init`. Contains agent instructions for performing complex workflows using CLI primitives.
- **Deprecation Stub**: A minimal command that prints a migration message and exits with a non-zero code.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: An agent following `skillsync-import` instructions can successfully import a skill from a GitHub repo using only CLI primitives and filesystem operations.
- **SC-002**: An agent following `skillsync-setup` instructions can take a machine from zero to a working SkillSync setup (initialized store, configured targets, one skill synced).
- **SC-003**: The CLI has no more than 12 top-level commands: init, new, rm, ls, sync, observe, log, info, target, git, doctor, version (plus push/pull as subcommands of the top level).
- **SC-004**: Running any removed command produces a helpful deprecation message, not an unknown command error.
