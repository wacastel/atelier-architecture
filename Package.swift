// swift-tools-version: 5.10
import PackageDescription
let package = Package(name: "ArchitectureEngine", platforms: [.macOS(.v14)], products: [.executable(name: "ArchitectureEngine", targets: ["ArchitectureEngine"])], targets: [.executableTarget(name: "ArchitectureEngine", resources: [.copy("Resources")], linkerSettings: [.linkedFramework("Metal"), .linkedFramework("MetalKit"), .linkedFramework("AppKit"), .linkedFramework("SwiftUI"), .linkedFramework("AVFoundation")])])
