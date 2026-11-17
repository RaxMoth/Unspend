// swift-tools-version:5.9
//
// This package exists only so the Foundation-only rule engine can be unit
// tested on the Mac in seconds:
//
//     swift test --package-path ios/Shared
//
// The Xcode project does NOT depend on it. The same source files under
// Sources/ShieldCore are compiled directly into the Runner, FocusMonitor and
// ShieldConfigurationExtension targets (see tools/ios_project.rb).
import PackageDescription

let package = Package(
    name: "ShieldCore",
    platforms: [.macOS(.v13), .iOS(.v16)],
    products: [
        .library(name: "ShieldCore", targets: ["ShieldCore"]),
    ],
    targets: [
        .target(name: "ShieldCore", path: "Sources/ShieldCore"),
        .testTarget(
            name: "ShieldCoreTests",
            dependencies: ["ShieldCore"],
            path: "Tests/ShieldCoreTests"
        ),
    ]
)
