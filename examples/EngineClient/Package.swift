// swift-tools-version: 5.10
import PackageDescription
let package = Package(name: "EngineClient", platforms: [.macOS(.v14)], dependencies: [.package(path: "../..")], targets: [
    .executableTarget(name: "EngineClient", dependencies: [.product(name: "WorkflowCore", package: "shortcutstudio")])
])
