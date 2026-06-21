// swift-tools-version: 6.2

import Foundation
import PackageDescription

let developerDir = ProcessInfo.processInfo.environment["DEVELOPER_DIR"] ?? "/Library/Developer/CommandLineTools"
let testingFrameworkDirs = [
    "\(developerDir)/Library/Developer/Frameworks",
    "\(developerDir)/Platforms/MacOSX.platform/Developer/Library/Frameworks"
]
let testingMacroPlugins = [
    "\(developerDir)/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib",
    "\(developerDir)/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib"
]

let testingSwiftSettings: [SwiftSetting] = {
    let fileManager = FileManager.default
    guard let frameworkDir = testingFrameworkDirs.first(where: {
        fileManager.fileExists(atPath: "\($0)/Testing.framework")
    }) else {
        return []
    }
    guard let macroPlugin = testingMacroPlugins.first(where: {
        fileManager.fileExists(atPath: $0)
    }) else {
        return [.unsafeFlags(["-F", frameworkDir])]
    }
    return [.unsafeFlags(["-F", frameworkDir, "-load-plugin-library", macroPlugin])]
}()

let testingLinkerSettings: [LinkerSetting] = {
    let fileManager = FileManager.default
    guard let frameworkDir = testingFrameworkDirs.first(where: {
        fileManager.fileExists(atPath: "\($0)/Testing.framework")
    }) else {
        return []
    }
    return [.unsafeFlags(["-F", frameworkDir, "-framework", "Testing", "-Xlinker", "-rpath", "-Xlinker", frameworkDir])]
}()

let package = Package(
    name: "PhotosMCP",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .executable(name: "PhotosMCP", targets: ["PhotosMCP"])
    ],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.10.0")
    ],
    targets: [
        .executableTarget(
            name: "PhotosMCP",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk")
            ],
            path: "Sources/PhotosMCP",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
                .unsafeFlags(["-parse-as-library"])
            ]
        ),
        .testTarget(
            name: "PhotosMCPTests",
            dependencies: ["PhotosMCP"],
            swiftSettings: testingSwiftSettings,
            linkerSettings: testingLinkerSettings
        )
    ]
)
