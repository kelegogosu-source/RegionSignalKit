import Foundation
#if canImport(Darwin)
import Darwin
#endif

/// Fetches network signals from an endpoint controlled by the integrator.
public final class RegionSignalKitClient {
    private let endpoint: URL
    private let session: URLSession

    public enum ConfigurationError: Error { case httpsRequired }

    public init(endpoint: URL, session: URLSession = .shared) throws {
        guard endpoint.scheme?.lowercased() == "https", endpoint.host != nil else { throw ConfigurationError.httpsRequired }
        self.endpoint = endpoint
        self.session = session
    }

    /// The completion is called on URLSession's callback queue, not necessarily the main queue.
    /// Network or decoding errors produce unknown results, never an implicit pass.
    public func check(policy: Policy = Policy(), completion: @escaping (Report) -> Void) {
        var request = URLRequest(url: endpoint, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        session.dataTask(with: request) { data, response, error in
            var signals: NetworkSignals?
            if error == nil, let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
               http.url?.scheme?.lowercased() == "https", let data = data, data.count <= 16_384 {
                signals = try? JSONDecoder().decode(NetworkSignals.self, from: data)
            }
            let observations = Observations(region: Locale.current.regionCode,
                                            language: Locale.preferredLanguages.first,
                                            network: signals,
                                            tunnelInterfaceDetected: Self.g2())
            completion(RegionSignalKit.evaluate(observations, policy: policy))
        }.resume()
    }

    private static func g2() -> Bool {
        #if canImport(Darwin)
        var first: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&first) == 0, let head = first else { return false }
        defer { freeifaddrs(first) }
        var cursor: UnsafeMutablePointer<ifaddrs>? = head
        while let entry = cursor {
            let flags = Int32(entry.pointee.ifa_flags)
            let name = String(cString: entry.pointee.ifa_name).lowercased()
            if flags & IFF_UP != 0 && RSKStrings.c.contains(where: { name.hasPrefix($0) }) { return true }
            cursor = entry.pointee.ifa_next
        }
        #endif
        return false
    }
}
