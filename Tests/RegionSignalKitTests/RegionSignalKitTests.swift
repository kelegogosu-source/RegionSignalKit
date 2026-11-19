import XCTest
@testable import RegionSignalKit

final class RegionSignalKitTests: XCTestCase {
    private func state(_ check: Check, _ report: Report) -> CheckState? {
        report.results.first { $0.check == check }?.state
    }
    private func input(_ region: String? = "CN", _ language: String? = "zh-Hans-CN", _ country: String? = "CN", _ vpn: Bool? = false, tunnel: Bool = false) -> Observations {
        Observations(region: region, language: language, network: NetworkSignals(countryCode: country, vpn: vpn), tunnelInterfaceDetected: tunnel)
    }
    func testObfuscatedConstantsDecode() {
        XCTAssertEqual(RSKStrings.a, "US")
        XCTAssertEqual(RSKStrings.b, "en")
        XCTAssertEqual(RSKStrings.c, ["utun", "ipsec", "ppp", "tap", "tun"])
    }
    func testEachRequestedRule() {
        XCTAssertEqual(state(.ipCountry, RegionSignalKit.evaluate(input("CN", "zh", "us"))), .rejected)
        XCTAssertEqual(state(.deviceRegion, RegionSignalKit.evaluate(input("US"))), .rejected)
        XCTAssertEqual(state(.deviceLanguage, RegionSignalKit.evaluate(input("CN", "en-GB"))), .rejected)
        XCTAssertEqual(state(.regionMatchesIP, RegionSignalKit.evaluate(input("JP", "ja", "CN"))), .rejected)
        XCTAssertEqual(state(.vpn, RegionSignalKit.evaluate(input("CN", "zh", "CN", true))), .rejected)
        XCTAssertEqual(state(.vpn, RegionSignalKit.evaluate(input(tunnel: true))), .rejected)
        let report = RegionSignalKit.evaluate(input())
        XCTAssertEqual(state(.simPresent, report), .unknown)
        XCTAssertEqual(state(.physicalSIM, report), .unknown)
        XCTAssertFalse(report.allowed)
    }
    func testUnknownAndOptOut() {
        var policy = Policy()
        policy.enabledChecks.subtract([.simPresent, .physicalSIM])
        XCTAssertTrue(RegionSignalKit.evaluate(input(), policy: policy).allowed)
        XCTAssertFalse(RegionSignalKit.evaluate(input("CN", "zh", nil, nil), policy: policy).allowed)
        policy.unknownIsRejected = false
        XCTAssertTrue(RegionSignalKit.evaluate(input("CN", "zh", nil, nil), policy: policy).allowed)
        XCTAssertFalse(RegionSignalKit.evaluate(input("CN", "en", nil, nil), policy: policy).allowed)
    }
    func testInvalidSignalsAndJSON() throws {
        let data = Data("{\"country_code\":\"CN\",\"vpn\":false}".utf8)
        let signals = try JSONDecoder().decode(NetworkSignals.self, from: data)
        XCTAssertEqual(signals.countryCode, "CN")
        let report = RegionSignalKit.evaluate(input("ZZ", "123", "USA", nil))
        XCTAssertEqual(state(.deviceRegion, report), .unknown)
        XCTAssertEqual(state(.ipCountry, report), .unknown)
        XCTAssertEqual(state(.deviceLanguage, report), .unknown)
        XCTAssertEqual(state(.vpn, report), .unknown)
        XCTAssertThrowsError(try RegionSignalKitClient(endpoint: URL(string: "http://example.com")!))
    }
}
