import XCTest

final class BuildScreenshots: XCTestCase {
    let app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = true
        addUIInterruptionMonitor(withDescription: "System Dialog") { alert in
            alert.buttons.allElementsBoundByIndex.last?.tap()
            return true
        }
        app.launch()
        // Tap the app to trigger any queued interruption monitors
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        Thread.sleep(forTimeInterval: 0.5)
    }

    func test_00_HomeScreen() {
        Thread.sleep(forTimeInterval: 2.0)
        saveScreenshot("00_HomeScreen")
    }

    private func saveScreenshot(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let data = screenshot.pngRepresentation
        let dir = URL(fileURLWithPath: "/tmp/build-screenshots")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? data.write(to: dir.appendingPathComponent("\(name).png"))
    }
}
