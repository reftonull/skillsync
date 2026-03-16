# Contract: AddFeature (batch-extended)

## Feature API

```swift
AddFeature().run(Input) throws -> Result
```

### Input (unchanged)

```swift
Input.Source
  .localPath(String)           // path to skill dir OR parent dir
  .github(GitHubSkillSource)   // repo path to skill dir OR parent dir
```

### Result (changed)

```swift
Result
  .skills: [SkillResult]       // 1 element for single, N for batch

SkillResult
  .status: Status
  .skillName: String
  .skillRoot: URL?
  .contentHash: String?

Status
  .imported(createdMeta: Bool)
  .skippedExists
  .skippedInvalid(reason: String)
```

### Errors thrown

| Error | When |
|-------|------|
| `sourcePathNotFound` | Path does not exist (local) |
| `sourcePathNotDirectory` | Path is a file, not directory (local) |
| `missingSkillMarkdown` | Single-skill mode: no SKILL.md |
| `skillAlreadyExists` | Single-skill mode: destination occupied |
| `noSkillsFound` | Batch mode: parent has zero valid children |
| `invalidGitHubSkillPath` | GitHub payload contains unsafe path |

### Detection rule

```
if SKILL.md exists at root of path:
  → single-skill import (throws on conflict)
else:
  → enumerate children, import each (skips on conflict)
  → throw noSkillsFound if zero children imported or skipped
```

## CLI Output

### Single skill (unchanged)
```
Imported skill review-assistant to /Users/x/.skillsync/skills/review-assistant
Run `skillsync sync` to apply changes to configured targets.
```

### Batch
```
Imported speckit-specify
Imported speckit-plan
Skipped speckit-tasks (already exists)
Skipped broken (no SKILL.md)

Imported 2 skills, skipped 2.
Run `skillsync sync` to apply changes to configured targets.
```
