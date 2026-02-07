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
skillsync info <name>
skillsync log <name> --summary
```

`info` shows the skill's version, state, and observation counters.
`log --summary` shows a one-line performance summary: total invocations, positive/negative counts, and negative rate as a percentage.

## What to tell the user

If the summary is `0 invocations`, there is not enough data to judge performance yet.

If the negative rate is high (roughly 30%+ with at least a few invocations), mention it:

> "<name> has been struggling — <summary line>. Want me to try refining it?"

If performance looks fine, no action needed.

## Important

- This is read-only. Do not edit or refine the skill without the user's explicit approval.
- If the user wants to refine, consult `skillsync-refine`.
