import XCTest
@testable import RegionSignalKit

final class RegionSignalKitTests: XCTestCase {
    private func state(_ check: Check, _ report: Report) -> CheckState? {
        report.results.first { $0.check == check }?.state
    }
    private func input(_ region: String? = "CN", _ language: String? = "zh-Hans-CN", tunnel: Bool = false) -> Observations {
        Observations(region: region, language: language, tunnelInterfaceDetected: tunnel)
    }
    func testObfuscatedConstantsDecode() {
        XCTAssertEqual(RSKStrings.a, "US")
        XCTAssertEqual(RSKStrings.b, "en")
        XCTAssertEqual(RSKStrings.c, ["utun", "ipsec", "ppp", "tap", "tun"])
    }
    func testStrictPolicyRejectsUnknownAndKnownViolations() {
        let report = RegionSignalKit.evaluate(input())
        for check in [Check.ipCountry, .regionMatchesIP, .vpn, .simPresent, .physicalSIM] {
            XCTAssertEqual(state(check, report), .unknown)
        }
        XCTAssertFalse(report.allowed)
        XCTAssertEqual(state(.deviceRegion, RegionSignalKit.evaluate(input("US"))), .rejected)
        XCTAssertEqual(state(.deviceLanguage, RegionSignalKit.evaluate(input("CN", "en-GB"))), .rejected)
        XCTAssertEqual(state(.vpn, RegionSignalKit.evaluate(input(tunnel: true))), .rejected)
    }
    func testDeviceSettingsPolicy() {
        XCTAssertTrue(RegionSignalKit.evaluate(input(), policy: .deviceSettings).allowed)
        XCTAssertFalse(RegionSignalKit.evaluate(input("US"), policy: .deviceSettings).allowed)
        XCTAssertFalse(RegionSignalKit.evaluate(input("CN", "en-US"), policy: .deviceSettings).allowed)
        XCTAssertEqual(RegionSignalKit.evaluate(input(), policy: .deviceSettings).results.count, 2)
    }
    func testUnknownDoesNotOverrideRejection() {
        var policy = Policy()
        policy.unknownIsRejected = false
        XCTAssertTrue(RegionSignalKit.evaluate(input(), policy: policy).allowed)
        XCTAssertFalse(RegionSignalKit.evaluate(input("CN", "en"), policy: policy).allowed)
        let report = RegionSignalKit.evaluate(input("ZZ", "123"))
        XCTAssertEqual(state(.deviceRegion, report), .unknown)
        XCTAssertEqual(state(.deviceLanguage, report), .unknown)
    }
    func testLocalCheckReturnsRequestedResults() {
        let report = RegionSignalKit.check(policy: .deviceSettings)
        XCTAssertEqual(Set(report.results.map(\.check)), Set([.deviceRegion, .deviceLanguage]))
    }
}
