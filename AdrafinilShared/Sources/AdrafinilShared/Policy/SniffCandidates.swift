import Foundation

/// Filters the name-matched agent processes a sniff sweep finds down to the ones that should
/// actually get a sniffed hold — the pure, testable core the daemon's `processSweep` calls.
///
/// Some agents run as a *process pair* for one logical session: Devin is a wrapper `devin` that
/// spawns the `devin acp` child the hooks (and MCP servers) run under. Acquiring for every
/// name-matched pid then double-holds a single session: with hooks installed the hook hold watches
/// the child, so the unwatched wrapper picks up a sniffed hold that outlives the turn's `Stop`;
/// without hooks both processes get one. A same-kind ancestor/descendant pair is one agent — the
/// outermost process represents the group (and its tree CPU covers the child for the idle sweep),
/// while a watched descendant already covers its unwatched same-kind ancestors. Different-kind
/// nesting — e.g. Claude Code running inside a Devin shell — is NOT deduped: those really are two
/// agents.
public enum SniffCandidates {
    /// The pids that should get a sniffed hold, sorted for a deterministic acquisition order.
    ///
    /// - Parameters:
    ///   - agents: every running name-matched, non-gateway agent process, pid → kind.
    ///   - watched: pids an existing assertion already watches (a live hold covers them).
    ///   - suppressed: pids whose sniffed hold the daemon already released once this process
    ///     lifetime — don't re-acquire.
    ///   - parentOf: pid → parent pid (`ProcessResolver.parentPID(of:)` in the daemon, a fake
    ///     map in tests).
    public static func select(
        agents: [pid_t: AgentKind],
        watched: Set<pid_t>,
        suppressed: Set<pid_t>,
        parentOf: (pid_t) -> pid_t,
    ) -> [pid_t] {
        agents.keys
            .filter { pid in
                guard !watched.contains(pid), !suppressed.contains(pid) else { return false }
                return !isCovered(pid, by: agents, watched: watched, parentOf: parentOf)
            }
            .sorted()
    }

    /// Whether another same-kind process already stands in for `pid`: a strict ancestor in
    /// `agents` of the same kind (the outermost process represents the pair), or a watched
    /// same-kind descendant (a hook-held `devin acp` child already covers its `devin` wrapper).
    private static func isCovered(
        _ pid: pid_t,
        by agents: [pid_t: AgentKind],
        watched: Set<pid_t>,
        parentOf: (pid_t) -> pid_t,
    ) -> Bool {
        guard let kind = agents[pid] else { return false }
        let ancestors = strictAncestors(of: pid, via: parentOf)
        if ancestors.contains(where: { agents[$0] == kind }) { return true }
        return watched.contains { w in
            agents[w] == kind && strictAncestors(of: w, via: parentOf).contains(pid)
        }
    }

    /// The strict ancestors of `pid`, bounded at 16 hops — the same walk `owningAgentPID` does.
    /// Terminates at pid ≤ 1, on a self-loop, or on a cycle.
    private static func strictAncestors(of pid: pid_t, via parentOf: (pid_t) -> pid_t) -> Set<pid_t> {
        var ancestors: Set<pid_t> = []
        var current = pid
        while ancestors.count < 16 {
            let parent = parentOf(current)
            guard parent > 1, parent != current, !ancestors.contains(parent) else { break }
            ancestors.insert(parent)
            current = parent
        }
        return ancestors
    }
}
