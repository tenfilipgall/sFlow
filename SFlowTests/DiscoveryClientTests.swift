import XCTest
@testable import SFlow

final class DiscoveryClientTests: XCTestCase {
    func testBuildsCorrectRequestBody() throws {
        let body = DiscoveryClient.buildRequestBody(
            bundleId: "com.x",
            appName: "X",
            appVersion: "1.0.5",
            menuBar: [MenuBarDumpEntry(path: ["File", "New"], shortcut: "cmd+n")],
            skeleton: [SkeletonItem(role: "AXButton", title: "Send")],
            clientVersion: "1.0.0"
        )
        let json = try JSONSerialization.jsonObject(with: body) as! [String: Any]
        XCTAssertEqual(json["bundleId"] as? String, "com.x")
        XCTAssertEqual(json["appVersion"] as? String, "1.0.5")
        XCTAssertEqual((json["menuBar"] as? [[String: Any]])?.count, 1)
        XCTAssertEqual((json["uiSkeleton"] as? [[String: Any]])?.count, 1)
    }

    func testParsesBackendResponse() throws {
        let json = #"""
        {
          "bundleId": "com.x",
          "rulesVersion": "2026-05-11T00:00:00Z",
          "rules": [
            {
              "match": {"role": "AXButton", "titles": ["Send"]},
              "keys": ["meta", "enter"],
              "hint": "Send",
              "confidence": "high",
              "source": "menu_bar"
            }
          ]
        }
        """#.data(using: .utf8)!
        let result = try DiscoveryClient.parseResponse(json)
        XCTAssertEqual(result.bundleId, "com.x")
        XCTAssertEqual(result.rules.count, 1)
    }

    func testParseBundledResponse() throws {
        let json = #"""
        {
          "version": "2026-05-14T00:00:00Z",
          "rules": [
            {
              "bundleId": "com.x",
              "appVersion": "1.0",
              "fetchedAt": "2026-05-14T00:00:00Z",
              "source": "bundled",
              "rulesVersion": "2026-05-14T00:00:00Z",
              "rules": []
            }
          ]
        }
        """#.data(using: .utf8)!
        let result = try JSONDecoder().decode(BundledResponse.self, from: json)
        XCTAssertEqual(result.version, "2026-05-14T00:00:00Z")
        XCTAssertEqual(result.rules.count, 1)
        XCTAssertEqual(result.rules[0].bundleId, "com.x")
    }
}
