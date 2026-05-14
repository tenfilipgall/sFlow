import XCTest
@testable import SFlow

final class MenuBarIndexTests: XCTestCase {

    func test_parseModifiers_commandOnly() {
        XCTAssertEqual(MenuBarIndex.parseModifiers(rawMods: 0), ["meta"])
    }

    func test_parseModifiers_commandShift() {
        let mods = MenuBarIndex.parseModifiers(rawMods: 1)
        XCTAssertTrue(mods.contains("meta"))
        XCTAssertTrue(mods.contains("shift"))
    }

    func test_parseModifiers_alt() {
        let mods = MenuBarIndex.parseModifiers(rawMods: 2)
        XCTAssertTrue(mods.contains("alt"))
        XCTAssertTrue(mods.contains("meta"))
    }

    func test_parseModifiers_ctrl() {
        let mods = MenuBarIndex.parseModifiers(rawMods: 4)
        XCTAssertTrue(mods.contains("ctrl"))
        XCTAssertTrue(mods.contains("meta"))
    }

    func test_lookup_exactTitle() {
        var index = MenuBarIndex()
        index.insert(title: "New Message", keys: ["meta", "n"])
        let result = index.lookup(query: "new message")
        XCTAssertEqual(result?.entry.keys, ["meta", "n"])
        XCTAssertEqual(result?.confidence, .high)
    }

    func test_lookup_partialTitle() {
        var index = MenuBarIndex()
        index.insert(title: "Find in Files", keys: ["meta", "shift", "f"])
        // query "files" (5 chars) is a substring of key "find in files" → .medium match
        let result = index.lookup(query: "files")
        XCTAssertEqual(result?.entry.keys, ["meta", "shift", "f"])
        XCTAssertEqual(result?.confidence, .medium)
    }

    func test_lookup_copyLink_noFalsePositive() {
        // Bug P-5: "copy link" should NOT match key "copy" (old bug: q.contains(key) was true)
        var index = MenuBarIndex()
        index.insert(title: "Copy", keys: ["meta", "c"])
        XCTAssertNil(index.lookup(query: "copy link"))
    }

    func test_lookup_shortQuery_belowThreshold_returnsNil() {
        // Partial matching requires query.count >= 5 to avoid spurious matches
        var index = MenuBarIndex()
        index.insert(title: "Find in Files", keys: ["meta", "shift", "f"])
        XCTAssertNil(index.lookup(query: "find"))
    }

    func test_lookup_noMatch_returnsNil() {
        var index = MenuBarIndex()
        index.insert(title: "New Message", keys: ["meta", "n"])
        XCTAssertNil(index.lookup(query: "archive"))
    }

    func test_lookup_emptyQuery_returnsNil() {
        var index = MenuBarIndex()
        index.insert(title: "New", keys: ["meta", "n"])
        XCTAssertNil(index.lookup(query: ""))
    }

    // MARK: - Determinism + longest-match-wins (BUG #3)

    func test_lookup_longestMatchWins() {
        var index = MenuBarIndex()
        index.insert(title: "Find", keys: ["meta", "f"])
        index.insert(title: "Find in Files", keys: ["meta", "shift", "f"])
        index.insert(title: "Find Next", keys: ["meta", "g"])
        // Query "find in files" should pick the longest containing key
        let r = index.lookup(query: "find in files")
        XCTAssertEqual(r?.entry.keys, ["meta", "shift", "f"], "longest matching key wins")
    }

    func test_lookup_deterministic_acrossManyInserts() {
        // BUG #3 root cause: titleMap.first(where:) iterated a dict — order unstable.
        // After fix, repeated lookups must return the same value.
        var index = MenuBarIndex()
        for i in 1...50 {
            index.insert(title: "Find variant \(i) text", keys: ["meta", "f"])
        }
        index.insert(title: "Find in Files", keys: ["meta", "shift", "f"])
        let first = index.lookup(query: "find in files")
        for _ in 0..<20 {
            let r = index.lookup(query: "find in files")
            XCTAssertEqual(r?.entry.keys, first?.entry.keys, "lookup must be deterministic")
        }
    }

    func test_lookup_wordBoundary_doesNotMatchInsideWord() {
        var index = MenuBarIndex()
        index.insert(title: "Researcher Mode", keys: ["meta", "alt", "r"])
        // Query "search" (6 chars, ≥ 5 threshold) appears inside "researcher" — must NOT match
        XCTAssertNil(index.lookup(query: "search"))
    }

    func test_lookup_wordBoundary_matchesAtStart() {
        var index = MenuBarIndex()
        index.insert(title: "Search Slack", keys: ["meta", "k"])
        let r = index.lookup(query: "search")
        XCTAssertEqual(r?.entry.keys, ["meta", "k"])
        XCTAssertEqual(r?.confidence, .medium)
    }

    func test_lookup_equalLength_alphabeticallyFirstWins() {
        // When two matching keys have equal length, the alphabetically earlier one wins.
        // Without stable tie-break, dict iteration order would make this nondeterministic.
        var index = MenuBarIndex()
        // Both "find next" and "find prev" are 9 chars, both contain "find n" (6 chars) → no.
        // Use distinct queries: both keys must word-boundary-contain the query.
        // Insert keys of same length that both match query "find":
        index.insert(title: "Find Next", keys: ["meta", "g"])
        index.insert(title: "Find Prev", keys: ["meta", "shift", "g"])
        // Both 9 chars. Query "find " (5 chars including space — wait, threshold is 5).
        // Use a query of length ≥ 5 that matches both: "find " not lowercased-stored.
        // Both stored as lowercase ("find next", "find prev"). Query "find " (with trailing space) won't appear.
        // Use query length 5: "find n" no, that's 6. Try storing differently.
        // Simpler: same length keys, both contain query.
        // Reset and use a cleaner setup.
        var idx2 = MenuBarIndex()
        idx2.insert(title: "Find next entry", keys: ["meta", "g"])
        idx2.insert(title: "Find prev entry", keys: ["meta", "shift", "g"])
        // Both 15 chars. Query "find" no (only 4). Query "entry" (5) appears in both at end.
        let r = idx2.lookup(query: "entry")
        XCTAssertNotNil(r, "either should match — but result must be deterministic")
        // Alphabetical: "find next entry" < "find prev entry", so Next wins
        XCTAssertEqual(r?.entry.keys, ["meta", "g"], "alphabetically earlier key wins on length tie")
    }
}
