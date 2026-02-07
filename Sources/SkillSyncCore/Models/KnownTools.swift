import Foundation

public enum KnownTools {
  public static let defaultPaths: [String: String] = [
    "claude-code": "~/.claude/skills",
    "codex": "~/.codex/skills",
    "cursor": "~/.cursor/skills",
  ]

  public static let projectDirectories: [String: String] = [
    "claude-code": ".claude",
    "codex": ".codex",
    "cursor": ".cursor",
  ]
}
