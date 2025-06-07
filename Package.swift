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
            name: "SwiftDataSQL",
            targets: [
                "SwiftDataSQL",
                "SwiftDataSQL_MariaDB",
                "SwiftDataMariaDB_Connector"
            ]
        ),
    ],
    targets: [
        .binaryTarget(
            name: "CMariaDBClient",
            path: "Frameworks/libmariadbclient.xcframework"
        ),
        .target(
            name: "SwiftDataSQL_MariaDB",
            dependencies: [ "CMariaDBClient" ],
            path: "Sources/SwiftDataSQL_MariaDB", // This directory should now ONLY contain Swift files/subdirs
            // If PrivateCModule_Private was moved OUTSIDE of Sources/SwiftDataSQL_MariaDB/,
            // then excluding it here is not strictly needed for this path, but doesn't hurt.
            // The key is that SPM doesn't find .c/.h files when scanning Sources/SwiftDataSQL_MariaDB/.
            // If you still have other .h files like SwiftDataSQL_MariaDB.h (auto-generated for Obj-C header)
            // directly in Sources/SwiftDataSQL_MariaDB/, that's usually fine as SPM handles those.
            // The problem is user-provided .c/.h files mixed with .swift.
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .target(
            name: "SwiftDataSQL",
            dependencies: [ "SwiftDataSQL_MariaDB" ],
            path: "Sources/SwiftDataSQL",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .target(
            name: "SwiftDataMariaDB_Connector",
            dependencies: [ "SwiftDataSQL" ],
            path: "Sources/SwiftDataMariaDB_Connector",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
