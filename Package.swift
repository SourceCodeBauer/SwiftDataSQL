// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "SwiftDataSQL",
    platforms: [
        .macOS(.v15),
        .iOS(.v14)
    ],
    products: [
        .library(
            name: "SwiftDataSQL", // Product name
            targets: ["SwiftDataSQL", "SwiftDataSQL_MariaDB", "SwiftDataMariaDB_Connector"] // Original target names
        ),
    ],
    targets: [
        // This C target is now replaced by the binaryTarget
        // .target(
        //     name: "CPrivateMariaDBHeaders",
        //     path: "Sources/SwiftDataSQL_MariaDB/PrivateCModule_Private",
        //     publicHeadersPath: "."
        // ),

        .target(
            name: "SwiftDataSQL_MariaDB", // Original target name
            dependencies: [
                // .target(name: "CPrivateMariaDBHeaders") // Old dependency
            ],
            // exclude: [ "PrivateCModule_Private/", ], // Still good to exclude if dir exists but not for SPM
            // linkerSettings: [ ... ] // These are removed
        ),
        .target(
            name: "SwiftDataSQL", // Original target name
            dependencies: ["SwiftDataSQL_MariaDB"]
        ),
        .target(
            name: "SwiftDataMariaDB_Connector", // Original target name
            dependencies: [ "SwiftDataSQL"]
        )
    ]
)
