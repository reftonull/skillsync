# Research: Data-Driven Agent Registry

## Decision 1: Registry Data Format

**Decision**: TOML, decoded via `dduan/TOMLDecoder` (0.4.3+).

**Rationale**: The project already uses TOML for `config.toml` and `.meta.toml` with a fragile hand-rolled parser. Adding `TOMLDecoder` (Swift 6.0, zero deps, zero data race errors, TOML 1.1.0, confirmed Linux support) gives proper Decodable-based parsing for the registry AND replaces the hand-rolled parsers in `LoadSyncConfigFeature` and `UpdateMetaFeature.read`. One dependency addition solves two problems.

**Alternatives considered**:
- JSON via Foundation: Works but introduces a second config format into the project. TOML is already the project's config language.
- Swift array literal: Violates FR-001 ("not hardcoded in Swift source").
- Hand-rolled TOML parser: Already proven fragile. Adding more formats to it would compound the problem.
- mattt/swift-toml: Read+write support, but very new (24 stars, Dec 2025). TOMLDecoder is more battle-tested.

## Decision 2: Bundling Strategy

**Decision**: Static TOML string embedded in Swift source, decoded at startup via `TOMLDecoder`. Same pattern as `BuiltInSkill.swift` (string literals in Swift), but now properly parsed instead of hand-rolled.

**Rationale**: The codebase previously used SPM `.copy()` resources with `Bundle.module` for built-in skills and hit significant problems (see commits `c87e560` → `b23fe9b`). The approach was abandoned entirely — built-in skills are now Swift string literals. The registry follows the same proven pattern: a static TOML string in a `.swift` file, decoded via `TOMLDecoder` into `[AgentRegistryEntry]`. Adding a new agent means adding one TOML entry to the string.

**Alternatives considered**:
- SPM `.process("Resources")` + `Bundle.module`: Previously tried and abandoned due to bundling issues.
- SPM `.embedInCode()`: Intermediate approach also abandoned.
- Runtime-loaded file at `~/.skillsync/agents.toml`: Makes the registry user-editable, but complicates distribution and versioning. The registry is tool-authored, not user-authored.

## Decision 3: Dependency Injection

**Decision**: Introduce an `AgentRegistryClient` dependency (following the swift-dependencies pattern). Live implementation decodes the embedded TOML string via `TOMLDecoder`. Test implementation returns a fixed set.

**Rationale**: Constitution Principle III requires DI for testability. Wrapping the registry in a client allows tests to control exactly which agents exist without depending on the full registry. This is consistent with how `BuiltInSkillsClient` wraps the static `BuiltInSkill.seeded()` array.

**Alternatives considered**:
- Static method on `AgentRegistry`: Violates Principle III (not injectable, tests would depend on the real JSON file).
- Pass registry as a parameter to features: Would change the signature of `TargetAddFeature.run()` and all callers. Over-coupled.

## Decision 4: Fallback Behavior

**Decision**: No fallback needed. The registry is a static array compiled into the binary — it cannot fail to load. FR-007 (fallback on load failure) is satisfied trivially.

**Rationale**: Since the registry is not loaded from an external file, there's no failure mode to handle. The "data file" is the Swift source itself, always present.

## Decision 5: Agent Paths (Verified)

Research confirmed exact paths for 9 agents that support SKILL.md:

| Agent | Global Skills Path | Project Dir | Default Link Mode | Notes |
|---|---|---|---|---|
| claude-code | `~/.claude/skills` | `.claude` | symlink | Confirmed |
| codex | `~/.codex/skills` | `.codex` | symlink | Confirmed |
| cursor | `~/.cursor/skills` | `.cursor` | hardlink | Does not follow symlinks |
| gemini-cli | `~/.gemini/skills` | `.gemini` | symlink | Confirmed symlink support |
| copilot | `~/.copilot/skills` | `.github` | symlink | Unconfirmed symlink behavior |
| windsurf | `~/.codeium/windsurf/skills` | `.windsurf` | symlink | Unconfirmed symlink behavior |
| amp | `~/.config/agents/skills` | `.agents` | symlink | Likely symlink support |
| cline | `~/.cline/skills` | `.cline` | symlink | Unconfirmed symlink behavior |
| opencode | `~/.config/opencode/skills` | `.opencode` | symlink | Unconfirmed symlink behavior |

**Aider excluded**: Does not support SKILL.md natively. Uses `CONVENTIONS.md` via CLI flag. A third-party bridge exists but it's not built-in. Can be added later if native support lands.

**Note on Cursor**: dot-agents project confirmed Cursor does not follow symlinks. Default link mode should be `hardlink`. This aligns with the per-target-link-mode spec (order 2).

## Decision 6: Link Mode in Registry vs. Per-Target-Link-Mode Spec

**Decision**: The registry includes `defaultLinkMode` as a string field now, but the actual link mode logic (symlink/hardlink/copy installation) is deferred to the per-target-link-mode spec (order 2). For this spec, the field is stored but only used as a default value when adding a target. The sync engine continues to use symlinks until spec 2 is implemented.

**Rationale**: This avoids blocking the registry work on the link mode implementation. The field is forward-compatible — it's written to `config.toml` and will be consumed by the updated sync engine later.
