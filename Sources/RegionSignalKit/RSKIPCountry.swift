import Foundation

extension RegionSignalKit {
    /// Queries ipwho.is for the public exit IP country. The service receives the user's IP.
    /// The completion runs on the URLSession callback queue. Failures remain unknown.
    public static func checkWithIP(policy: Policy = Policy(), session: URLSession = .shared,
                                   completion: @escaping (Report) -> Void) {
        let endpoint = URL(string: "https://ipwho.is/")!
        var request = URLRequest(url: endpoint, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        session.dataTask(with: request) { data, response, error in
            var country: String?
            if error == nil, let response = response as? HTTPURLResponse,
               (200..<300).contains(response.statusCode), response.url?.scheme?.lowercased() == "https",
               response.url?.host?.lowercased() == "ipwho.is", let data = data, data.count <= 16_384,
               let value = try? JSONDecoder().decode(IPResponse.self, from: data), value.success == true {
                country = value.countryCode
            }
            let observations = Observations(region: Locale.current.regionCode,
                                            language: Locale.preferredLanguages.first,
                                            ipCountryCode: country,
                                            tunnelInterfaceDetected: RSKLocalNetwork.g2())
            completion(evaluate(observations, policy: policy))
        }.resume()
    }
}

private struct IPResponse: Decodable {
    let success: Bool?
    let countryCode: String?
    enum CodingKeys: String, CodingKey { case success; case countryCode = "country_code" }
}
