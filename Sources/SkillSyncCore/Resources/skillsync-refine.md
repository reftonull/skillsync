---
name: skillsync-refine
description: Refine an underperforming skill using observation history. Requires user approval.
metadata:
  short-description: Refine a skill
---

# Refine a Skill

## Goal

Improve a skill that has been underperforming, based on observation history.
Only proceed after the user has explicitly approved refinement.

## How to refine a skill

1. Read the full observation history to understand what's failing:

   ```bash
   skillsync log <name> --json
   ```

   Parse structured records (`timestamp`, `signal`, `note`) and focus on negative observations and their notes to identify failure patterns.

2. Open the skill for editing:

   ```bash
   skillsync edit <name>
   ```

   If the skill is already being edited, ask the user before forcing: `skillsync edit <name> --force`.

3. Read the current `SKILL.md` from the editing path (printed by `edit`).

4. Make targeted fixes based on the failure patterns. Prefer small, specific changes
   over full rewrites.

5. Show the diff to the user before committing:

   ```bash
   skillsync diff <name>
   ```

6. Once the user approves, commit and sync:

   ```bash
   skillsync commit <name> --reason "Address frequent failure pattern from observations"
   skillsync sync
   ```

## How to abort

If the user changes their mind or the changes aren't right, discard the editing copy:

```bash
skillsync abort <name>
```

This leaves the canonical skill untouched.

## Important

- Never refine without user consent.
- Do not modify `.meta.toml`.
- Always show the diff before committing.
