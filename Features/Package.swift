// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Features",
    platforms: [
        .iOS(.v26),
        .macOS(.v15)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Features",
            targets: ["Features"]
        ),
        .library(
            name: "Domain",
            targets: ["Domain"]
        ),
        .library(
            name: "Core",
            targets: ["Core"]
        ),
        .library(
            name: "Common",
            targets: ["Common"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/pointfreeco/swift-composable-architecture",
            exact: "1.23.1"
        ),
        .package(
            url: "https://github.com/pointfreeco/swift-dependencies",
            exact: "1.11.0"
        ),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Features",
            dependencies: [
                .tca,
                .common,
                .domain,
            ]
        ),
        .target(
            name: "Domain",
            dependencies: [
                .dependencies,
                .dependenciesMacros,
            ]
        ),
        .target(
            name: "Core",
            dependencies: [
                .domain,
                .dependencies,
            ]
        ),
        .target(name: "Common", dependencies: []),
        .testTarget(
            name: "FeaturesTests",
            dependencies: ["Features", .tca],
            path: "Tests/FeaturesTests",
            sources: ["FeaturesTests.swift"]
        ),
        .testTarget(
            name: "CommonTests",
            dependencies: [.common],
            path: "Tests/FeaturesTests/CommonTests"
        ),
        .testTarget(
            name: "CoreTests",
            dependencies: [.core, .domain],
            path: "Tests/FeaturesTests/CoreTests"
        ),
        .testTarget(
            name: "DomainTests",
            dependencies: [.domain],
            path: "Tests/FeaturesTests/DomainTests"
        ),
    ]
)

extension Target.Dependency {
    static let common: Target.Dependency = .target(name: "Common")
    static let domain: Target.Dependency = .target(name: "Domain")
    static let core: Target.Dependency = .target(name: "Core")
    
    static let dependencies: Target.Dependency = .product(
        name: "Dependencies",
        package: "swift-dependencies"
    )
    static let dependenciesMacros: Target.Dependency = .product(
        name: "DependenciesMacros",
        package: "swift-dependencies"
    )
    static let tca: Target.Dependency = .product(
        name: "ComposableArchitecture",
        package: "swift-composable-architecture"
    )
}
