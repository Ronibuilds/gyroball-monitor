// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "gyroball",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "gyroball",
            path: "gyroball",
            exclude: [
                "Info.plist",
                "gyroball.entitlements"
            ]
        )
    ]
)
