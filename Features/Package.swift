// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Features",
    platforms: [
        .iOS(.v26),
        .watchOS(.v26),
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
        .library(
            name: "WatchFeatures",
            targets: ["WatchFeatures"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/pointfreeco/swift-composable-architecture",
            exact: "1.23.2"
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
                "Core",
                "Common",
                "Domain",
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
                "Domain",
                .dependencies,
            ],
            path: "Sources",
            // Sources/Application holds the UseCase+Live orchestrators
            // per docs/architecture.md §8. Kept inside the Core target
            // for now (Phase 6.4 decision) to avoid a target-explosion
            // refactor; a future split can convert Application into its
            // own target depending on Core.
            sources: ["Core", "Application"]
        ),
        .target(name: "Common", dependencies: ["Domain"]),
        // WatchFeatures: watchOS-only target. Intentionally does NOT depend
        // on Core — Core carries iOS-only SwiftData/CloudKit code that
        // would force a platform-conditional rewrite. Watch-side live
        // client implementations and the WatchSessionGateway live here
        // and only need Domain + Common (design tokens) + TCA.
        .target(
            name: "WatchFeatures",
            dependencies: [
                .tca,
                "Domain",
                "Common",
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)

extension Target.Dependency {
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
