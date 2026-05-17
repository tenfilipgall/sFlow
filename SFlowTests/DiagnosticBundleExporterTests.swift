import XCTest
@testable import SFlow

final class DiagnosticBundleExporterTests: XCTestCase {

    func test_makeTimestamp_followsExpectedFormat() {
        let fixed = Date(timeIntervalSince1970: 1_715_000_000) // 2024-05-06 12:53:20 UTC
        let stamp = DiagnosticBundleExporter.makeTimestamp(date: fixed)
        XCTAssertEqual(stamp, "20240506-125320")
    }

    func test_makeTimestamp_alwaysMatchesYYYYMMDD_HHMMSS() throws {
        let stamp = DiagnosticBundleExporter.makeTimestamp()
        let regex = try NSRegularExpression(pattern: #"^\d{8}-\d{6}$"#)
        let range = NSRange(stamp.startIndex..., in: stamp)
        XCTAssertNotNil(regex.firstMatch(in: stamp, range: range),
                        "Timestamp \(stamp) doesn't match YYYYMMDD-HHMMSS")
    }

    func test_makeSystemInfo_includesOSAndLocale() {
        let info = DiagnosticBundleExporter.makeSystemInfo()
        XCTAssertTrue(info.contains("macOS version:"), "Missing macOS version line")
        XCTAssertTrue(info.contains("Locale:"), "Missing locale line")
        XCTAssertTrue(info.contains("SFlow version:"), "Missing SFlow version line")
        XCTAssertTrue(info.contains("Screen count:"), "Missing screen count line")
    }

    func test_makeSystemInfo_doesNotLeakUserIdentity() {
        // Defensive: no usernames, no IPs, no app list. Document the policy.
        let info = DiagnosticBundleExporter.makeSystemInfo()
        let lowered = info.lowercased()
        let username = NSUserName().lowercased()
        if !username.isEmpty && username != "_unknown" {
            XCTAssertFalse(lowered.contains(username),
                           "system-info.txt leaked username '\(username)' — PII risk")
        }
        XCTAssertFalse(lowered.contains("/users/"),
                       "system-info.txt leaked home-folder path — PII risk")
    }

    func test_makeSystemInfo_documentsPrivacyPolicy() {
        // Bundle text should announce that nothing was uploaded automatically.
        let info = DiagnosticBundleExporter.makeSystemInfo()
        XCTAssertTrue(info.lowercased().contains("no cloud upload")
                      || info.lowercased().contains("offline"),
                      "system-info should declare privacy posture for beta testers")
    }
}
