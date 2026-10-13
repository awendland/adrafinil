import Foundation
import Testing
@testable import AdrafinilShared

/// Covers `SniffCandidates.select` — the dedupe the daemon's sniff sweep applies before
/// auto-acquiring, built for wrapper/child agent pairs like Devin's `devin` + `devin acp` (both
/// basename `devin`): one logical session must produce one sniffed hold.
@Suite("SniffCandidates")
struct SniffCandidatesTests {
    /// Builds a parentOf closure over a fake ppid map; anything unmapped answers launchd.
    private func parentOf(_ map: [pid_t: pid_t]) -> (pid_t) -> pid_t {
        { map[$0] ?? 1 }
    }

    @Test
    func `wrapper plus same-kind child selects only the wrapper`() {
        // devin wrapper (10) → devin acp child (11). One session, one hold: the outermost
        // process represents the pair, and its tree CPU already covers the child.
        let selected = SniffCandidates.select(
            agents: [10: .devin, 11: .devin],
            watched: [],
            suppressed: [],
            parentOf: parentOf([11: 10]),
        )
        #expect(selected == [10])
    }

    @Test
    func `watched child covers its unwatched same-kind wrapper`() {
        // The hook hold watches the `devin acp` child; sniffing the wrapper too would leave a
        // stale hold that outlives the turn's Stop.
        let selected = SniffCandidates.select(
            agents: [10: .devin, 11: .devin],
            watched: [11],
            suppressed: [],
            parentOf: parentOf([11: 10]),
        )
        #expect(selected.isEmpty)
    }

    @Test
    func `watched wrapper covers its unwatched same-kind child`() {
        let selected = SniffCandidates.select(
            agents: [10: .devin, 11: .devin],
            watched: [10],
            suppressed: [],
            parentOf: parentOf([11: 10]),
        )
        #expect(selected.isEmpty)
    }

    @Test
    func `unrelated same-kind processes each get a hold`() {
        // Two independent devin sessions share no ancestor — both are real agents.
        let selected = SniffCandidates.select(
            agents: [10: .devin, 20: .devin],
            watched: [],
            suppressed: [],
            parentOf: parentOf([10: 2, 20: 3]),
        )
        #expect(selected == [10, 20])
    }

    @Test
    func `different-kind nesting is not deduped`() {
        // A claude session running inside a devin shell is a second agent, not a wrapper.
        let selected = SniffCandidates.select(
            agents: [10: .devin, 30: .claudeCode],
            watched: [],
            suppressed: [],
            parentOf: parentOf([30: 10]),
        )
        #expect(selected == [10, 30])
    }

    @Test
    func `a watched pid is not sniffed`() {
        // An existing hold already watches this pid — sniffing it again would double-acquire.
        let selected = SniffCandidates.select(
            agents: [10: .devin, 20: .codex],
            watched: [10],
            suppressed: [],
            parentOf: parentOf([10: 2, 20: 3]),
        )
        #expect(selected == [20])
    }

    @Test
    func `a suppressed pid is not sniffed`() {
        // The daemon already released a sniffed hold on this pid once — don't re-acquire it.
        let selected = SniffCandidates.select(
            agents: [10: .devin, 20: .codex],
            watched: [],
            suppressed: [10],
            parentOf: parentOf([10: 2, 20: 3]),
        )
        #expect(selected == [20])
    }

    @Test
    func `a suppressed ancestor does not cover its same-kind descendant`() {
        // An outer claude (10) idled once and was suppressed; a nested `claude -p` (11) it
        // launched in the background is still a live agent and needs its own hold.
        let selected = SniffCandidates.select(
            agents: [10: .claudeCode, 11: .claudeCode],
            watched: [],
            suppressed: [10],
            parentOf: parentOf([11: 10]),
        )
        #expect(selected == [11])
    }

    @Test
    func `parent walk terminates on a cycle`() {
        // A corrupt/racy ppid map (10 → 11 → 10) must not loop forever. In the degenerate case
        // each sees the other as an ancestor, so both are dropped — better one too few holds
        // than a hang inside the sweep.
        let selected = SniffCandidates.select(
            agents: [10: .devin, 11: .devin],
            watched: [],
            suppressed: [],
            parentOf: parentOf([10: 11, 11: 10]),
        )
        #expect(selected.isEmpty)
    }
}
