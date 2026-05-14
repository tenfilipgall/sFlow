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
        XCTAssertTrue(ClickWatcher.shouldRunNonInteractiveLayers(role: "AXGroup", depth: 0, hasAXPress: false))
        XCTAssertTrue(ClickWatcher.shouldRunNonInteractiveLayers(role: "AXWindow", depth: 0, hasAXPress: false))
        XCTAssertTrue(ClickWatcher.shouldRunNonInteractiveLayers(role: "AXScrollArea", depth: 0, hasAXPress: false))
    }

    func test_deeperDepth_allowsInteractiveRolesOnly() {
        XCTAssertTrue(ClickWatcher.shouldRunNonInteractiveLayers(role: "AXButton", depth: 1, hasAXPress: false))
        XCTAssertTrue(ClickWatcher.shouldRunNonInteractiveLayers(role: "AXMenuItem", depth: 2, hasAXPress: false))
        XCTAssertTrue(ClickWatcher.shouldRunNonInteractiveLayers(role: "AXTextField", depth: 3, hasAXPress: false))
        XCTAssertTrue(ClickWatcher.shouldRunNonInteractiveLayers(role: "AXSearchField", depth: 4, hasAXPress: false))
    }

    func test_deeperDepth_blocksStructuralRoles() {
        XCTAssertFalse(ClickWatcher.shouldRunNonInteractiveLayers(role: "AXGroup", depth: 1, hasAXPress: false))
        XCTAssertFalse(ClickWatcher.shouldRunNonInteractiveLayers(role: "AXWindow", depth: 2, hasAXPress: false))
        XCTAssertFalse(ClickWatcher.shouldRunNonInteractiveLayers(role: "AXScrollArea", depth: 3, hasAXPress: false))
        XCTAssertFalse(ClickWatcher.shouldRunNonInteractiveLayers(role: "AXImage", depth: 1, hasAXPress: false))
        XCTAssertFalse(ClickWatcher.shouldRunNonInteractiveLayers(role: "AXStaticText", depth: 2, hasAXPress: false))
    }

    func test_unknownRole_atDepthZero_allowed() {
        XCTAssertTrue(ClickWatcher.shouldRunNonInteractiveLayers(role: "AXSomeNewRole", depth: 0, hasAXPress: false))
    }

    func test_unknownRole_atDepthOnePlus_blocked() {
        XCTAssertFalse(ClickWatcher.shouldRunNonInteractiveLayers(role: "AXSomeNewRole", depth: 1, hasAXPress: false))
    }

    // MARK: - AXPress probe (Coverage QW Fix 1)

    func test_axPress_overridesNonInteractiveRoleAtDepthZero() {
        // Depth 0 always allowed regardless — but verify hasAXPress flag doesn't break
        XCTAssertTrue(ClickWatcher.shouldRunNonInteractiveLayers(role: "AXImage", depth: 0, hasAXPress: true))
        XCTAssertTrue(ClickWatcher.shouldRunNonInteractiveLayers(role: "AXImage", depth: 0, hasAXPress: false))
    }

    func test_axPress_allowsStructuralRoleAtDeeperDepth() {
        // AXImage/AXGroup/AXStaticText with AXPress should be treated as interactive
        XCTAssertTrue(ClickWatcher.shouldRunNonInteractiveLayers(role: "AXImage", depth: 1, hasAXPress: true))
        XCTAssertTrue(ClickWatcher.shouldRunNonInteractiveLayers(role: "AXGroup", depth: 2, hasAXPress: true))
        XCTAssertTrue(ClickWatcher.shouldRunNonInteractiveLayers(role: "AXStaticText", depth: 3, hasAXPress: true))
    }

    func test_noAxPress_stillBlocksStructuralAtDepth() {
        // Sanity: without AXPress, structural roles at depth>0 stay blocked
        XCTAssertFalse(ClickWatcher.shouldRunNonInteractiveLayers(role: "AXImage", depth: 1, hasAXPress: false))
        XCTAssertFalse(ClickWatcher.shouldRunNonInteractiveLayers(role: "AXGroup", depth: 1, hasAXPress: false))
    }
}
