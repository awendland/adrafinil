import Testing
@testable import AdrafinilShared

/// A safety cutout must actually sleep a lid-closed Mac — but only in the clamshell-sleep case,
/// and only once the block is confirmed cleared.
@Suite("CutoutSleepDecider")
struct CutoutSleepDeciderTests {
    private let d = CutoutSleepDecider()

    @Test
    func `a cutout with the lid closed and no external display sleeps`() {
        #expect(d.shouldSleep(cause: .safetyCutout, onlyDisplayIsClosedBuiltIn: true, blockCleared: true))
    }

    @Test
    func `an external display or an open lid keeps the Mac awake`() {
        #expect(!d.shouldSleep(cause: .safetyCutout, onlyDisplayIsClosedBuiltIn: false, blockCleared: true))
    }

    @Test
    func `a block that failed to clear is not slept against`() {
        #expect(!d.shouldSleep(cause: .safetyCutout, onlyDisplayIsClosedBuiltIn: true, blockCleared: false))
    }

    @Test(arguments: [ReleaseCause.workComplete, .holdExpired, .userAction])
    func `other release causes leave sleep to macOS`(cause: ReleaseCause) {
        #expect(!d.shouldSleep(cause: cause, onlyDisplayIsClosedBuiltIn: true, blockCleared: true))
    }
}
