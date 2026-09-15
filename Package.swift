// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OTPBar",
    platforms: [.macOS(.v14)],
    products: [.library(name: "OTPBarCore", targets: ["OTPBarCore"])],
    targets: [
        .target(name: "OTPBarCore"),
        .testTarget(name: "OTPBarCoreTests", dependencies: ["OTPBarCore"], resources: [.copy("Fixtures")])
    ]
)
