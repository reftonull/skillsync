# Core Redesign — Spec Index

Ordered by dependency. Each spec can be planned and implemented independently,
provided its dependencies are complete.

| Order | Spec | Depends On | Summary |
|-------|------|------------|---------|
| 1 | [agent-registry](../agent-registry/spec.md) | — | Data-driven agent registry replacing hardcoded KnownTools |
| 2 | [per-target-link-mode](../per-target-link-mode/spec.md) | agent-registry | Symlink, hardlink, or copy per target |
| 3 | [layered-stores](../layered-stores/spec.md) | agent-registry, per-target-link-mode | Global + project skill stores |
| 4 | [git-workflow](../git-workflow/spec.md) | — (parallel with 3) | Git passthrough and auto-commit |
| 5 | [builtin-skills-cli-reduction](../builtin-skills-cli-reduction/spec.md) | layered-stores | Replace add/update/export with built-in skills |
| 6 | [sync-diagnostics](../sync-diagnostics/spec.md) | layered-stores, per-target-link-mode | Doctor command and sync dry-run |

**Future (not yet specced):** EVAL.md format, structured observation, skill testing.
