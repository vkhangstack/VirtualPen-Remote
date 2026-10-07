// swift-tools-version:5.9
import Foundation
import PackageDescription

// Embed Info.plist into the binary so macOS shows the Bluetooth permission prompt
// instead of killing an unbundled CLI that touches CoreBluetooth.
let infoPlist = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Info.plist").path

let package = Package(
    name: "PPTReceiver",
    platforms: [.macOS(.v12)],
    targets: [
        .executableTarget(
            name: "PPTReceiver",
            path: "Sources/PPTReceiver",
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-sectcreate", "-Xlinker", "__TEXT", "-Xlinker", "__info_plist", "-Xlinker", infoPlist]),
            ]
        ),
    ]
)
