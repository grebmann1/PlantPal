import XCTest

final class BuildScreenshots: XCTestCase {
    let app = XCUIApplication()
    private let outputDirectory = URL(fileURLWithPath: "/tmp/plantpal-readme-screenshots")

    override func setUp() {
        continueAfterFailure = false
        addUIInterruptionMonitor(withDescription: "System Dialog") { alert in
            alert.buttons.allElementsBoundByIndex.last?.tap()
            return true
        }
        app.launchArguments = ["-uiScreenshotDemo"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Garden"].waitForExistence(timeout: 8))
    }

    func test_00_Garden() {
        saveScreenshot("garden")
    }

    func test_01_PlantDetail() {
        let plant = app.buttons["plant-detail-Kevin"]
        XCTAssertTrue(plant.waitForExistence(timeout: 5))
        plant.tap()
        XCTAssertTrue(staticText("Plant Detail").waitForExistence(timeout: 5))
        saveScreenshot("plant-detail")
    }

    func test_02_Reminders() {
        selectTab("Water")
        XCTAssertTrue(element("reminders-screen").waitForExistence(timeout: 5))
        saveScreenshot("reminders")
    }

    func test_03_GuideLibrary() {
        openGuideLibrary()
        saveScreenshot("guide-library")
    }

    func test_04_GuideArticle() {
        openGuideLibrary()
        let guide = app.buttons["guide-finger-test"]
        XCTAssertTrue(guide.waitForExistence(timeout: 5))
        guide.tap()
        XCTAssertTrue(element("guide-article-screen").waitForExistence(timeout: 5))
        saveScreenshot("guide-article")
    }

    func test_05_FieldCapture() {
        selectTab("Scan")
        XCTAssertTrue(element("scan-screen").waitForExistence(timeout: 5))
        saveScreenshot("field-capture")
    }

    private func openGuideLibrary() {
        selectTab("Discover")
        let guides = app.buttons["discover-guides"]
        XCTAssertTrue(guides.waitForExistence(timeout: 5))
        guides.tap()
        XCTAssertTrue(element("guide-library-screen").waitForExistence(timeout: 5))
    }

    private func selectTab(_ name: String) {
        let tab = app.tabBars.buttons[name]
        XCTAssertTrue(tab.waitForExistence(timeout: 5), "Missing \(name) tab")
        tab.tap()
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    private func staticText(_ label: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    private func saveScreenshot(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let data = screenshot.pngRepresentation
        try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        try? data.write(to: outputDirectory.appendingPathComponent("\(name).png"))
    }
}
