import XCTest
@testable import SFlow

final class AnalyzerTests: XCTestCase {

    func test_aggregate_emptyInput_returnsEmptyReport() {
        let report = Analyzer.aggregate(lines: [])
        XCTAssertEqual(report.totalMisses, 0)
        XCTAssertEqual(report.totalToasts, 0)
        XCTAssertTrue(report.appsRanked.isEmpty)
    }

    func test_aggregate_groupsMissesByBundleAndTuple() {
        let lines = [
            #"{"type":"miss","bundleId":"md.obsidian","role":"AXButton","title":"open quick switcher","desc":"","help":""}"#,
            #"{"type":"miss","bundleId":"md.obsidian","role":"AXButton","title":"open quick switcher","desc":"","help":""}"#,
            #"{"type":"miss","bundleId":"md.obsidian","role":"AXButton","title":"new note","desc":"","help":""}"#,
            #"{"type":"miss","bundleId":"com.linear","role":"AXButton","title":"Create issue","desc":"","help":""}"#,
        ]
        let report = Analyzer.aggregate(lines: lines)
        XCTAssertEqual(report.totalMisses, 4)
        XCTAssertEqual(report.appsRanked.count, 2)
        XCTAssertEqual(report.appsRanked[0].bundleId, "md.obsidian")
        XCTAssertEqual(report.appsRanked[0].missCount, 3)
        XCTAssertEqual(report.appsRanked[0].topMisses[0].count, 2)
        XCTAssertEqual(report.appsRanked[0].topMisses[0].title, "open quick switcher")
    }

    func test_aggregate_countsToastsAlongsideMisses() {
        let lines = [
            #"{"type":"toast","bundleId":"md.obsidian","shortcutId":"x","keys":["meta","k"],"hint":"X","mouseX":0,"mouseY":0}"#,
            #"{"type":"miss","bundleId":"md.obsidian","role":"AXButton","title":"a","desc":"","help":""}"#,
        ]
        let report = Analyzer.aggregate(lines: lines)
        XCTAssertEqual(report.totalToasts, 1)
        XCTAssertEqual(report.totalMisses, 1)
    }

    func test_aggregate_legacyLineWithoutTypeFieldCountsAsToast() {
        let lines = [
            #"{"bundleId":"md.obsidian","shortcutId":"x","keys":["meta","k"],"hint":"X","mouseX":0,"mouseY":0}"#,
        ]
        let report = Analyzer.aggregate(lines: lines)
        XCTAssertEqual(report.totalToasts, 1)
        XCTAssertEqual(report.totalMisses, 0)
    }

    func test_aggregate_skipsCorruptedLinesAndContinues() {
        let lines = [
            #"not json"#,
            #"{"type":"miss","bundleId":"md.obsidian","role":"AXButton","title":"a","desc":"","help":""}"#,
            #"{partial"#,
        ]
        let report = Analyzer.aggregate(lines: lines)
        XCTAssertEqual(report.totalMisses, 1)
    }

    func test_aggregate_handlesPipeCharacterInTitle() {
        let lines = [
            #"{"type":"miss","bundleId":"md.obsidian","role":"AXButton","title":"File | New","desc":"","help":""}"#,
            #"{"type":"miss","bundleId":"md.obsidian","role":"AXButton","title":"File | New","desc":"","help":""}"#,
        ]
        let report = Analyzer.aggregate(lines: lines)
        XCTAssertEqual(report.appsRanked[0].topMisses.count, 1)
        XCTAssertEqual(report.appsRanked[0].topMisses[0].title, "File | New")
        XCTAssertEqual(report.appsRanked[0].topMisses[0].count, 2)
    }

    func test_format_includesAppNameBundleIdAndTopMisses() {
        let lines = [
            #"{"type":"miss","bundleId":"md.obsidian","role":"AXButton","title":"open quick switcher","desc":"","help":""}"#,
        ]
        let report = Analyzer.aggregate(lines: lines)
        let text = Analyzer.format(report: report)
        XCTAssertTrue(text.contains("md.obsidian"))
        XCTAssertTrue(text.contains("open quick switcher"))
        XCTAssertTrue(text.contains("1x"))
    }

    func test_aggregateFalsePositives_groupsByAppAndKeys() {
        let lines = [
            #"{"type":"false_positive","bundleId":"com.x","shortcutId":"s1","keys":["meta","k"],"hint":"New","timestamp":"2026-05-14T00:00:00Z"}"#,
            #"{"type":"false_positive","bundleId":"com.x","shortcutId":"s1","keys":["meta","k"],"hint":"New","timestamp":"2026-05-14T00:00:01Z"}"#,
            #"{"type":"false_positive","bundleId":"com.x","shortcutId":"s2","keys":["meta","enter"],"hint":"Send","timestamp":"2026-05-14T00:00:02Z"}"#,
            #"{"type":"false_positive","bundleId":"com.y","shortcutId":"s3","keys":["ctrl","w"],"hint":"Close","timestamp":"2026-05-14T00:00:03Z"}"#,
        ]
        let fp = Analyzer.aggregateFalsePositives(lines: lines)
        XCTAssertEqual(fp.count, 2)
        let comX = fp.first { $0.bundleId == "com.x" }
        XCTAssertNotNil(comX)
        XCTAssertEqual(comX?.totalReports, 3)
        XCTAssertEqual(comX?.topEntries[0].count, 2)
        XCTAssertEqual(comX?.topEntries[0].keys, ["meta", "k"])
    }

    func test_format_includesFalsePositiveSection() {
        let report = Analyzer.Report(totalToasts: 10, totalMisses: 2, appsRanked: [])
        let fpReport: [Analyzer.FalsePosAppReport] = [
            Analyzer.FalsePosAppReport(
                bundleId: "com.x",
                totalReports: 5,
                topEntries: [Analyzer.FalsePosEntry(keys: ["meta", "k"], hint: "Test", count: 5)]
            )
        ]
        let output = Analyzer.format(report: report, falsePositives: fpReport)
        XCTAssertTrue(output.contains("False Positive"))
        XCTAssertTrue(output.contains("com.x"))
        XCTAssertTrue(output.contains("meta"))
    }
}
