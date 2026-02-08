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
    description: Create or update a reusable skill from a workflow, pattern, or capability. Use when the user asks to save repeatable instructions for future sessions.
    compatibility: Requires skillsync CLI and local filesystem access to ~/.skillsync.
    metadata:
      short-description: Create a new skill
    ---

    # Create a New Skill

    Create skills that are concise, reusable, and easy for another agent to execute.

    ## Workflow

    1. Clarify intent with one concrete example of the task the skill should handle.
    2. Pick a short kebab-case name (for example: `pdf-extract`, `api-auth`, `debug-memory`).
    3. Create the skeleton:
       ```bash
       skillsync new <name> --description "<what it does and when to use it>"
       ```
    4. Read the canonical path from:
       ```bash
       skillsync info <name> --json
       ```
       Use `path` from JSON.
    5. Edit `<path>/SKILL.md`:
       - Keep instructions imperative and specific.
       - Keep `description` trigger-rich (what + when to use).
       - Keep the body concise; move details to companion files when needed.
    6. Add supporting files only when they improve repeatability:
       - `scripts/` for deterministic repeated operations.
       - `references/` for large context that should load on demand.
       - `assets/` for templates/resources used in outputs.
    7. Sync changes:
       ```bash
       skillsync sync
       ```
    8. If `~/.skillsync` is git-backed with a configured upstream, push updates:
       ```bash
       skillsync push
       ```

    ## Common edge cases

    - If no sync targets are configured, run `skillsync target add ...` first, then `skillsync sync`.
    - If the requested name is not kebab-case, propose a kebab-case alternative and use that.
    - If the skill already exists, do not overwrite it silently; confirm whether to refine the existing skill.

    ## Important

    - Keep `SKILL.md` focused on procedural guidance, not background theory.
    - Do not create or modify `.meta.toml` \u{2014} it is managed by skillsync.
    - Follow the Agent Skills format:
      - docs index: https://agentskills.io/llms.txt
      - specification: https://agentskills.io/specification.md
    """

  private static let skillCheck = """
    ---
    name: skillsync-check
    description: Check a skill's performance from observation history and surface issues to the user. Use when the user asks how well a skill is performing.
    compatibility: Requires skillsync CLI and local filesystem access to ~/.skillsync.
    metadata:
      short-description: Check skill performance
    ---

    # Check Skill Performance

    Assess performance with concise, evidence-based output.

    ## Workflow

    1. Gather metrics:
       ```bash
       skillsync info <name> --json
       skillsync log <name> --summary --json
       ```
    2. Read:
       - `totalInvocations`
       - `positive`
       - `negative`
    3. Determine status:
       - If `totalInvocations == 0`, report insufficient data.
       - If negative rate is roughly 30%+ with meaningful sample size, recommend refinement.
       - Otherwise report healthy/acceptable performance.
    4. Report in one short message with concrete numbers.
    5. Ask for explicit approval before any refinement work.

    ## Common edge cases

    - If the skill has zero observations, report that there is not enough evidence yet.
    - If `skillsync info` or `skillsync log` says the skill does not exist, report that clearly and ask which skill to check.
    - If the user asks to refine immediately, confirm explicit consent before switching to `skillsync-refine`.

    ## Important

    - This is read-only. Do not edit or refine the skill without the user's explicit approval.
    - If the user wants to refine, consult `skillsync-refine`.
    """

  private static let skillRefine = """
    ---
    name: skillsync-refine
    description: Refine an underperforming skill using observation history. Use when observations show repeated failures and the user has approved refinement.
    compatibility: Requires skillsync CLI and local filesystem access to ~/.skillsync.
    metadata:
      short-description: Refine a skill
    ---

    # Refine a Skill

    Apply small, evidence-driven changes to improve reliability.

    ## Workflow

    1. Confirm explicit user approval to refine.
    2. Analyze failures:
       ```bash
       skillsync log <name> --json
       ```
       Focus on recurring negative notes and missing instructions.
    3. Locate the skill:
       ```bash
       skillsync info <name> --json
       ```
       Read `path` and edit `<path>/SKILL.md`.
    4. Make narrow edits that directly address observed failures:
       - Clarify ambiguous instructions.
       - Add missing preconditions/inputs.
       - Add explicit failure handling steps.
    5. Sync updates:
       ```bash
       skillsync sync
       ```
    6. If `~/.skillsync` is git-backed with a configured upstream, push updates:
       ```bash
       skillsync push
       ```
    7. Summarize what changed and why in terms of observed failures.

    ## Common edge cases

    - If user approval is missing, stop and ask for explicit consent before editing.
    - If there are no actionable negative observations, avoid speculative rewrites and state that no clear refinement target was found.
    - If `skillsync info` fails because the skill is missing, report the error and ask the user which skill to refine.

    ## Important

    - Never refine without user consent.
    - Do not modify `.meta.toml`.
    """
}
