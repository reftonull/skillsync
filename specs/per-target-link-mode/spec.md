# Feature Specification: Per-Target Link Mode

**Created**: 2026-03-16
**Status**: Draft
**Order**: 2 of 6 (depends on: agent-registry)
**Input**: Allow each sync target to specify how skills are installed — symlink, hardlink, or copy — to handle agents that don't follow symlinks (notably Cursor).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Configure Link Mode for a Target (Priority: P1)

A developer discovers their Cursor installation doesn't follow symlinks for skill files. They reconfigure the Cursor target to use hardlinks, and on the next sync, skills appear as hardlinked files that Cursor can read.

**Why this priority**: Symlink-only sync is a known compatibility issue. Without per-target mode, SkillSync cannot reliably sync to all agents.

**Independent Test**: Can be tested by adding a target with `--mode hardlink`, syncing, and verifying the filesystem entry is a hardlink (same inode as rendered copy).

**Acceptance Scenarios**:

1. **Given** user runs `skillsync target add --tool cursor --mode hardlink`, **When** sync runs, **Then** skill entries in the Cursor target directory are hard links.
2. **Given** user runs `skillsync target add --tool claude-code` (no mode flag), **When** sync runs, **Then** skill entries are symlinks (the default).
3. **Given** user runs `skillsync target add --tool codex --mode copy`, **When** sync runs, **Then** skill entries are independent file copies.

---

### User Story 2 - Default Link Mode from Registry (Priority: P2)

The agent registry specifies that Cursor's default link mode is "hardlink." When a user adds Cursor as a target without specifying `--mode`, the registry default is used automatically.

**Why this priority**: Good defaults reduce configuration burden. Users shouldn't need to know which agents have symlink issues.

**Independent Test**: Can be tested by adding a Cursor target without `--mode` and verifying the target is configured with the registry's default link mode.

**Acceptance Scenarios**:

1. **Given** the registry specifies `default_link_mode = "hardlink"` for cursor, **When** user runs `skillsync target add --tool cursor`, **Then** the target is added with `mode = "hardlink"`.
2. **Given** user explicitly passes `--mode symlink` for cursor, **When** the target is added, **Then** the explicit mode overrides the registry default.

---

### Edge Cases

- What happens when hardlink creation fails due to cross-device link? Sync MUST fail for that target with a descriptive error. No silent fallback to copy.
- What happens when the mode field is missing from an existing target in config.toml? Defaults to "symlink" for backward compatibility.
- What happens when sync re-runs and the link mode has changed since last sync? Old entries MUST be removed and recreated with the new mode.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: `SyncTarget` MUST include a `mode` field with values: `symlink` (default), `hardlink`, `copy`.
- **FR-002**: `skillsync target add` MUST accept an optional `--mode <symlink|hardlink|copy>` flag.
- **FR-003**: When `--mode` is not specified, the mode MUST be set from the agent registry's default link mode for `--tool` targets, or `symlink` for `--path` targets.
- **FR-004**: `SyncRenderFeature` MUST use the target's configured mode when installing skills to the target directory.
- **FR-005**: Symlink mode MUST create a symbolic link pointing to the rendered copy (existing behavior).
- **FR-006**: Hardlink mode MUST create a hard link to the rendered copy's files. For directories, this means hardlinking individual files within the skill directory.
- **FR-007**: Copy mode MUST create an independent file copy of the rendered skill content.
- **FR-008**: If the requested link operation fails (e.g., cross-device hardlink), sync MUST fail for that target with a descriptive error message including the OS error.
- **FR-009**: `config.toml` serialization MUST include the `mode` field for each target.
- **FR-010**: Loading a `config.toml` with targets missing the `mode` field MUST default to `symlink`.
- **FR-011**: `skillsync target list` MUST display the configured mode for each target.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Per-target link mode correctly uses the configured filesystem primitive for every sync operation, verified by filesystem inspection (inode comparison for hardlinks, readlink for symlinks, independent inode for copies).
- **SC-002**: Existing sync tests pass without modification when targets use the default symlink mode.
- **SC-003**: A target configured with hardlink mode results in skill files readable by an agent that does not follow symlinks.
