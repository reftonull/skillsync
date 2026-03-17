# CLI Contract: Agent Registry Changes

## Modified Commands

### `skillsync target add --tool <name>`

**Before** (current):
```
$ skillsync target add --tool unknown
Error: Unknown tool 'unknown'. Known tools: claude-code, codex, cursor.
```

**After**:
```
$ skillsync target add --tool unknown
Error: Unknown tool 'unknown'. Available tools:

  claude-code     Claude Code
  codex           Codex CLI
  cursor          Cursor
  gemini-cli      Gemini CLI
  copilot         GitHub Copilot
  windsurf        Windsurf
  amp             Amp
  cline           Cline
  opencode        OpenCode

Use 'skillsync target add --path <path>' for agents not listed above.
```

### `skillsync target add --tool` (no argument)

**Before**: Error (missing argument).

**After**: Same listing as unknown tool error above, but without the error prefix. Exit code 0.

### `skillsync target list`

**Before**:
```
ID          PATH                SOURCE
codex       ~/.codex/skills     tool
path-1      /tmp/custom         path
```

**After** (no change to format for this spec; mode column added by per-target-link-mode spec):
```
ID          PATH                SOURCE
codex       ~/.codex/skills     tool
path-1      /tmp/custom         path
```

## Exit Codes

| Scenario | Exit Code |
|---|---|
| Tool added successfully | 0 |
| Unknown tool name | 1 |
| Duplicate path | 1 |
| Registry load failure (fallback used) | 0 (warning on stderr) |
