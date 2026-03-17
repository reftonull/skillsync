# Feature Specification: Layered Stores (Global + Project)

**Created**: 2026-03-16
**Status**: Draft
**Order**: 3 of 6 (depends on: agent-registry, per-target-link-mode)
**Input**: Support two independent skill stores — a global store at `~/.skillsync/` synced across machines via git, and a project store at `./.skillsync/` committed to the project repo. Global skills sync to global targets; project skills sync to project targets. No cross-contamination.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Initialize and Use a Project Store (Priority: P1)

A developer working on a project initializes a project-local store with `skillsync init --project`. They create project-specific skills (architecture context, test runner instructions) that only sync to that project's agent directories. Their global skills remain separate and sync to global targets as usual.

**Why this priority**: This is the foundational change. Without it, all skills are global and there's no way to have project-specific skills or share project skills with teammates.

**Independent Test**: Can be tested by initializing a project store, creating a skill in it, syncing, and verifying the skill only appears in project-local agent directories.

**Acceptance Scenarios**:

1. **Given** a project root with `.git/`, **When** user runs `skillsync init --project`, **Then** a `.skillsync/` directory is created at the project root with `skills/` subdirectory and `config.toml`.
2. **Given** an initialized project store, **When** user runs `skillsync new run-tests --project`, **Then** the skill is created at `./.skillsync/skills/run-tests/`.
3. **Given** a project store with skill "run-tests", **When** user runs `skillsync sync` from within the project, **Then** "run-tests" appears in `.claude/skills/`, `.codex/skills/`, etc. (project-local agent dirs) but NOT in `~/.claude/skills/` (global).
4. **Given** a global store with skill "code-style" and a project store with skill "run-tests", **When** user runs `skillsync sync` from within the project, **Then** "code-style" syncs to global targets and "run-tests" syncs to project targets.

---

### User Story 2 - Global-Only Sync Outside Projects (Priority: P1)

A developer runs `skillsync sync` from their home directory (outside any project). Only the global store syncs to global targets. No errors about missing project stores.

**Why this priority**: The common case — syncing personal skills — must work without project context.

**Independent Test**: Run sync outside any project and verify only global targets are affected.

**Acceptance Scenarios**:

1. **Given** an initialized global store and no project store in scope, **When** user runs `skillsync sync`, **Then** only global skills sync to global targets. No error or warning about missing project store.
2. **Given** an initialized global store, **When** user runs `skillsync ls` outside any project, **Then** only global skills are listed (no `[project]` section).

---

### User Story 3 - Project Target Auto-Detection (Priority: P1)

When syncing project skills, SkillSync automatically detects which agents have directories at the project root and syncs to their skills subdirectories. No manual `target add --project` needed.

**Why this priority**: Manual per-project target configuration is friction. Auto-detection from the agent registry makes project stores zero-config.

**Independent Test**: Create a project with `.claude/` and `.codex/` directories, init a project store, create a skill, sync, and verify skills appear in both agent dirs.

**Acceptance Scenarios**:

1. **Given** a project with `.claude/` and `.codex/` directories, **When** `skillsync sync` runs, **Then** project skills are synced to `.claude/skills/` and `.codex/skills/` automatically.
2. **Given** a project with only `.claude/`, **When** `skillsync sync` runs, **Then** project skills sync only to `.claude/skills/`. No error about missing `.codex/`.
3. **Given** a project with no agent directories, **When** `skillsync sync` runs, **Then** project skills are not synced (no targets) and a warning is emitted suggesting creating an agent directory or using `target add`.

---

### User Story 4 - Unified Listing (Priority: P2)

A developer runs `skillsync ls` from within a project and sees both their global and project skills, clearly labeled.

**Why this priority**: Visibility into what's available across both scopes prevents confusion and duplicated effort.

**Independent Test**: Create skills in both stores, run `ls` from within the project, verify both are shown with labels.

**Acceptance Scenarios**:

1. **Given** global skill "code-style" and project skill "run-tests", **When** user runs `skillsync ls` from within the project, **Then** output shows both skills with `[global]` and `[project]` labels.
2. **Given** the same setup, **When** user runs `skillsync ls` from outside the project, **Then** only "code-style" is shown with `[global]` label.
3. **Given** a global skill and project skill with the same name "code-review", **When** user runs `skillsync ls`, **Then** both are listed — one as `[global]` and one as `[project]`.

---

### User Story 5 - Project Skills as Team-Shared (Priority: P2)

A team commits their project's `.skillsync/` directory to the repo. When a teammate clones the project and runs `skillsync sync`, the project skills are synced to their local agent directories without any additional setup.

**Why this priority**: Team-shared project skills are a natural extension. The project store being a regular directory in the repo makes this work with no special tooling.

**Independent Test**: Clone a repo containing `.skillsync/skills/`, run sync, verify skills appear in project agent dirs.

**Acceptance Scenarios**:

1. **Given** a cloned repo with `.skillsync/skills/run-tests/`, **When** a teammate runs `skillsync sync` from within the project, **Then** "run-tests" is synced to the project's agent directories.
2. **Given** the teammate has never run `skillsync init --project`, **When** they run `skillsync sync`, **Then** the existing `.skillsync/` is detected and used. No initialization required.

---

### Edge Cases

- What happens when `skillsync init --project` is run outside a detectable project root? Error with a clear message.
- What happens when both global and project stores have a skill with the same name? Both sync to their respective targets. No collision resolution by SkillSync.
- What happens when a project store exists but has no skills? Project targets are synced (empty — stale symlinks pruned). No error.
- What happens when `skillsync rm run-tests --project` is run outside a project? Error: no project store in scope.
- What happens when `skillsync observe` is run for a project skill? Observations are logged in the project store's `logs/` directory, not the global store.
- What happens when `skillsync info` is run for a skill name that exists in both stores? The CLI MUST require `--project` or default to global, and display which store is being queried.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: `skillsync init --project` MUST create a `.skillsync/` directory at the detected project root with `skills/` subdirectory and a minimal `config.toml`.
- **FR-002**: `skillsync init` (no flag) MUST continue to initialize the global store at `~/.skillsync/`.
- **FR-003**: `skillsync new <name> --project` MUST create the skill in the project store.
- **FR-004**: `skillsync new <name>` (no flag) MUST create in the global store.
- **FR-005**: `skillsync rm <name> --project` MUST operate on the project store.
- **FR-006**: `skillsync ls` MUST display skills from both stores when a project store is in scope, with `[global]` and `[project]` labels.
- **FR-007**: `skillsync sync` MUST sync global skills to global targets (from `config.toml` targets with source=tool or source=path).
- **FR-008**: `skillsync sync` MUST sync project skills to auto-detected project targets when a project store is in scope.
- **FR-009**: Project targets MUST be auto-detected by scanning the project root for known agent directories from the registry.
- **FR-010**: Global skills MUST NOT be synced to project targets. Project skills MUST NOT be synced to global targets.
- **FR-011**: Each store MUST have independent `logs/` directories for observation data.
- **FR-012**: `skillsync observe`, `skillsync log`, and `skillsync info` MUST accept `--project` to operate on the project store.
- **FR-013**: When a skill name exists in both stores and no `--project` flag is given, commands MUST default to the global store.
- **FR-014**: `skillsync push` and `skillsync pull` MUST operate only on the global store. Project store syncing is handled by the project's own git workflow.
- **FR-015**: Detecting a project store MUST work by walking upward from the current directory to find `.skillsync/` at a project root (same heuristic as current project root detection).

### Key Entities

- **Global Store**: `~/.skillsync/` — personal skills, git-synced across machines, targets configured in its `config.toml`.
- **Project Store**: `./.skillsync/` (at project root) — project-specific skills, committed to the repo, targets auto-detected from agent directories at project root.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Skills in the global store sync only to global targets. Skills in the project store sync only to project targets. No cross-contamination under any ordering of operations.
- **SC-002**: A teammate cloning a repo with `.skillsync/` can run `skillsync sync` and have project skills distributed to their agent directories with no additional setup beyond having SkillSync installed.
- **SC-003**: `skillsync ls` within a project shows skills from both stores with clear scope labels.
- **SC-004**: All existing global-only tests continue to pass. The layered store is additive — no regression in global-only behavior.
