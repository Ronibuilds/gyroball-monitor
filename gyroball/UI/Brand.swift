import SwiftUI
import AppKit

/// Loads the bundled Gyroball icon for in-app use. The SwiftPM executable
/// target has no asset catalog / Bundle.module, so we load the loose
/// Gyroball.icns from the app bundle's Resources (copied in by run.sh /
/// release.sh), falling back to the running app's own icon.
enum Brand {
    static let logo: Image = {
        if let url = Bundle.main.url(forResource: "Gyroball", withExtension: "icns"),
           let ns = NSImage(contentsOf: url) {
            return Image(nsImage: ns)
        }
        return Image(nsImage: NSApp.applicationIconImage)
    }()
}
