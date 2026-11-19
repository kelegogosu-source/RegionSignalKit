import XCTest
@testable import RegionSignalKit

final class IPStub: URLProtocol {
    static var payload = Data()
    static var status = 200
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.payload)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

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
    func testIPCountryAndRegionMatching() {
        let us = RegionSignalKit.evaluate(Observations(region: "CN", language: "zh", ipCountryCode: "us"))
        XCTAssertEqual(state(.ipCountry, us), .rejected)
        XCTAssertEqual(state(.regionMatchesIP, us), .rejected)
        let matching = RegionSignalKit.evaluate(Observations(region: "CN", language: "zh", ipCountryCode: "cn"))
        XCTAssertEqual(state(.ipCountry, matching), .passed)
        XCTAssertEqual(state(.regionMatchesIP, matching), .passed)
        let invalid = RegionSignalKit.evaluate(Observations(region: "CN", language: "zh", ipCountryCode: "ZZ"))
        XCTAssertEqual(state(.ipCountry, invalid), .unknown)
        XCTAssertEqual(state(.regionMatchesIP, invalid), .unknown)
    }
    func testIPLookupSuccessAndFailure() {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [IPStub.self]
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }
        for (json, status, expected) in [
            ("{\"success\":true,\"country_code\":\"US\"}", 200, CheckState.rejected),
            ("{\"success\":true,\"country_code\":\"CN\"}", 200, CheckState.passed),
            ("{\"success\":false,\"country_code\":\"CN\"}", 200, CheckState.unknown),
            ("{\"success\":true,\"country_code\":\"CN\"}", 429, CheckState.unknown),
            ("bad json", 200, CheckState.unknown)
        ] {
            IPStub.status = status
            IPStub.payload = Data(json.utf8)
            let completed = expectation(description: "IP lookup")
            RegionSignalKit.checkWithIP(session: session) { report in
                XCTAssertEqual(self.state(.ipCountry, report), expected)
                completed.fulfill()
            }
            wait(for: [completed], timeout: 5)
        }
    }
    func testLocalCheckReturnsRequestedResults() {
        let report = RegionSignalKit.check(policy: .deviceSettings)
        XCTAssertEqual(Set(report.results.map(\.check)), Set([.deviceRegion, .deviceLanguage]))
    }
}
