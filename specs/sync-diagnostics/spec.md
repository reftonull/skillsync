# Feature Specification: Sync Diagnostics

**Created**: 2026-03-16
**Status**: Draft
**Order**: 6 of 6 (depends on: layered-stores, per-target-link-mode)
**Input**: Add a `skillsync doctor` command for self-healing diagnostics and a `skillsync sync --dry-run` mode for previewing sync changes without modifying the filesystem.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Diagnose Broken Sync State (Priority: P1)

A developer's agent can't find a skill that should be synced. They run `skillsync doctor` which finds a broken symlink in the Claude Code target (the rendered copy was accidentally deleted) and reports it with a suggested fix.

**Why this priority**: Symlinks break. Without diagnostics, users must manually inspect the filesystem to find the problem.

**Independent Test**: Intentionally break a symlink, run doctor, verify it's detected and reported.

**Acceptance Scenarios**:

1. **Given** a target with a broken symlink (rendered copy deleted), **When** user runs `skillsync doctor`, **Then** the output reports the broken link with the target name, skill name, and file path, and suggests `skillsync sync` to repair.
2. **Given** a target directory that no longer exists, **When** user runs `skillsync doctor`, **Then** the output reports the missing directory and suggests removing the target with `skillsync target remove`.
3. **Given** a rendered copy whose content hash doesn't match the canonical skill, **When** user runs `skillsync doctor`, **Then** the output reports the stale rendered copy and suggests `skillsync sync` to refresh.
4. **Given** an orphaned rendered directory (skill was removed but rendered copy remains), **When** user runs `skillsync doctor`, **Then** the output reports the orphan and suggests `skillsync sync` to prune.
5. **Given** everything is in sync, **When** user runs `skillsync doctor`, **Then** the output confirms all targets are healthy with a summary (e.g., "3 targets, 12 skills, all healthy").
6. **Given** multiple issues exist, **When** user runs `skillsync doctor`, **Then** ALL issues are reported, not just the first one.

---

### User Story 2 - Preview Sync Changes (Priority: P1)

Before syncing, a developer runs `skillsync sync --dry-run` to see what would happen. The output lists each skill that would be added, removed, or updated at each target — without touching the filesystem.

**Why this priority**: Prevents surprises, especially when syncing to project targets for the first time or after adding/removing skills.

**Independent Test**: Run dry-run, then run actual sync, and verify the dry-run output matches what actually happened.

**Acceptance Scenarios**:

1. **Given** a new skill "pdf" was created but not yet synced, **When** user runs `skillsync sync --dry-run`, **Then** the output shows "pdf" would be added to each configured target.
2. **Given** a skill "old-skill" was removed (pending_remove), **When** user runs `skillsync sync --dry-run`, **Then** the output shows "old-skill" would be pruned from each target.
3. **Given** a skill's content changed since last sync (hash mismatch), **When** user runs `skillsync sync --dry-run`, **Then** the output shows the skill would be updated at each target.
4. **Given** everything is in sync, **When** user runs `skillsync sync --dry-run`, **Then** the output confirms "no changes needed."
5. **Given** dry-run output shows changes, **When** user subsequently runs `skillsync sync` (without `--dry-run`), **Then** the actual changes match the dry-run output.

---

### Edge Cases

- What happens when `skillsync doctor` is run but no targets are configured? Reports "no targets configured" and suggests `skillsync target add`.
- What happens when `skillsync doctor` encounters a permission error reading a target? Reports the permission error for that target and continues checking others.
- What happens when `skillsync sync --dry-run` is run with both global and project stores? Shows changes for both scopes, clearly labeled.
- What happens when the rendered directory doesn't exist yet (first sync)? Dry-run shows all skills as "would be added."

## Requirements *(mandatory)*

### Functional Requirements

#### Doctor Command

- **FR-001**: `skillsync doctor` MUST check all configured targets for broken symlinks, broken hardlinks, and missing target directories.
- **FR-002**: `skillsync doctor` MUST check rendered directories for stale copies (content hash mismatch with canonical store).
- **FR-003**: `skillsync doctor` MUST check for orphaned rendered directories (skill no longer exists in canonical store).
- **FR-004**: `skillsync doctor` MUST report ALL findings, not stop at the first error.
- **FR-005**: Each finding MUST include: severity (error/warning), location (target + skill), description, and suggested action.
- **FR-006**: `skillsync doctor` MUST exit with code 0 if healthy, non-zero if any errors found.
- **FR-007**: `skillsync doctor` MUST check both global and project stores when a project store is in scope.

#### Dry Run

- **FR-008**: `skillsync sync --dry-run` MUST compute all changes (adds, removes, updates) without modifying the filesystem.
- **FR-009**: Dry-run output MUST list each change with: action (add/remove/update), skill name, target id, and link mode.
- **FR-010**: Dry-run output MUST clearly separate global and project scope changes when both are in scope.
- **FR-011**: `skillsync sync --dry-run` MUST exit with code 0 regardless of what changes would be made.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: `skillsync doctor` detects and reports 100% of broken symlinks, missing target directories, stale rendered copies, and orphaned directories in a test scenario with intentionally degraded state.
- **SC-002**: `skillsync sync --dry-run` output matches the actual changes performed by a subsequent `skillsync sync` for the same state.
- **SC-003**: `skillsync doctor` completes in under 5 seconds for a store with 50 skills and 5 targets.
