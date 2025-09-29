//
//  SonoraUITests.swift
//  SonoraUITests
//
//  Created by Samuel Kahessay on 2025-08-23.
//

import XCTest

final class SonoraUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    @MainActor
    func testTabNavigationDuringTitleGeneration() throws {
        let app = XCUIApplication()
        app.launch()

        let tabBar = app.tabBars
        let recordButton = tabBar.buttons["Record"]
        let memosButton = tabBar.buttons["Memos"]

        XCTAssertTrue(recordButton.waitForExistence(timeout: 2))
        XCTAssertTrue(memosButton.waitForExistence(timeout: 2))

        memosButton.tap()
        recordButton.tap()
    }
}
