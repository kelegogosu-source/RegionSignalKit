// swift-tools-version:5.7
import PackageDescription
let package = Package(name: "RegionSignalKit", platforms: [.iOS(.v15)], products: [
    .library(name: "RegionSignalKit", targets: ["RegionSignalKit"])
], targets: [
    .target(name: "RegionSignalKit"),
    .testTarget(name: "RegionSignalKitTests", dependencies: ["RegionSignalKit"])
])
