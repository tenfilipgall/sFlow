import XCTest
@testable import SFlow

final class MatchConfidenceTests: XCTestCase {

    func test_ordering_lowLessThanMedium() {
        XCTAssertLessThan(MatchConfidence.low, .medium)
    }

    func test_ordering_mediumLessThanHigh() {
        XCTAssertLessThan(MatchConfidence.medium, .high)
    }

    func test_threshold_suppressesLow() {
        XCTAssertFalse(MatchConfidence.low >= .threshold)
    }

    func test_threshold_allowsMedium() {
        XCTAssertTrue(MatchConfidence.medium >= .threshold)
    }

    func test_threshold_allowsHigh() {
        XCTAssertTrue(MatchConfidence.high >= .threshold)
    }
}
