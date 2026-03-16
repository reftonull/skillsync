# Feature Specification: Batch Skill Import

**Feature Branch**: `more-than-just-skills`
**Created**: 2026-03-16
**Status**: Draft
**Input**: User description: "I want to support adding directories of skills, not just singular skills. This should work for a few different manners of skills"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Import a directory of pre-built skills from a local path (Priority: P1)

A user has run a third-party tool (e.g., spec-kit with `--ai-skills`)
that generated multiple skill directories inside a parent folder. Each
child directory contains a `SKILL.md` file. The user wants to import all
of them into SkillSync's canonical store in a single command instead of
running `skillsync add` once per skill.

**Why this priority**: This is the core value of the feature. Without
batch local import, users must repeat the same command N times, which is
tedious and error-prone — especially for agents scripting the workflow.

**Independent Test**: Can be fully tested by creating a temporary
directory with 3 child skill directories, running the batch add command,
and verifying all 3 appear in `~/.skillsync/skills/`.

**Acceptance Scenarios**:

1. **Given** a directory `/tmp/tools/.claude/skills/` containing child
   directories `speckit-specify/SKILL.md`, `speckit-plan/SKILL.md`, and
   `speckit-tasks/SKILL.md`, **When** the user runs
   `skillsync add /tmp/tools/.claude/skills/`, **Then** all three skills
   are imported into the canonical store with correct names, metadata,
   and content hashes.

2. **Given** the same parent directory but `speckit-plan` already exists
   in the canonical store, **When** the user runs the batch add command,
   **Then** `speckit-specify` and `speckit-tasks` are imported
   successfully and the output reports that `speckit-plan` was skipped
   because it already exists.

3. **Given** a parent directory where one child (`broken/`) has no
   `SKILL.md`, **When** the user runs the batch add command, **Then**
   valid children are imported and the output reports that `broken/` was
   skipped with a reason.

---

### User Story 2 - Import a directory of skills from a GitHub repository (Priority: P2)

A user wants to import multiple skills from a GitHub repository where
the skills are organized under a common parent directory (e.g.,
`skills/` containing `speckit-specify/SKILL.md`,
`speckit-plan/SKILL.md`, etc.). Instead of importing one skill at a
time, they point at the parent path and all children are imported.

**Why this priority**: Extends the batch concept to the existing GitHub
import flow. This is the most common distribution model — a repo
publishes a folder of skills.

**Independent Test**: Can be tested by pointing at a GitHub repo with a
known parent directory containing multiple skill subdirectories and
verifying all are imported.

**Acceptance Scenarios**:

1. **Given** a GitHub repository `owner/repo` with path `skills/`
   containing `skill-a/SKILL.md` and `skill-b/SKILL.md`, **When** the
   user runs `skillsync add github owner/repo skills/`, **Then** both
   skills are imported with upstream metadata tracking the repo, commit,
   and individual skill paths.

2. **Given** the same repo but `skill-a` already exists locally,
   **When** the user runs the batch GitHub add, **Then** `skill-b` is
   imported and `skill-a` is reported as skipped.

---

### User Story 3 - Disambiguate single skill vs. parent directory (Priority: P3)

A user points `skillsync add` at a path that is itself a valid skill
directory (contains `SKILL.md`) — this is the existing single-skill
behavior. The system MUST distinguish between "this is one skill" and
"this is a parent containing multiple skills" without requiring a
separate command or flag.

**Why this priority**: Ensures backward compatibility and a smooth UX.
Without clear disambiguation, users could accidentally import a parent
directory as a single skill or vice versa.

**Independent Test**: Can be tested by running `skillsync add` against
a single-skill directory and verifying only one skill is imported (no
behavioral change from today), then against a parent directory and
verifying batch behavior activates.

**Acceptance Scenarios**:

1. **Given** a directory `my-skill/` that contains `SKILL.md`, **When**
   the user runs `skillsync add my-skill/`, **Then** it is imported as
   a single skill (existing behavior, unchanged).

2. **Given** a directory `all-skills/` that does NOT contain `SKILL.md`
   but has children `a/SKILL.md` and `b/SKILL.md`, **When** the user
   runs `skillsync add all-skills/`, **Then** both `a` and `b` are
   imported as separate skills.

3. **Given** a directory `ambiguous/` that contains BOTH a `SKILL.md`
   and child directories with their own `SKILL.md` files, **When** the
   user runs `skillsync add ambiguous/`, **Then** it is imported as a
   single skill (the presence of `SKILL.md` at the root takes
   precedence, matching current behavior).

---

### Edge Cases

- What happens when the parent directory is empty (no children)?
  The system reports "no skills found" and exits with a non-zero status.
- What happens when all children already exist in the canonical store?
  The system reports each as skipped and exits successfully (idempotent).
- What happens when a child directory name conflicts with a reserved
  name or contains invalid characters? The system skips that child and
  reports the validation error.
- What happens with nested directories (skills inside skills inside a
  parent)? Only immediate children of the parent are considered — no
  recursive descent beyond one level.
- What happens when a GitHub parent path does not exist in the repo?
  The system reports "path not found" as it does today for single skills.
- What happens when a GitHub path has no `SKILL.md` at the root and no
  children with `SKILL.md`? The system reports "no skills found" with
  the path.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST accept a local directory path that
  contains multiple skill subdirectories and import each valid child
  as a separate skill.
- **FR-002**: The system MUST accept a GitHub repository path pointing
  to a parent directory and import each child skill subdirectory.
- **FR-003**: A child directory is considered a valid skill if and only
  if it contains a `SKILL.md` file.
- **FR-004**: The system MUST skip children that are not valid skill
  directories and report them in the output.
- **FR-005**: The system MUST skip children whose name matches an
  existing skill in the canonical store and report them as skipped.
- **FR-006**: The system MUST auto-detect whether a given path is a
  single skill (contains `SKILL.md`) or a parent of multiple skills
  (does not contain `SKILL.md` but has children that do).
- **FR-007**: Each imported skill MUST receive its own `.meta.toml`
  with the appropriate source type (`imported` for local,
  `github` for remote) and a computed content hash.
- **FR-008**: For GitHub batch imports, each skill's upstream metadata
  MUST record the individual skill path within the repository (e.g.,
  `skills/speckit-plan`), not the parent path (`skills/`).
- **FR-009**: The output MUST provide a per-skill summary: imported,
  skipped (already exists), or skipped (invalid), with a final count.
- **FR-010**: The system MUST NOT recurse beyond one level of depth
  below the specified parent directory.

### Key Entities

- **Parent Directory**: A directory containing zero or more child skill
  directories. Distinguished from a skill directory by the absence of
  a `SKILL.md` at its root.
- **Skill Directory**: A directory containing a `SKILL.md` file and
  optional companion files. The directory name becomes the skill name.
- **Import Result**: Per-skill outcome (imported, skipped-exists,
  skipped-invalid) aggregated into a batch summary.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can import 10+ skills from a single parent
  directory in one command invocation.
- **SC-002**: Existing single-skill `add` behavior is unchanged — no
  regressions for users who import individual skills.
- **SC-003**: 100% of imported skills are individually syncable via
  `skillsync sync` immediately after batch import.
- **SC-004**: Users receive clear per-skill feedback (imported vs.
  skipped with reason) for every child in the parent directory.
- **SC-005**: Agents can script batch import without parsing ambiguous
  output — the summary is structured and predictable.
