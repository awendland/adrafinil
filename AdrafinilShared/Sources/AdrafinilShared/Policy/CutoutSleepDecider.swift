import Foundation

/// Decides whether the daemon must put the Mac to sleep itself after the registry empties. Pure.
///
/// Clearing the sleep block lets a lid-closed MacBook sleep only in principle: macOS runs
/// clamshell sleep on the lid-close edge, and once a hold has carried the Mac past that edge only
/// idle sleep is left, which any `PreventUserIdleSystemSleep` or display assertion defers — the
/// `caffeinate -i` wrapping the very job that overheated it, for one. So a safety cutout requests
/// sleep explicitly, the way `pmset sleepnow` does.
///
/// Gated to the clamshell-sleep case: lid closed with no external display. A closed lid driving
/// an external display is a desk setup with the user present, and sleeping it would cut them off.
/// The block must also have been confirmed cleared, since a sleep request against a still-set
/// `disablesleep` is refused.
public struct CutoutSleepDecider {
    public init() {}

    public func shouldSleep(
        cause: ReleaseCause,
        onlyDisplayIsClosedBuiltIn: Bool,
        blockCleared: Bool,
    ) -> Bool {
        cause == .safetyCutout && onlyDisplayIsClosedBuiltIn && blockCleared
    }
}
