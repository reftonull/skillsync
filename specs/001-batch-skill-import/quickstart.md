# Quickstart: Batch Skill Import

## Local batch import

```bash
# A third-party tool generated skills in a directory:
ls /tmp/project/.claude/skills/
# speckit-specify/  speckit-plan/  speckit-tasks/

# Import all at once:
skillsync add /tmp/project/.claude/skills/

# Output:
# Imported speckit-specify
# Imported speckit-plan
# Imported speckit-tasks
#
# Imported 3 skills, skipped 0.
# Run `skillsync sync` to apply changes to configured targets.

skillsync sync
```

## GitHub batch import

```bash
# Import all skills from a repo's skills/ directory:
skillsync add github owner/repo skills/

# Output:
# Imported skill-a
# Imported skill-b
#
# Imported 2 skills, skipped 0.
# Run `skillsync sync` to apply changes to configured targets.
```

## Single skill still works

```bash
# This still works exactly as before:
skillsync add ./my-skill/
# Imported skill my-skill to /Users/x/.skillsync/skills/my-skill
```

## Verify

```bash
skillsync list
skillsync sync
```
