import Foundation

public struct BuiltInSkill: Equatable, Sendable {
  public var name: String
  public var files: [String: Data]

  public init(name: String, files: [String: Data]) {
    self.name = name
    self.files = files
  }
}

public extension BuiltInSkill {
  private static let embeddedSkills: [(name: String, content: String)] = [
    ("skillsync-new", skillNew),
    ("skillsync-check", skillCheck),
    ("skillsync-refine", skillRefine),
  ]

  static let seededNames = embeddedSkills.map(\.name)

  static func seeded() -> [BuiltInSkill] {
    embeddedSkills.map { name, content in
      BuiltInSkill(name: name, files: ["SKILL.md": Data(content.utf8)])
    }
  }

  // MARK: - Embedded skill content

  private static let skillNew = """
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
    - Do not create or modify `.meta.toml` \u{2014} it is managed by skillsync.
    - If `edit` reports the skill is already being edited, ask the user before using `--force`.
    """

  private static let skillCheck = """
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
    """

  private static let skillRefine = """
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
    """
}
