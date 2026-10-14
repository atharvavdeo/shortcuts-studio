// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ShortcutStudio",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "WorkflowCore", targets: ["WorkflowCore"]),
        .executable(name: "ShortcutStudio", targets: ["ShortcutStudio"])
    ],
    targets: [
        .target(name: "WorkflowCore"),
        .executableTarget(name: "ShortcutStudio", dependencies: ["WorkflowCore"]),
        .testTarget(name: "WorkflowCoreTests", dependencies: ["WorkflowCore"])
    ]
)
