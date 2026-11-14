// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "swift-particles",
    platforms: [.macOS(.v27), .iOS(.v27), .tvOS(.v27), .watchOS(.v27), .visionOS(.v27)],
    products: [
        .library(name: "Particles", targets: ["Particles"])
    ],
    traits: [
        .trait(name: "Threads", description: "Picture CPU draws on several threads, as swift-picture's own Threads trait")
    ],
    dependencies: [
        .package(url: "https://github.com/swift-atoms/swift-ballistics.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-numeric.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-rational.git", branch: "main"),
        .package(
            url: "https://github.com/swift-compositions/swift-picture.git",
            branch: "main",
            traits: [.trait(name: "Threads", condition: .when(traits: ["Threads"]))]
        ),
        .package(url: "https://github.com/swift-atoms/swift-standard-library-extensions.git", branch: "main"),
        .package(url: "https://github.com/swift-molecules/swift-timeline.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "Particles",
            dependencies: [
                .product(name: "Ballistics", package: "swift-ballistics"),
                .product(name: "Numeric", package: "swift-numeric"),
                .product(name: "Picture", package: "swift-picture"),
                .product(name: "Rational", package: "swift-rational"),
                .product(name: "Standard Library Extensions", package: "swift-standard-library-extensions"),
                .product(name: "Timeline", package: "swift-timeline"),
            ]
        ),
        .testTarget(
            name: "Particles Tests",
            dependencies: [
                .target(name: "Particles"),
                .product(name: "Numeric", package: "swift-numeric"),
                .product(name: "Picture CPU", package: "swift-picture"),
                .product(name: "Standard Library Extensions", package: "swift-standard-library-extensions"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    target.swiftSettings =
        (target.swiftSettings ?? []) + [
            .strictMemorySafety(),
            .enableUpcomingFeature("ExistentialAny"),
            .enableUpcomingFeature("InternalImportsByDefault"),
            .enableUpcomingFeature("MemberImportVisibility"),
            .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
            .enableUpcomingFeature("InferIsolatedConformances"),
            .enableExperimentalFeature("Lifetimes"),
            .treatAllWarnings(as: .error),
        ]
}
