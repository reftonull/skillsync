// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "skillsync",
  platforms: [
    .macOS(.v15)
  ],
  products: [
    .executable(name: "skillsync", targets: ["skillsync"]),
    .library(name: "SkillSyncCLI", targets: ["SkillSyncCLI"]),
    .library(name: "SkillSyncCore", targets: ["SkillSyncCore"]),
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
    .package(url: "https://github.com/pointfreeco/swift-concurrency-extras", from: "1.0.0"),
    .package(url: "https://github.com/pointfreeco/swift-custom-dump", from: "1.0.0"),
    .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.0.0"),
    .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.18.9"),
    .package(url: "https://github.com/apple/swift-crypto", from: "3.0.0"),
  ],
  targets: [
    .executableTarget(
      name: "skillsync",
      dependencies: [
        "SkillSyncCLI"
      ],
      swiftSettings: [
        .enableUpcomingFeature("NonisolatedNonsendingByDefault")
      ]
    ),
    .target(
      name: "SkillSyncCLI",
      dependencies: [
        "SkillSyncCore",
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "Dependencies", package: "swift-dependencies"),
      ],
      swiftSettings: [
        .enableUpcomingFeature("NonisolatedNonsendingByDefault")
      ]
    ),
    .target(
      name: "SkillSyncCore",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "CustomDump", package: "swift-custom-dump"),
        .product(name: "Crypto", package: "swift-crypto", condition: .when(platforms: [.linux])),
      ],
      resources: [
        .copy("Resources/BuiltInSkills")
      ],
      swiftSettings: [
        .enableUpcomingFeature("NonisolatedNonsendingByDefault")
      ]
    ),
    .testTarget(
      name: "SkillSyncTests",
      dependencies: [
        "SkillSyncCLI",
        "SkillSyncCore",
        .product(name: "ConcurrencyExtras", package: "swift-concurrency-extras"),
        .product(name: "CustomDump", package: "swift-custom-dump"),
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "DependenciesTestSupport", package: "swift-dependencies"),
        .product(name: "InlineSnapshotTesting", package: "swift-snapshot-testing"),
      ],
      path: "Tests",
      swiftSettings: [
        .enableUpcomingFeature("NonisolatedNonsendingByDefault")
      ]
    ),
  ],
  swiftLanguageModes: [.v6]
)
