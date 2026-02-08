---
name: skillsync-new
description: Create a new reusable skill from a workflow, pattern, or capability.
metadata:
  short-description: Create a new skill
---

# Create a New Skill

## Goal

Create a new skill when the user asks you to save a workflow, pattern, or capability
as something reusable across sessions.

## How to create a skill

1. Choose a short, kebab-case name (e.g. `pdf-extract`, `api-auth`, `debug-memory`).

2. Create the skeleton and open it for editing:

   ```bash
   skillsync new <name> --description "<one-line summary>"
   skillsync edit <name>
   ```

   The `edit` command prints the editing path. All file writes go there.

3. Write `SKILL.md` at the editing path. This is the file future agents read when
   the skill is invoked. Write it as clear instructions, not documentation.

4. Add any supporting files (scripts, templates, configs) alongside `SKILL.md` if needed.

5. Review and commit:

   ```bash
   skillsync diff <name>
   skillsync commit <name> --reason "Initial skill draft"
   skillsync sync
   ```

## Important

- `SKILL.md` is the entry point. Without it, the skill is empty.
- Do not modify files outside the editing path.
- Do not create or modify `.meta.toml` — it is managed by skillsync.
- If `edit` reports the skill is already being edited, ask the user before using `--force`.
