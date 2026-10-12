import Foundation
import Testing
@testable import AdrafinilShared

/// The latch prevents the acquire → cutout → release → re-acquire oscillation: a cutout's
/// rejection of new acquires must hold until the hazard genuinely recedes (with hysteresis) or
/// the lid opens.
@Suite("CutoutLatch")
struct CutoutLatchTests {
    @Test
    func `tripping latches and produces a rejection message`() {
        var latch = CutoutLatch()
        #expect(!latch.isLatched)
        #expect(latch.rejectionMessage == nil)
        latch.trip(.thermal)
        #expect(latch.isLatched)
        #expect(latch.rejectionMessage != nil)
    }

    @Test
    func `thermal latch holds at the threshold and clears only past hysteresis, sustained`() {
        var latch = CutoutLatch()
        latch.trip(.thermal)
        let t0 = Date(timeIntervalSinceReferenceDate: 0)

        // Just under the threshold is not enough — that's the oscillation the latch exists for.
        latch.update(temperatureCelsius: 79, thermalThresholdCelsius: 80, batteryPercent: nil, onBattery: nil, batteryThresholdPercent: 20, lidClosed: true, now: t0)
        #expect(latch.isLatched)

        // At threshold − hysteresis the cool-down starts, but one reading doesn't clear it.
        latch.update(temperatureCelsius: 75, thermalThresholdCelsius: 80, batteryPercent: nil, onBattery: nil, batteryThresholdPercent: 20, lidClosed: true, now: t0)
        #expect(latch.isLatched)

        // Still below the margin a full cool-down later: clears.
        let cleared = latch.update(temperatureCelsius: 74, thermalThresholdCelsius: 80, batteryPercent: nil, onBattery: nil, batteryThresholdPercent: 20, lidClosed: true, now: t0 + CutoutLatch.thermalCoolDuration)
        #expect(cleared == [.thermal])
        #expect(!latch.isLatched)
    }

    @Test
    func `a hot reading during the cool-down restarts it`() {
        var latch = CutoutLatch()
        latch.trip(.thermal)
        let t0 = Date(timeIntervalSinceReferenceDate: 0)
        let minute: TimeInterval = 60

        // A bursty load: dips below the margin between batches, then heats again.
        latch.update(temperatureCelsius: 70, thermalThresholdCelsius: 80, batteryPercent: nil, onBattery: nil, batteryThresholdPercent: 20, lidClosed: true, now: t0)
        latch.update(temperatureCelsius: 82, thermalThresholdCelsius: 80, batteryPercent: nil, onBattery: nil, batteryThresholdPercent: 20, lidClosed: true, now: t0 + 4 * minute)
        latch.update(temperatureCelsius: 70, thermalThresholdCelsius: 80, batteryPercent: nil, onBattery: nil, batteryThresholdPercent: 20, lidClosed: true, now: t0 + 5 * minute)
        latch.update(temperatureCelsius: 70, thermalThresholdCelsius: 80, batteryPercent: nil, onBattery: nil, batteryThresholdPercent: 20, lidClosed: true, now: t0 + 11 * minute)
        #expect(latch.isLatched, "only six cool minutes since the last hot reading")

        let cleared = latch.update(temperatureCelsius: 70, thermalThresholdCelsius: 80, batteryPercent: nil, onBattery: nil, batteryThresholdPercent: 20, lidClosed: true, now: t0 + 15 * minute)
        #expect(cleared == [.thermal])
    }

    @Test
    func `a missing reading restarts the thermal cool-down`() {
        var latch = CutoutLatch()
        latch.trip(.thermal)
        let t0 = Date(timeIntervalSinceReferenceDate: 0)
        latch.update(temperatureCelsius: 70, thermalThresholdCelsius: 80, batteryPercent: nil, onBattery: nil, batteryThresholdPercent: 20, lidClosed: true, now: t0)
        latch.update(temperatureCelsius: nil, thermalThresholdCelsius: 80, batteryPercent: nil, onBattery: nil, batteryThresholdPercent: 20, lidClosed: true, now: t0 + 5 * 60)
        latch.update(temperatureCelsius: 70, thermalThresholdCelsius: 80, batteryPercent: nil, onBattery: nil, batteryThresholdPercent: 20, lidClosed: true, now: t0 + CutoutLatch.thermalCoolDuration)
        #expect(latch.isLatched)
    }

    @Test
    func `re-tripping the thermal latch restarts its cool-down`() {
        var latch = CutoutLatch()
        latch.trip(.thermal)
        let t0 = Date(timeIntervalSinceReferenceDate: 0)
        latch.update(temperatureCelsius: 70, thermalThresholdCelsius: 80, batteryPercent: nil, onBattery: nil, batteryThresholdPercent: 20, lidClosed: true, now: t0)
        latch.trip(.thermal)
        latch.update(temperatureCelsius: 70, thermalThresholdCelsius: 80, batteryPercent: nil, onBattery: nil, batteryThresholdPercent: 20, lidClosed: true, now: t0 + CutoutLatch.thermalCoolDuration)
        #expect(latch.isLatched)
    }

    @Test
    func `battery latch clears on AC or with charge margin, not on a missing reading`() {
        var latch = CutoutLatch()
        latch.trip(.lowBattery)

        // Unknown readings keep the latch — a cutout must not clear on missing data.
        latch.update(temperatureCelsius: nil, thermalThresholdCelsius: 80, batteryPercent: nil, onBattery: nil, batteryThresholdPercent: 20, lidClosed: true)
        #expect(latch.isLatched)

        // Still on battery, barely above threshold — not enough margin.
        latch.update(temperatureCelsius: nil, thermalThresholdCelsius: 80, batteryPercent: 22, onBattery: true, batteryThresholdPercent: 20, lidClosed: true)
        #expect(latch.isLatched)

        // Plugged in clears immediately.
        let cleared = latch.update(temperatureCelsius: nil, thermalThresholdCelsius: 80, batteryPercent: 22, onBattery: false, batteryThresholdPercent: 20, lidClosed: true)
        #expect(cleared == [.lowBattery])
    }

    @Test
    func `opening the lid clears every cause`() {
        var latch = CutoutLatch()
        latch.trip(.thermal)
        latch.trip(.lowBattery)
        let cleared = latch.update(temperatureCelsius: nil, thermalThresholdCelsius: 80, batteryPercent: nil, onBattery: nil, batteryThresholdPercent: 20, lidClosed: false)
        #expect(cleared == [.thermal, .lowBattery])
        #expect(!latch.isLatched)
    }

    @Test
    func `causes clear independently`() {
        var latch = CutoutLatch()
        latch.trip(.thermal)
        latch.trip(.lowBattery)
        // Cool for a full cool-down but still draining: thermal clears, battery stays.
        let t0 = Date(timeIntervalSinceReferenceDate: 0)
        latch.update(temperatureCelsius: 60, thermalThresholdCelsius: 80, batteryPercent: 15, onBattery: true, batteryThresholdPercent: 20, lidClosed: true, now: t0)
        let cleared = latch.update(temperatureCelsius: 60, thermalThresholdCelsius: 80, batteryPercent: 15, onBattery: true, batteryThresholdPercent: 20, lidClosed: true, now: t0 + CutoutLatch.thermalCoolDuration)
        #expect(cleared == [.thermal])
        #expect(latch.active == [.lowBattery])
    }
}

@Suite("AdrafinilSettings hardening")
struct SettingsHardeningTests {
    @Test
    func `a type-mismatched field costs only that field`() throws {
        let json = """
        {"idleReleaseSeconds": "ninety", "thermalThresholdCelsius": 85, "launchAtLogin": false}
        """
        let s = try JSONDecoder().decode(AdrafinilSettings.self, from: Data(json.utf8))
        #expect(s.idleReleaseSeconds == AdrafinilSettings().idleReleaseSeconds, "the bad field falls back to default")
        #expect(s.thermalThresholdCelsius == 85, "good fields survive")
        #expect(!s.launchAtLogin, "good fields survive")
    }

    @Test
    func `out-of-range values are clamped on load`() throws {
        let json = """
        {"lowBatteryThresholdPercent": 150, "thermalThresholdCelsius": 0, "idleReleaseSeconds": -5, "manualHoldMaxHours": -1, "soundVolume": 9}
        """
        let s = try JSONDecoder().decode(AdrafinilSettings.self, from: Data(json.utf8))
        #expect(s.lowBatteryThresholdPercent == 99, "150% would fire the cutout on every tick")
        #expect(s.thermalThresholdCelsius == 50)
        #expect(s.idleReleaseSeconds == 30)
        #expect(s.manualHoldMaxHours == 0.25)
        #expect(s.soundVolume == 1)
    }
}
