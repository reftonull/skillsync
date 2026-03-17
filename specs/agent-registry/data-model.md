# Data Model: Agent Registry

## Entities

### AgentRegistryEntry

A single agent definition in the registry.

| Field | Type | Required | Description |
|---|---|---|---|
| id | String | Yes | Unique identifier (e.g., "claude-code", "gemini-cli") |
| displayName | String | Yes | Human-readable name (e.g., "Claude Code", "Gemini CLI") |
| globalSkillsPath | String | Yes | Path to global skills directory, with `~` for home (e.g., "~/.claude/skills") |
| projectDirectory | String | Yes | Name of the project-level agent directory (e.g., ".claude", ".gemini") |
| defaultLinkMode | String | Yes | Default link mode: "symlink", "hardlink", or "copy" |

**Validation rules**:
- `id` must be non-empty and unique across entries
- `globalSkillsPath` must contain `~` or be an absolute path
- `projectDirectory` must start with `.`
- `defaultLinkMode` must be one of: "symlink", "hardlink", "copy"

### AgentRegistry

An ordered collection of `AgentRegistryEntry` values.

**Operations**:
- `entry(for id: String) -> AgentRegistryEntry?` — lookup by identifier
- `allEntries() -> [AgentRegistryEntry]` — all entries in registry order
- `allIdentifiers() -> [String]` — all identifiers, sorted

## Source Representation

File: `Sources/SkillSyncCore/Models/AgentRegistryEntry.swift`

The registry is a static TOML string decoded via `TOMLDecoder`, following the same embedding pattern as `BuiltInSkill.swift`:

```swift
public extension AgentRegistryEntry {
  static let registry: [AgentRegistryEntry] = {
    let toml = """
    [[agents]]
    id = "claude-code"
    display-name = "Claude Code"
    global-skills-path = "~/.claude/skills"
    project-directory = ".claude"
    default-link-mode = "symlink"

    [[agents]]
    id = "cursor"
    display-name = "Cursor"
    global-skills-path = "~/.cursor/skills"
    project-directory = ".cursor"
    default-link-mode = "hardlink"
    # ...
    """
    struct Wrapper: Decodable { var agents: [AgentRegistryEntry] }
    return try! TOMLDecoder().decode(Wrapper.self, from: toml).agents
  }()
}
```

No SPM resources, no `Bundle.module`. Adding a new agent = adding one TOML entry to the string.

## Relationships

- `TargetAddFeature` consumes `AgentRegistryClient` to look up paths and default link modes when adding `--tool` targets.
- `TargetAddFeature` (project mode) consumes `AgentRegistryClient` to iterate project directory names for auto-detection.
- `SyncTarget` gains a `mode` field (from per-target-link-mode spec) whose default is populated from the registry entry.

## State Transitions

None. The registry is read-only at runtime. Changes happen by editing the TOML string in `AgentRegistryEntry.swift` and rebuilding.
