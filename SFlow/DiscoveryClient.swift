import Foundation

enum DiscoveryClientError: Error {
    case http(Int, String)
    case malformedResponse(String)
    case rateLimited(retryAfterSeconds: Int)
}

final class DiscoveryClient {
    private let baseURL: URL
    private let clientVersion: String
    private let session: URLSession

    init(baseURL: URL, clientVersion: String, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.clientVersion = clientVersion
        self.session = session
    }

    /// Default for production. Replace before shipping with the URL from Task A8.
    static let productionURL = URL(string: "https://sflow-rules.shortcutflow.workers.dev")!

    func discover(
        bundleId: String,
        appName: String,
        appVersion: String,
        menuBar: [MenuBarDumpEntry],
        skeleton: [SkeletonItem],
        fresh: Bool = false
    ) async throws -> BackendRuleSet {
        var components = URLComponents(url: baseURL.appendingPathComponent("v1/discover"),
                                       resolvingAgainstBaseURL: false)!
        if fresh {
            components.queryItems = [URLQueryItem(name: "fresh", value: "1")]
        }
        let url = components.url!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = DiscoveryClient.buildRequestBody(
            bundleId: bundleId, appName: appName, appVersion: appVersion,
            menuBar: menuBar, skeleton: skeleton, clientVersion: clientVersion
        )
        req.timeoutInterval = 90  // backend may spend up to ~45s talking to Claude

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw DiscoveryClientError.malformedResponse("not HTTP")
        }
        if http.statusCode == 429 {
            let retry = http.value(forHTTPHeaderField: "Retry-After").flatMap(Int.init) ?? 3600
            throw DiscoveryClientError.rateLimited(retryAfterSeconds: retry)
        }
        guard (200..<300).contains(http.statusCode) else {
            let bodyText = String(data: data, encoding: .utf8) ?? ""
            throw DiscoveryClientError.http(http.statusCode, bodyText)
        }
        return try DiscoveryClient.parseResponse(data)
    }

    static func buildRequestBody(
        bundleId: String, appName: String, appVersion: String,
        menuBar: [MenuBarDumpEntry], skeleton: [SkeletonItem],
        clientVersion: String
    ) -> Data {
        struct Payload: Encodable {
            let bundleId: String
            let appName: String
            let appVersion: String
            let menuBar: [MenuBarDumpEntry]
            let uiSkeleton: [SkeletonItem]
            let clientVersion: String
        }
        let payload = Payload(
            bundleId: bundleId, appName: appName, appVersion: appVersion,
            menuBar: menuBar, uiSkeleton: skeleton, clientVersion: clientVersion
        )
        return try! JSONEncoder().encode(payload)
    }

    static func parseResponse(_ data: Data) throws -> BackendRuleSet {
        do {
            return try JSONDecoder().decode(BackendRuleSet.self, from: data)
        } catch {
            throw DiscoveryClientError.malformedResponse(error.localizedDescription)
        }
    }
}
