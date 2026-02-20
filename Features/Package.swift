// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Features",
    platforms: [
        .iOS(.v26)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Features",
            targets: ["Features"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", exact: "1.23.1")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Features",
            dependencies: [
                .tca,
                "DesignSystem"
            ]
        ),
        .target(
            name: "DesignSystem",
            dependencies: []
        ),
        .testTarget(
            name: "FeaturesTests",
            dependencies: ["Features", .tca]
        ),
    ]
)

extension Target.Dependency {
    static let tca: Target.Dependency = .product(
        name: "ComposableArchitecture",
        package: "swift-composable-architecture"
    )
}
