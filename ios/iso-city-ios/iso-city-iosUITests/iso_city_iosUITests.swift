//
//  iso_city_iosUITests.swift
//  iso-city-iosUITests
//
//  Created by Gregory O'Neill on 2/9/26.
//

import XCTest

final class iso_city_iosUITests: XCTestCase {

    @MainActor
    func testLaunchStartsInImplicitSelect() throws {
        let app = launchApp()
        waitForHUD(app)
        assertSelectedTool(app, equals: "select")
    }

    @MainActor
    func testPinToolShowsInHUDAndPersistsAcrossRelaunch() throws {
        var app = launchApp()
        waitForHUD(app)

        openToolSheet(app)
        tapPin(app, tool: "road")
        closeToolSheet(app)

        XCTAssertTrue(app.buttons["hud.pinned.road"].waitForExistence(timeout: 5))

        app.terminate()
        app = launchApp()
        waitForHUD(app)
        XCTAssertTrue(app.buttons["hud.pinned.road"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testPinnedToolTogglesBackToSelect() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting"]
        app.launch()
        waitForHUD(app)

        ensurePinned(app, tool: "road")
        let roadButton = app.buttons["hud.pinned.road"]
        XCTAssertTrue(roadButton.waitForExistence(timeout: 5))

        roadButton.tap()
        assertSelectedTool(app, equals: "road")

        roadButton.tap()
        assertSelectedTool(app, equals: "select")
    }

    @MainActor
    func testPinnedToolsLimitAtFour() throws {
        let app = launchApp()
        waitForHUD(app)

        openToolSheet(app)
        tapPin(app, tool: "road")
        tapPin(app, tool: "rail")
        tapPin(app, tool: "bulldoze")
        tapPin(app, tool: "zone_residential")

        let fifthPin = app.buttons["toolSheet.pin.zone_commercial"]
        XCTAssertTrue(fifthPin.waitForExistence(timeout: 5))
        XCTAssertFalse(fifthPin.isEnabled)
        closeToolSheet(app)

        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'hud.pinned.'")).count, 4)
    }

    @MainActor
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting"]
        app.launch()
        return app
    }

    @MainActor
    private func waitForHUD(_ app: XCUIApplication) {
        XCTAssertTrue(app.buttons["hud.more"].waitForExistence(timeout: 25))
    }

    @MainActor
    private func openToolSheet(_ app: XCUIApplication) {
        app.buttons["hud.more"].tap()
        XCTAssertTrue(app.otherElements["toolSheet"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func closeToolSheet(_ app: XCUIApplication) {
        let done = app.buttons["toolSheet.done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        done.tap()
    }

    @MainActor
    private func tapPin(_ app: XCUIApplication, tool: String) {
        let pinButton = app.buttons["toolSheet.pin.\(tool)"]
        XCTAssertTrue(pinButton.waitForExistence(timeout: 5))
        XCTAssertTrue(pinButton.isEnabled)
        pinButton.tap()
    }

    @MainActor
    private func ensurePinned(_ app: XCUIApplication, tool: String) {
        if app.buttons["hud.pinned.\(tool)"].exists {
            return
        }
        openToolSheet(app)
        tapPin(app, tool: tool)
        closeToolSheet(app)
        XCTAssertTrue(app.buttons["hud.pinned.\(tool)"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func assertSelectedTool(_ app: XCUIApplication, equals value: String) {
        let selectedToolProbe = app.otherElements["hud.selectedTool"]
        XCTAssertTrue(selectedToolProbe.waitForExistence(timeout: 5))
        XCTAssertEqual(selectedToolProbe.label, value)
    }
}
