import XCTest
@testable import SFlow

final class ClickWatcherLayerGateTests: XCTestCase {

    // Tests for ClickWatcher.shouldRunNonInteractiveLayers(role:depth:)
    //
    // Contract:
    //   - depth == 0 → always true (the hit-tested element)
    //   - depth > 0 and role is in interactiveRoles → true
    //   - depth > 0 and role is NOT in interactiveRoles → false
    //
    // L0 (AXKeyShortcuts) ignores this gate — checked separately.
    // L2 (AXHelp) already has its own gate; not touched here.

    func test_depthZero_alwaysAllowsLayers() {
        XCTAssertTrue(ClickWatcher.shouldRunNonInteractiveLayers(role: "AXGroup", depth: 0))
        XCTAssertTrue(ClickWatcher.shouldRunNonInteractiveLayers(role: "AXWindow", depth: 0))
        XCTAssertTrue(ClickWatcher.shouldRunNonInteractiveLayers(role: "AXScrollArea", depth: 0))
    }

    func test_deeperDepth_allowsInteractiveRolesOnly() {
        XCTAssertTrue(ClickWatcher.shouldRunNonInteractiveLayers(role: "AXButton", depth: 1))
        XCTAssertTrue(ClickWatcher.shouldRunNonInteractiveLayers(role: "AXMenuItem", depth: 2))
        XCTAssertTrue(ClickWatcher.shouldRunNonInteractiveLayers(role: "AXTextField", depth: 3))
        XCTAssertTrue(ClickWatcher.shouldRunNonInteractiveLayers(role: "AXSearchField", depth: 4))
    }

    func test_deeperDepth_blocksStructuralRoles() {
        XCTAssertFalse(ClickWatcher.shouldRunNonInteractiveLayers(role: "AXGroup", depth: 1))
        XCTAssertFalse(ClickWatcher.shouldRunNonInteractiveLayers(role: "AXWindow", depth: 2))
        XCTAssertFalse(ClickWatcher.shouldRunNonInteractiveLayers(role: "AXScrollArea", depth: 3))
        XCTAssertFalse(ClickWatcher.shouldRunNonInteractiveLayers(role: "AXImage", depth: 1))
        XCTAssertFalse(ClickWatcher.shouldRunNonInteractiveLayers(role: "AXStaticText", depth: 2))
    }

    func test_unknownRole_atDepthZero_allowed() {
        XCTAssertTrue(ClickWatcher.shouldRunNonInteractiveLayers(role: "AXSomeNewRole", depth: 0))
    }

    func test_unknownRole_atDepthOnePlus_blocked() {
        XCTAssertFalse(ClickWatcher.shouldRunNonInteractiveLayers(role: "AXSomeNewRole", depth: 1))
    }
}
