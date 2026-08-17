import Foundation

/// Demo garden plants and offline AI fallbacks are for Simulator testing only.
enum DemoContent {
    static let screenshotGuestUserId = UUID(uuidString: "6D6578A6-6D88-4D24-8DFE-3A2B453E1D01")!

    static var isScreenshotMode: Bool {
        ProcessInfo.processInfo.arguments.contains("-uiScreenshotDemo")
    }

    static var isEnabled: Bool {
        #if targetEnvironment(simulator)
        true
        #else
        false
        #endif
    }
}
