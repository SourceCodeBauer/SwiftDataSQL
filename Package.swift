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
            targets: ["SwiftDataSQL", "SwiftDataSQL_MariaDB", "SwiftDataMariaDB_Connector"]),
    ],
    targets: [
        .target(
            name: "CPrivateMariaDBHeaders",
            path: "Sources/SwiftDataSQL_MariaDB/PrivateCModule_Private",
            publicHeadersPath: "."
        ),

        .target(
            name: "SwiftDataSQL_MariaDB",
            dependencies: [
                .target(name: "CPrivateMariaDBHeaders")
            ],
            exclude: [
                "PrivateCModule_Private/",
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ],
            linkerSettings: [
                .unsafeFlags(["Sources/SwiftDataSQL_MariaDB/PrivateCModule_Private/libs/libmariadbclient-ios.a"],
                             .when(platforms: [.iOS])),
                .unsafeFlags(["Sources/SwiftDataSQL_MariaDB/PrivateCModule_Private/libs/libmariadbclient-macos.a"],
                             .when(platforms: [.macOS])),
            ]
        ),

        .target(
            name: "SwiftDataSQL",
            dependencies: ["SwiftDataSQL_MariaDB"],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .target(name: "SwiftDataMariaDB_Connector",
                dependencies: [ "SwiftDataSQL"] ,
                swiftSettings: [
                    .swiftLanguageMode(.v5)
                ]

               )
    ]
)
