import Foundation
import TOMLDecoder

public struct AgentRegistryEntry: Equatable, Sendable, Decodable {
    public var id: String
    public var displayName: String
    public var globalSkillsPath: String
    public var projectDirectory: String
    public var defaultLinkMode: String

    public init(
        id: String,
        displayName: String,
        globalSkillsPath: String,
        projectDirectory: String,
        defaultLinkMode: String
    ) {
        self.id = id
        self.displayName = displayName
        self.globalSkillsPath = globalSkillsPath
        self.projectDirectory = projectDirectory
        self.defaultLinkMode = defaultLinkMode
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display-name"
        case globalSkillsPath = "global-skills-path"
        case projectDirectory = "project-directory"
        case defaultLinkMode = "default-link-mode"
    }
}

// MARK: - Embedded registry

public extension AgentRegistryEntry {
    private struct RegistryFile: Decodable {
        var agents: [AgentRegistryEntry]
    }

    static let registry: [AgentRegistryEntry] = {
        let toml = """
        [[agents]]
        id = "claude-code"
        display-name = "Claude Code"
        global-skills-path = "~/.claude/skills"
        project-directory = ".claude"
        default-link-mode = "symlink"

        [[agents]]
        id = "codex"
        display-name = "Codex CLI"
        global-skills-path = "~/.codex/skills"
        project-directory = ".codex"
        default-link-mode = "symlink"

        [[agents]]
        id = "cursor"
        display-name = "Cursor"
        global-skills-path = "~/.cursor/skills"
        project-directory = ".cursor"
        default-link-mode = "hardlink"

        [[agents]]
        id = "gemini-cli"
        display-name = "Gemini CLI"
        global-skills-path = "~/.gemini/skills"
        project-directory = ".gemini"
        default-link-mode = "symlink"

        [[agents]]
        id = "copilot"
        display-name = "GitHub Copilot"
        global-skills-path = "~/.copilot/skills"
        project-directory = ".github"
        default-link-mode = "symlink"

        [[agents]]
        id = "windsurf"
        display-name = "Windsurf"
        global-skills-path = "~/.codeium/windsurf/skills"
        project-directory = ".windsurf"
        default-link-mode = "symlink"

        [[agents]]
        id = "amp"
        display-name = "Amp"
        global-skills-path = "~/.config/agents/skills"
        project-directory = ".agents"
        default-link-mode = "symlink"

        [[agents]]
        id = "cline"
        display-name = "Cline"
        global-skills-path = "~/.cline/skills"
        project-directory = ".cline"
        default-link-mode = "symlink"

        [[agents]]
        id = "opencode"
        display-name = "OpenCode"
        global-skills-path = "~/.config/opencode/skills"
        project-directory = ".opencode"
        default-link-mode = "symlink"
        """
        // Force-unwrap is safe: this is a compile-time-constant TOML string.
        // A decoding failure here is a programmer error that should crash immediately.
        return try! TOMLDecoder().decode(RegistryFile.self, from: toml).agents
    }()
}
