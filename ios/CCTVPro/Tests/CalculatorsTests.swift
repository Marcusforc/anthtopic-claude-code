import XCTest
@testable import CCTVPro

final class CalculatorsTests: XCTestCase {
    func testHDDRawVolume() {
        let r = HDDCalculator.calculate(cameras: 1, bitrateKbps: 1000, days: 1, codec: .h264)
        XCTAssertEqual(r.rawTB, 0.0108, accuracy: 1e-6)
        XCTAssertEqual(r.recommendedTB, 1)
    }

    func testHDDTypicalObject() {
        let r = HDDCalculator.calculate(cameras: 8, bitrateKbps: 4096, days: 30, codec: .h264)
        XCTAssertEqual(r.rawTB, 10.616832, accuracy: 1e-6)
        XCTAssertEqual(r.recommendedTB, 12)
        XCTAssertEqual(r.usableTiB, 10.914, accuracy: 0.001)
    }

    func testHDDCodecSavesSpace() {
        let a = HDDCalculator.calculate(cameras: 4, bitrateKbps: 4096, days: 14, codec: .h264)
        let b = HDDCalculator.calculate(cameras: 4, bitrateKbps: 4096, days: 14, codec: .h265)
        XCTAssertEqual(b.rawTB, a.rawTB * 0.6, accuracy: 1e-9)
    }

    func testPoE() {
        let r = PoECalculator.calculate(cameras: 8, wattsPerCamera: 8, reservePercent: 20)
        XCTAssertEqual(r.totalWatts, 64)
        XCTAssertEqual(r.recommendedBudget, 120)
        XCTAssertEqual(r.portsNeeded, 8)
    }

    func testPowerSupply() {
        let r = PowerSupplyCalculator.calculate(cameras: 8, ampsPerCamera: 0.5, reservePercent: 30)
        XCTAssertEqual(r.totalAmps, 4)
        XCTAssertEqual(r.recommendedAmps, 10)
        XCTAssertEqual(r.recommendedWatts, 120)
    }

    func testCableVoltageDrop() {
        let r = CableCalculator.calculate(length: 50, current: 0.5, section: 0.5, supply: 12)
        XCTAssertEqual(r.resistance, 3.5, accuracy: 1e-9)
        XCTAssertEqual(r.dropVolts, 1.75, accuracy: 1e-9)
        XCTAssertEqual(r.dropPercent, 14.583, accuracy: 0.001)
        XCTAssertEqual(r.maxLength, 17.14, accuracy: 0.01)
    }

    func testWiFiAccessPoints() {
        XCTAssertEqual(WiFiCalculator.calculate(area: 500, band: .ghz24, environment: .open).accessPoints, 1)
        XCTAssertEqual(WiFiCalculator.calculate(area: 500, band: .ghz5, environment: .dense).accessPoints, 3)
    }
}
