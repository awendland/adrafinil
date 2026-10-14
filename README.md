# Adrafinil

Adrafinil keeps a Mac awake through a closed lid while a coding agent works, then releases the hold when the turn ends. Hooks track active work across agents; a thermal cutout and automatic release of abandoned holds limit unattended runs.

<a href="https://kagerou.glass/get/adrafinil?from=readme"><img src=".github/download.svg" alt="Download Adrafinil for Mac" width="360" height="80"></a>

![Adrafinil](.github/adrafinil-awake.png)

## Highlights

- Keep a closed-lid Mac running for the duration of agent work.
- Track overlapping agents independently; sleep resumes after the last hold ends.
- Limit unattended holds with a thermal cutout and abandoned-session cleanup.

<details>
<summary>Full feature list</summary>

- Hooks for Claude Code, Codex, Cursor, Gemini CLI, Devin, Aider, Hermes, OpenCode, Cline, and Pi.
- Per-session acquire/release, timed holds, and manual **Let it sleep** control.
- Closed-lid sleep control through a privileged helper.
- CLI and MCP access; custom integrations through hooks or command wrappers.
- Thermal cutout and automatic release of abandoned holds.
- Optional detection of running agent processes, lid-close audio confirmation, and a lid-open activity/temperature summary.
- Hook removal during uninstall.

</details>

## Notes

- macOS 26.4+; administrator approval for the privileged helper. [macOS 15 backport](https://github.com/valentine/adrafinil).
- Homebrew: `brew install --cask adrafinil`; install agent hooks in Settings.
- [CLI, custom hooks, and installation quirks](REFERENCE.md).
