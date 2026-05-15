import XCTest
@testable import SFlow

final class DiscoveryFailureReasonTests: XCTestCase {
    func test_from_rateLimited() {
        let e: Error = DiscoveryClientError.rateLimited(retryAfterSeconds: 60)
        XCTAssertEqual(DiscoveryFailureReason.from(error: e), .rateLimited)
    }

    func test_from_malformedResponse() {
        let e: Error = DiscoveryClientError.malformedResponse("bad json")
        XCTAssertEqual(DiscoveryFailureReason.from(error: e), .parseError)
    }

    func test_from_http() {
        let e: Error = DiscoveryClientError.http(500, "boom")
        XCTAssertEqual(DiscoveryFailureReason.from(error: e), .httpError)
    }

    func test_from_unknownError_fallsBackToHttp() {
        struct Boom: Error {}
        XCTAssertEqual(DiscoveryFailureReason.from(error: Boom()), .httpError)
    }

    func test_rawValuesRoundTrip() {
        for reason in DiscoveryFailureReason.allCases {
            let decoded = DiscoveryFailureReason(rawValue: reason.rawValue)
            XCTAssertEqual(decoded, reason)
        }
    }
}
