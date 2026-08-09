import Foundation

/// Demo garden plants and offline AI fallbacks are for Simulator testing only.
enum DemoContent {
    static var isEnabled: Bool {
        #if targetEnvironment(simulator)
        true
        #else
        false
        #endif
    }
}
