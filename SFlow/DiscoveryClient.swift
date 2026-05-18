import Foundation

enum DiscoveryClientError: Error {
    case http(Int, String)
    case malformedResponse(String)
    case rateLimited(retryAfterSeconds: Int)
}

struct BundledResponse: Codable {
    let version: String
    let rules: [StoredRuleSet]
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
        fresh: Bool = false,
        appLocale: String? = nil
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
            menuBar: menuBar, skeleton: skeleton, clientVersion: clientVersion,
            appLocale: appLocale
        )
        // P-35 mitigation (2026-05-18): backend now uses web_search max_uses=8 (Sub-cel 1.12)
        // which can push generation to ~120s for apps with deep cheatsheet searches (observed:
        // Obsidian first attempt timed out at 90s; retry succeeded in ~90s). Raised to 180s so
        // typical reseed/discover finishes on first try. Backend itself has CF Workers safety
        // limits; 180s is a generous client-side ceiling.
        req.timeoutInterval = 180

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
        clientVersion: String, appLocale: String? = nil
    ) -> Data {
        struct Payload: Encodable {
            let bundleId: String
            let appName: String
            let appVersion: String
            let appLocale: String?
            let menuBar: [MenuBarDumpEntry]
            let uiSkeleton: [SkeletonItem]
            let clientVersion: String
        }
        let payload = Payload(
            bundleId: bundleId, appName: appName, appVersion: appVersion,
            appLocale: appLocale,
            menuBar: menuBar, uiSkeleton: skeleton, clientVersion: clientVersion
        )
        let encoder = JSONEncoder()
        // omit nil appLocale from JSON entirely (backward-compat with backend
        // that doesn't yet know about the field)
        return try! encoder.encode(payload)
    }

    static func parseResponse(_ data: Data) throws -> BackendRuleSet {
        do {
            return try JSONDecoder().decode(BackendRuleSet.self, from: data)
        } catch {
            throw DiscoveryClientError.malformedResponse(error.localizedDescription)
        }
    }

    func fetchBundled() async throws -> BundledResponse {
        let url = baseURL.appendingPathComponent("v1/bundled")
        let (data, response) = try await session.data(for: URLRequest(url: url))
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw DiscoveryClientError.http(code, String(data: data, encoding: .utf8) ?? "")
        }
        do {
            return try JSONDecoder().decode(BundledResponse.self, from: data)
        } catch {
            throw DiscoveryClientError.malformedResponse(error.localizedDescription)
        }
    }

    func feedback(bundleId: String, keys: [String], reportType: String = "wrong_shortcut") async {
        let url = baseURL.appendingPathComponent("v1/feedback")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["bundleId": bundleId, "keys": keys, "reportType": reportType]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 10
        do {
            let (_, response) = try await session.data(for: req)
            if let http = response as? HTTPURLResponse {
                NSLog("SFlow: feedback POST \(http.statusCode) for \(bundleId)")
            }
        } catch {
            NSLog("SFlow: feedback POST failed: \(error.localizedDescription)")
        }
    }
}
