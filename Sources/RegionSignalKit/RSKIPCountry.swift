import Foundation

extension RegionSignalKit {
    /// Queries Cloudflare's diagnostic trace to estimate the public exit IP country.
    /// Cloudflare receives the user's IP; its trace format may change without notice.
    /// The completion runs on the URLSession callback queue. Failures remain unknown.
    public static func checkWithIP(policy: Policy = Policy(), session: URLSession = .shared,
                                   completion: @escaping (Report) -> Void) {
        let endpoint = URL(string: "https://www.cloudflare.com/cdn-cgi/trace")!
        var request = URLRequest(url: endpoint, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        request.setValue("text/plain", forHTTPHeaderField: "Accept")
        session.dataTask(with: request) { data, response, error in
            var country: String?
            if error == nil, let response = response as? HTTPURLResponse,
               (200..<300).contains(response.statusCode), response.url?.scheme?.lowercased() == "https",
               response.url?.host?.lowercased() == endpoint.host?.lowercased(),
               response.url?.path == endpoint.path, let data = data, data.count <= 16_384,
               let text = String(data: data, encoding: .utf8) {
                let entries = text.components(separatedBy: .newlines).filter { $0.hasPrefix("loc=") }
                if entries.count == 1 {
                    country = String(entries[0].dropFirst(4)).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            let observations = Observations(region: Locale.current.regionCode,
                                            language: Locale.preferredLanguages.first,
                                            ipCountryCode: country,
                                            tunnelInterfaceDetected: RSKLocalNetwork.g2())
            completion(evaluate(observations, policy: policy))
        }.resume()
    }
}
