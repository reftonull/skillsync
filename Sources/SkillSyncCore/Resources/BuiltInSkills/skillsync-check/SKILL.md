---
name: skillsync-check
description: Check a skill's performance from observation history and surface issues to the user.
metadata:
  short-description: Check skill performance
---

# Check Skill Performance

## Goal

Check how a skill is performing and let the user know if it may need refinement.

## How to check a skill

```bash
skillsync info <name> --json
skillsync log <name> --summary --json
```

Parse the JSON output to inspect:

- `totalInvocations`
- `positive`
- `negative`

Use those fields to judge current performance.

## What to tell the user

If `totalInvocations` is `0`, there is not enough data to judge performance yet.

If the negative rate is high (roughly 30%+ with at least a few invocations), mention it:

> "<name> has been struggling (<negative>/<total> negative). Want me to try refining it?"

If performance looks fine, no action needed.

## Important

- This is read-only. Do not edit or refine the skill without the user's explicit approval.
- If the user wants to refine, consult `skillsync-refine`.
