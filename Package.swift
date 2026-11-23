// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

// Same sources and platform as CYLDeallocBlockExecutor.podspec, so CYLTabBarController can depend on it through
// Swift Package Manager as it does through CocoaPods.
let package = Package(
    name: "CYLDeallocBlockExecutor",
    platforms: [
        .iOS(.v15),
    ],
    products: [
        .library(name: "CYLDeallocBlockExecutor", targets: ["CYLDeallocBlockExecutor"]),
    ],
    targets: [
        .target(
            name: "CYLDeallocBlockExecutor",
            path: "CYLDeallocBlockExecutor"
        ),
    ]
)
