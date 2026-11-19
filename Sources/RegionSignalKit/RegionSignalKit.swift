import Foundation

/// A missing signal is deliberately distinct from a confirmed violation.
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

/// Values supplied by your own HTTPS endpoint. `vpn` should be the server's risk assessment
/// of the address it actually received, not an address supplied by the client.
public struct NetworkSignals: Decodable {
    public let countryCode: String?
    public let vpn: Bool?

    public init(countryCode: String?, vpn: Bool?) {
        self.countryCode = countryCode
        self.vpn = vpn
    }
    enum CodingKeys: String, CodingKey { case countryCode = "country_code", vpn }
}

public struct Policy {
    public var enabledChecks: Set<Check> = Set(Check.allCases)
    public var unknownIsRejected = true
    public init() {}
}

/// The caller can inject test observations. Never treat client observations as authoritative
/// proof of physical SIM, identity, location, or absence of a VPN.
public struct Observations {
    public var region: String?
    public var language: String?
    public var network: NetworkSignals?
    /// True means a tunnel-like interface was found; false does not prove VPN absence.
    public var tunnelInterfaceDetected: Bool
    public init(region: String?, language: String?, network: NetworkSignals?, tunnelInterfaceDetected: Bool = false) {
        self.region = region
        self.language = language
        self.network = network
        self.tunnelInterfaceDetected = tunnelInterfaceDetected
    }
}

public enum RegionSignalKit {
    public static func evaluate(_ observations: Observations, policy: Policy = Policy()) -> Report {
        let region = g1(observations.region)
        let ipCountry = g1(observations.network?.countryCode)
        let language = observations.language?.trimmingCharacters(in: .whitespacesAndNewlines)
        var results: [CheckResult] = []
        func add(_ check: Check, _ state: CheckState, _ detail: String) {
            if policy.enabledChecks.contains(check) { results.append(CheckResult(check: check, state: state, detail: detail)) }
        }
        if let ipCountry = ipCountry {
            add(.ipCountry, ipCountry == RSKStrings.a ? .rejected : .passed, "IP country: \(ipCountry)")
        } else { add(.ipCountry, .unknown, "IP country unavailable or invalid") }
        if let region = region {
            add(.deviceRegion, region == RSKStrings.a ? .rejected : .passed, "Device region: \(region)")
        } else { add(.deviceRegion, .unknown, "Device region unavailable or invalid") }
        if let language = language, !language.isEmpty {
            let code = language.replacingOccurrences(of: "_", with: "-").split(separator: "-").first?.lowercased()
            if let code = code, code.count >= 2, code.count <= 3, code.allSatisfy({ $0.isASCII && $0.isLetter }) {
                add(.deviceLanguage, code == RSKStrings.b ? .rejected : .passed, "Preferred language: \(language)")
            } else { add(.deviceLanguage, .unknown, "Preferred language unavailable or invalid") }
        } else { add(.deviceLanguage, .unknown, "Preferred language unavailable") }
        if let region = region, let ipCountry = ipCountry {
            add(.regionMatchesIP, region == ipCountry ? .passed : .rejected, "Device region \(region), IP country \(ipCountry)")
        } else { add(.regionMatchesIP, .unknown, "Device region or IP country unavailable") }
        if observations.tunnelInterfaceDetected {
            add(.vpn, .rejected, "Tunnel-like network interface detected")
        } else if let vpn = observations.network?.vpn {
            add(.vpn, vpn ? .rejected : .passed, "Server VPN risk assessment: \(vpn)")
        } else { add(.vpn, .unknown, "VPN status cannot be determined") }
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
