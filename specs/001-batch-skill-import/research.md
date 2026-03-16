# Research: Batch Skill Import

## How does AddFeature currently detect a single skill?

**Decision**: `SKILL.md` presence at the root of the given path is the
signal. This remains the detection mechanism — if present, single-skill
import. If absent, batch mode scans immediate children.

**Rationale**: No ambiguity. The agentskills.io spec requires
`SKILL.md` at the root of every skill directory. A parent directory
will never have one.

**Alternatives considered**: A `--batch` flag was considered but
rejected — auto-detection is simpler and matches the spec's FR-006.

## How does GitHub sparse-checkout handle parent directories?

**Decision**: The existing sparse-checkout of a parent path already
fetches all files recursively. `collectFilesRecursive` returns a flat
`[String: Data]` dictionary with paths like `child-a/SKILL.md`. The
batch logic groups by first path component and imports each group.

**Rationale**: No changes needed to `GitHubSkillClient`. The fetch
already works for parent directories — only `AddFeature` needs to
interpret the result differently.

**Alternatives considered**: Multiple sparse-checkout calls (one per
child) were considered but are slower and require knowing child names
upfront, which defeats the purpose.

## How should the Result type change?

**Decision**: Replace the single-value `Result` with an array-based
result. Single imports return a one-element array.

**Rationale**: Keeps one code path. Callers already destructure the
result — adapting to `result.skills[0]` or iterating is minimal change.
The only caller is `AddCommand`.

**Alternatives considered**: Returning a union `enum { single(Result),
batch([Result]) }` was rejected as unnecessary complexity per
Constitution Principle IV.

## How should "already exists" be handled in batch mode?

**Decision**: "Already exists" becomes a skip status instead of a
thrown error. In single-skill mode, the feature still throws (backward
compatibility). In batch mode (>1 child detected), skips are collected
and reported.

**Rationale**: Throwing on the first duplicate in a batch of 10 skills
would be a terrible UX. Users expect best-effort with a report.

**Alternatives considered**: Always returning skip status (even for
single) was considered but would be a breaking change to existing
callers and test expectations. The distinction is: single-skill throws
on conflict (user targeted a specific skill), batch skips (user
targeted a collection).
