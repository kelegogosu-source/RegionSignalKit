import Foundation

public enum CheckState: String {
    case passed, rejected, unknown
}

public enum Check: String, CaseIterable {
    case ipCountry, deviceRegion, deviceLanguage, regionMatchesIP, vpn, simPresent, physicalSIM
}

public struct CheckResult {
    public let check: Check
    public let state: CheckState
    public let detail: String
}

public struct Report {
    public let results: [CheckResult]
    public let unknownIsRejected: Bool
    public var allowed: Bool {
        !results.contains { $0.state == .rejected || (unknownIsRejected && $0.state == .unknown) }
    }
}

public struct Policy {
    /// The strict default enables all checks and rejects unknown results.
    public var enabledChecks: Set<Check> = Set(Check.allCases)
    public var unknownIsRejected = true
    public init() {}

    /// Only checks the device's region and first preferred language, without network access.
    public static var deviceSettings: Policy {
        var policy = Policy()
        policy.enabledChecks = [.deviceRegion, .deviceLanguage]
        return policy
    }
}

/// Injectable values for tests. They are not trusted proof of a device's location or network.
public struct Observations {
    public var region: String?
    public var language: String?
    /// A tunnel-like interface is only a heuristic, and may not be a VPN.
    public var tunnelInterfaceDetected: Bool
    public init(region: String?, language: String?, tunnelInterfaceDetected: Bool = false) {
        self.region = region
        self.language = language
        self.tunnelInterfaceDetected = tunnelInterfaceDetected
    }
}

public enum RegionSignalKit {
    /// Read device settings and local interface information. No network request is made.
    public static func check(policy: Policy = Policy()) -> Report {
        evaluate(Observations(region: Locale.current.regionCode,
                              language: Locale.preferredLanguages.first,
                              tunnelInterfaceDetected: RSKLocalNetwork.g2()), policy: policy)
    }

    public static func evaluate(_ observations: Observations, policy: Policy = Policy()) -> Report {
        let region = g1(observations.region)
        let language = observations.language?.trimmingCharacters(in: .whitespacesAndNewlines)
        var results: [CheckResult] = []
        func add(_ check: Check, _ state: CheckState, _ detail: String) {
            if policy.enabledChecks.contains(check) { results.append(CheckResult(check: check, state: state, detail: detail)) }
        }
        add(.ipCountry, .unknown, "IP country is unavailable without an IP geolocation source")
        if let region = region {
            add(.deviceRegion, region == RSKStrings.a ? .rejected : .passed, "Device region: \(region)")
        } else { add(.deviceRegion, .unknown, "Device region unavailable or invalid") }
        if let language = language, !language.isEmpty {
            let code = language.replacingOccurrences(of: "_", with: "-").split(separator: "-").first?.lowercased()
            if let code = code, code.count >= 2, code.count <= 3, code.allSatisfy({ $0.isASCII && $0.isLetter }) {
                add(.deviceLanguage, code == RSKStrings.b ? .rejected : .passed, "Preferred language: \(language)")
            } else { add(.deviceLanguage, .unknown, "Preferred language unavailable or invalid") }
        } else { add(.deviceLanguage, .unknown, "Preferred language unavailable") }
        add(.regionMatchesIP, .unknown, "IP country is unavailable without an IP geolocation source")
        if observations.tunnelInterfaceDetected {
            add(.vpn, .rejected, "Tunnel-like network interface detected; this may not be a VPN")
        } else {
            add(.vpn, .unknown, "No tunnel-like interface detected; VPN absence cannot be verified")
        }
        add(.simPresent, .unknown, "iOS does not expose a reliable general-purpose SIM presence check")
        add(.physicalSIM, .unknown, "iOS does not expose a reliable general-purpose physical SIM versus eSIM check")
        return Report(results: results, unknownIsRejected: policy.unknownIsRejected)
    }

    private static func g1(_ raw: String?) -> String? {
        guard let value = raw?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
              value.count == 2, Locale.isoRegionCodes.contains(value) else { return nil }
        return value
    }
}
