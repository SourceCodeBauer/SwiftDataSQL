// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "SwiftDataSQL",
    platforms: [
        .macOS(.v15), // Note: You had .v11 before, now .v15. Ensure this is intentional.
        .iOS(.v14)
    ],
    products: [
        .library(
            name: "SwiftDataSQL",
            // These should be the names of your SWIFT targets that provide the public API
            targets: ["SwiftDataSQL_Target", "SwiftDataSQL_MariaDB_Target", "SwiftDataMariaDB_Connector_Target"]
        ),
    ],
    targets: [
        // 1. Binary Target for the XCFramework
        .binaryTarget(
            name: "CMariaDBClient", // This is the module name from the XCFramework's module.modulemap
            path: "Frameworks/libmariadbclient.xcframework" // Path relative to Package.swift
            // Or, if hosting remotely:
            // url: "https://your_server.com/path/to/libmariadbclient.xcframework.zip",
            // checksum: "sha256_checksum_of_the_zip_file"
        ),

        // 2. Your Swift target that directly uses the C library
        .target(
            name: "SwiftDataSQL_MariaDB_Target", // Use a distinct name for the target
            dependencies: [
                "CMariaDBClient" // Depends on the XCFramework
            ],
            path: "Sources/SwiftDataSQL_MariaDB", // Path to this target's sources
            // NO unsafe linkerSettings needed anymore
            // NO CPrivateMariaDBHeaders dependency needed anymore
            // NO exclude for PrivateCModule_Private needed if it's not part of this target's sources
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),

        // 3. Your main SwiftDataSQL logic target
        .target(
            name: "SwiftDataSQL_Target", // Use a distinct name for the target
            dependencies: ["SwiftDataSQL_MariaDB_Target"],
            path: "Sources/SwiftDataSQL", // Path to this target's sources
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),

        // 4. Your SwiftData connector target
        .target(
            name: "SwiftDataMariaDB_Connector_Target", // Use a distinct name for the target
            dependencies: ["SwiftDataSQL_Target"], // Or directly on SwiftDataSQL_MariaDB_Target if appropriate
            path: "Sources/SwiftDataMariaDB_Connector", // Path to this target's sources
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
