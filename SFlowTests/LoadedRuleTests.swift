import XCTest
@testable import SFlow

final class LoadedRuleTests: XCTestCase {
    func testDecodesBackendResponseFormat() throws {
        let json = #"""
        {
          "bundleId": "com.x",
          "rulesVersion": "2026-05-11T10:00:00Z",
          "rules": [
            {
              "match": { "role": "AXButton", "titles": ["Send", "Wyślij"] },
              "keys": ["meta", "enter"],
              "hint": "Send",
              "confidence": "high",
              "source": "menu_bar"
            }
          ]
        }
        """#.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(BackendRuleSet.self, from: json)
        XCTAssertEqual(decoded.bundleId, "com.x")
        XCTAssertEqual(decoded.rules.count, 1)
        XCTAssertEqual(decoded.rules[0].match.titles, ["Send", "Wyślij"])
        XCTAssertEqual(decoded.rules[0].keys, ["meta", "enter"])
        XCTAssertEqual(decoded.rules[0].confidence, .high)
        XCTAssertEqual(decoded.rules[0].source, .menuBar)
    }

    func testDecodesOnDiskFormat() throws {
        let json = #"""
        {
          "bundleId": "com.x",
          "appVersion": "1.42",
          "fetchedAt": "2026-05-11T10:00:00Z",
          "source": "cloud",
          "rulesVersion": "2026-05-11T10:00:00Z",
          "rules": []
        }
        """#.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(StoredRuleSet.self, from: json)
        XCTAssertEqual(decoded.source, .cloud)
    }

    func test_decode_legacyRuleWithoutVersionField_defaultsToOne() throws {
        let json = #"""
        {
          "match": { "role": "AXButton", "titles": ["x"] },
          "keys": ["meta", "k"],
          "hint": "h",
          "confidence": "high",
          "source": "menu_bar"
        }
        """#.data(using: .utf8)!
        let rule = try JSONDecoder().decode(LoadedRule.self, from: json)
        XCTAssertEqual(rule.version, 1)
    }

    func test_decode_ruleWithExplicitVersion_preservesValue() throws {
        let json = #"""
        {
          "match": { "role": "AXButton", "titles": ["x"] },
          "keys": ["meta", "k"],
          "hint": "h",
          "confidence": "high",
          "source": "menu_bar",
          "version": 1
        }
        """#.data(using: .utf8)!
        let rule = try JSONDecoder().decode(LoadedRule.self, from: json)
        XCTAssertEqual(rule.version, 1)
    }
}
