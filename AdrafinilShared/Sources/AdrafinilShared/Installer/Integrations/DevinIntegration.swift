import Foundation

/// Devin (Devin CLI): `~/.config/devin/config.json`, `UserPromptSubmit` → acquire, `Stop` → release.
/// Same nested JSON shape as Claude Code — a `hooks` object keyed by event, each value an array of
/// groups wrapping an inner `hooks` array of `{"type": "command", "command": …}` handlers (verified
/// against Devin CLI 3000.11.3, which also tolerates the `_adrafinil` marker key on a handler).
///
/// **Activity-scoped, not session-scoped** (like Claude Code, Codex and Cursor): `UserPromptSubmit`
/// fires when a prompt is submitted and `Stop` fires when the agent finishes responding, so an
/// open-but-idle session at the prompt holds nothing — only an actively-working turn keeps the Mac
/// awake.
///
/// `SessionEnd` → release is release-only cleanup: it fires when a session ends, carrying that
/// session's id (verified on exit, `reason: "other"`), so a session that ends without a `Stop`
/// releases at once. It does not re-introduce session-scoped holding.
///
/// There is no session-id env var to expand — every hook payload carries `session_id` on stdin, so
/// the commands pass no positional and the CLI sources the id there.
///
/// The same wiring is expected to cover Devin Desktop's "Devin Local" agent too — per Devin's
/// docs it runs the same `devin acp` harness and reads the same user-level
/// `~/.config/devin/config.json` — but that is not yet verified on a Desktop install.
///
/// No TTL: the owning `devin` process is resolvable by the parent-walk (a hook's process tree is
/// `/bin/sh` → `devin` → …, basename `devin`), so the daemon's process-exit watcher covers a
/// terminal closed mid-turn. Like Claude Code, Devin fires no `Stop` when a turn is interrupted
/// (double-Esc in the TUI; verified on 3000.11.3), so the CPU-idle sweep releases that hold. No
/// background-shell hook either — Devin's exec exposes no clean `run_in_background` signal.
///
/// **MCP.** Devin imports Claude Code's MCP servers (`~/.claude.json`) by default, so registering
/// Devin's own `adrafinil` server in `~/.config/devin/mcp_config.json` overrides the imported one
/// by name (verified, 3000.11.3).
struct DevinIntegration: AgentIntegration {
    let agent = AgentKind.devin

    func isDetected(_ ctx: HookContext) -> Bool {
        FileManager.default.fileExists(atPath: "\(ctx.homeRoot)/.config/devin")
    }
    func primaryConfigPath(_ ctx: HookContext) -> String {
        "\(ctx.homeRoot)/.config/devin/config.json"
    }

    func install(_ ctx: HookContext, dryRun: Bool) throws -> HookInstaller.InstallResult {
        try shape(ctx).install(dryRun: dryRun)
    }

    func uninstall(_ ctx: HookContext, dryRun: Bool) throws -> HookInstaller.InstallResult {
        try shape(ctx).uninstall(dryRun: dryRun)
    }

    func installState(_ ctx: HookContext) -> HookInstallState {
        shape(ctx).installState()
    }

    private func shape(_ ctx: HookContext) -> NestedJSONHookShape {
        NestedJSONHookShape(
            configPath: "\(ctx.homeRoot)/.config/devin/config.json",
            startEvent: "UserPromptSubmit",
            endEvent: "Stop",
            acquireCommand: ctx.hookCommand("acquire", tool: agent.rawValue),
            releaseCommand: ctx.hookCommand("release", tool: agent.rawValue),
            // SessionEnd releases the retiring session's hold (see above) — release-only cleanup.
            extraHandlers: [
                .init(event: "SessionEnd", command: ctx.hookCommand("release", tool: agent.rawValue)),
            ],
        )
    }

    /// MCP lives in `~/.config/devin/mcp_config.json` under `mcpServers` — verified against Devin
    /// CLI 3000.11.3, which loads it and lists `keep_awake`/`release_awake`/`awake_status`.
    func mcpShape(_ ctx: HookContext) -> MCPServerShape? {
        MCPServerShape(
            configPath: "\(ctx.homeRoot)/.config/devin/mcp_config.json",
            serverName: HookContext.mcpServerName,
            entry: ctx.mcpEntry(tool: agent.rawValue),
        )
    }
}
