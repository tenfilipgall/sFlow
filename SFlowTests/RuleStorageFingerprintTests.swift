import XCTest
@testable import SFlow

/// P-19: bundled.json update path. Compares fingerprints of shipping vs user
/// bundled.json — shipping > user wins. Verifies the fingerprint scoring is
/// monotonic in the dimensions we care about (apps, rules, titles).
final class RuleStorageFingerprintTests: XCTestCase {
    private func encode(_ apps: [(rules: Int, titlesPerRule: Int)]) -> Data {
        // Synth a bundled.json-shaped array
        let entries: [[String: Any]] = apps.enumerated().map { idx, spec in
            let rules: [[String: Any]] = (0..<spec.rules).map { ruleIdx in
                let titles = (0..<spec.titlesPerRule).map { "title-\(ruleIdx)-\($0)" }
                return [
                    "match": ["role": "AXButton", "titles": titles],
                    "keys": ["meta", "k"],
                    "hint": "h",
                    "confidence": "high",
                    "source": "menu_bar",
                    "version": 1,
                ]
            }
            return [
                "bundleId": "com.test.app\(idx)",
                "fetchedAt": "2026-05-18T00:00:00Z",
                "source": "bundled",
                "rules": rules,
            ]
        }
        return try! JSONSerialization.data(withJSONObject: entries)
    }

    func test_fingerprint_emptyArrayIsZero() {
        let data = "[]".data(using: .utf8)!
        XCTAssertEqual(RuleStorage.fingerprintOfData(data), .zero)
    }

    func test_fingerprint_invalidJSONIsZero() {
        let data = "not json".data(using: .utf8)!
        XCTAssertEqual(RuleStorage.fingerprintOfData(data), .zero)
    }

    func test_fingerprint_countsAppsRulesTitles() {
        let data = encode([(rules: 3, titlesPerRule: 4), (rules: 2, titlesPerRule: 5)])
        let fp = RuleStorage.fingerprintOfData(data)
        XCTAssertEqual(fp.appCount, 2)
        XCTAssertEqual(fp.ruleCount, 5)  // 3 + 2
        XCTAssertEqual(fp.titleCount, 22) // 3*4 + 2*5
    }

    func test_fingerprint_moreAppsBeatsMoreRulesAtSameAppCount() {
        // Catches edge: 2 apps with 100 rules each (200 rules total) should
        // NOT beat 3 apps with 50 rules each (150 rules total).
        let fewer = encode([(rules: 100, titlesPerRule: 3), (rules: 100, titlesPerRule: 3)])
        let more = encode([(rules: 50, titlesPerRule: 3),
                           (rules: 50, titlesPerRule: 3),
                           (rules: 50, titlesPerRule: 3)])
        XCTAssertTrue(RuleStorage.fingerprintOfData(more) > RuleStorage.fingerprintOfData(fewer))
    }

    func test_fingerprint_moreRulesBeatsMoreTitlesAtSameAppCount() {
        // Apps equal → rules wins over titles
        let manyTitles = encode([(rules: 5, titlesPerRule: 20)])  // 100 titles
        let manyRules  = encode([(rules: 10, titlesPerRule: 3)])  // 30 titles, more rules
        XCTAssertTrue(RuleStorage.fingerprintOfData(manyRules) > RuleStorage.fingerprintOfData(manyTitles))
    }

    func test_fingerprint_moreTitlesWinsAtSameApps_andRules() {
        let lessTitles = encode([(rules: 5, titlesPerRule: 3)])
        let moreTitles = encode([(rules: 5, titlesPerRule: 5)])
        XCTAssertTrue(RuleStorage.fingerprintOfData(moreTitles) > RuleStorage.fingerprintOfData(lessTitles))
    }

    func test_fingerprint_equalSizesEqual() {
        let a = encode([(rules: 5, titlesPerRule: 3)])
        let b = encode([(rules: 5, titlesPerRule: 3)])
        XCTAssertEqual(RuleStorage.fingerprintOfData(a), RuleStorage.fingerprintOfData(b))
    }

    func test_realBundledShipping_isMonotonicallyLarger_thanV1Snapshot() {
        // Smoke test on the actual shipping bundled.json — it should always
        // be bigger than a synthetic "old" snapshot (1 app, 5 rules, 1 title
        // each).
        guard let url = Bundle.main.url(forResource: "bundled", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            // Skip in environments without the resource (CI without app bundle)
            return
        }
        let shipping = RuleStorage.fingerprintOfData(data)
        let oldSnapshot = RuleStorage.fingerprintOfData(encode([(rules: 5, titlesPerRule: 1)]))
        XCTAssertTrue(shipping > oldSnapshot, "shipping fp \(shipping) should beat old snapshot \(oldSnapshot)")
    }
}
