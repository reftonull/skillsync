# Data Model: Batch Skill Import

## Modified Types

### AddFeature.Result (modified)

Current:
```
Result
  skillName: String
  skillRoot: URL
  createdMeta: Bool
  contentHash: String
```

New:
```
Result
  skills: [SkillResult]

SkillResult
  status: Status
  skillName: String
  skillRoot: URL?          -- nil when skipped
  contentHash: String?     -- nil when skipped

Status
  imported(createdMeta: Bool)
  skippedExists
  skippedInvalid(reason: String)
```

### AddFeature.Error (modified)

Added:
```
noSkillsFound(String)  -- parent directory had zero valid children
```

Removed from throwing path (batch only):
```
skillAlreadyExists  -- becomes SkillResult.Status.skippedExists
missingSkillMarkdown -- becomes SkillResult.Status.skippedInvalid
```

These errors are still thrown in single-skill mode for backward
compatibility.

## Unchanged Types

- `AddFeature.Input` — no changes. The existing `localPath(String)`
  and `github(GitHubSkillSource)` sources already accept any path.
- `GitHubSkillClient.FetchResult` — no changes. Already returns all
  files recursively.
- `GitHubSkillSource` — no changes. `skillPath` can be a parent.
- `.meta.toml` schema — no changes. Each imported skill gets its own
  metadata as before.

## File Layout After Batch Import

Given `skillsync add /path/to/parent/`:

```
~/.skillsync/skills/
├── child-a/
│   ├── SKILL.md
│   ├── scripts/run.sh
│   └── .meta.toml          (source = "imported")
├── child-b/
│   ├── SKILL.md
│   └── .meta.toml          (source = "imported")
```

Given `skillsync add github owner/repo parent/`:

```
~/.skillsync/skills/
├── child-a/
│   ├── SKILL.md
│   └── .meta.toml          (source = "github", skill-path = "parent/child-a")
├── child-b/
│   ├── SKILL.md
│   └── .meta.toml          (source = "github", skill-path = "parent/child-b")
```
