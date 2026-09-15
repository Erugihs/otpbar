// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OTPBar",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "OTPBarCore", targets: ["OTPBarCore"]),
        .executable(name: "OTPBar", targets: ["OTPBarApp"])
    ],
    targets: [
        .target(name: "OTPBarCore"),
        .executableTarget(name: "OTPBarApp", dependencies: ["OTPBarCore"]),
        .testTarget(name: "OTPBarAppTests", dependencies: ["OTPBarApp", "OTPBarCore"]),
        .testTarget(name: "OTPBarCoreTests", dependencies: ["OTPBarCore"], resources: [.copy("Fixtures")])
    ]
)
