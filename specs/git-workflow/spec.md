# Feature Specification: Git Passthrough & Auto-Commit

**Created**: 2026-03-16
**Status**: Draft
**Order**: 4 of 6 (no hard dependencies; can be built in parallel with layered-stores)
**Input**: Add a `skillsync git` passthrough command for arbitrary git operations on the global store, and an opt-in auto-commit feature that stages and commits changes automatically before sync.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Git Passthrough (Priority: P1)

A developer wants to check the git log of their skill store without navigating to `~/.skillsync/`. They run `skillsync git -- log --oneline -10` and see recent commits.

**Why this priority**: Reduces friction for cross-machine sync. Users shouldn't need to remember where the store lives to run git commands on it.

**Independent Test**: Can be tested by running `skillsync git -- status` and verifying the output matches `cd ~/.skillsync && git status`.

**Acceptance Scenarios**:

1. **Given** an initialized global store with a git repo, **When** user runs `skillsync git -- status`, **Then** the output shows the git status of `~/.skillsync/`.
2. **Given** an initialized global store with a git repo, **When** user runs `skillsync git -- log --oneline -5`, **Then** the output shows recent commits.
3. **Given** an initialized global store with a git repo, **When** user runs `skillsync git -- diff`, **Then** the output shows unstaged changes in the store.
4. **Given** a global store without a git repo, **When** user runs `skillsync git -- status`, **Then** an error directs the user to run `skillsync remote set`.

---

### User Story 2 - Auto-Commit on Sync (Priority: P2)

A developer enables auto-commit so they don't have to manually commit skill edits. When they run `skillsync sync`, any uncommitted changes in the global store are automatically staged and committed before sync proceeds. They just need to `skillsync push` periodically.

**Why this priority**: Cross-machine sync requires commits. Forgetting to commit before pushing is a common friction point.

**Independent Test**: Enable auto-commit, edit a skill, run sync, verify a commit was created.

**Acceptance Scenarios**:

1. **Given** `auto-commit = true` in config.toml `[git]` section, **When** user edits a skill and runs `skillsync sync`, **Then** changes are staged (`git add -A`), committed with message `skillsync: update skills`, and sync proceeds.
2. **Given** `auto-commit = true` and no uncommitted changes, **When** user runs `skillsync sync`, **Then** no commit is created. Sync proceeds normally.
3. **Given** `auto-commit = false` (the default), **When** user edits a skill and runs `skillsync sync`, **Then** no git operations occur. Sync proceeds with whatever state exists.
4. **Given** `auto-commit = true` but the global store has no git repo, **When** user runs `skillsync sync`, **Then** sync proceeds normally. No error — auto-commit is silently skipped.

---

### Edge Cases

- What happens when `skillsync git` is passed no arguments after `--`? Runs `git` with no args (shows git help). Not an error.
- What happens when `skillsync git -- push` is run? It works — passthrough doesn't restrict which git commands are allowed. Users can use this instead of `skillsync push` if they prefer.
- What happens when auto-commit creates a commit but `push` is not run? The commit stays local. This is expected — auto-push is intentionally not included.
- What happens when `[git]` section is missing from config.toml? All git config defaults apply (`auto-commit = false`).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: `skillsync git -- <args>` MUST execute `git <args>` with the working directory set to the global store root (`~/.skillsync/`).
- **FR-002**: All arguments after `--` MUST be forwarded to git without modification.
- **FR-003**: The git command's stdout and stderr MUST be passed through to the user's terminal.
- **FR-004**: The exit code from git MUST be propagated as the skillsync exit code.
- **FR-005**: If the global store has no git repo, `skillsync git` MUST fail with an error directing the user to `skillsync remote set`.
- **FR-006**: `config.toml` MUST support a `[git]` section with an `auto-commit` boolean key (default: `false`).
- **FR-007**: When `auto-commit = true`, `skillsync sync` MUST stage all changes (`git add -A`) and commit before proceeding with sync.
- **FR-008**: Auto-commit MUST NOT create empty commits when there are no changes.
- **FR-009**: Auto-commit messages MUST follow the format `skillsync: update skills`.
- **FR-010**: Auto-commit MUST be silently skipped if the global store has no git repo.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: `skillsync git -- <any-git-command>` produces identical output to running the same git command from within `~/.skillsync/`.
- **SC-002**: With auto-commit enabled, a skill edit followed by `skillsync sync` followed by `skillsync push` results in the edit being available on a second machine after `skillsync pull`.
- **SC-003**: With auto-commit disabled (default), `skillsync sync` performs zero git operations.
