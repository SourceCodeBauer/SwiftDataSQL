# SwiftDataSQL

**SwiftDataSQL** is a Swift package designed to facilitate interaction with **MariaDB** databases from Swift applications.
A key feature is its demonstration of how to integrate pre-compiled C static libraries (specifically, `libmariadbclient`)
for different platforms (**macOS**, **iOS**) into a Swift Package Manager (SPM) project.

This package provides a Swift layer (`Perfect_MariaDB`) that uses a C wrapper module (`CPrivateMariaDBHeaders`)
to interface with the MariaDB C client library.

---

## ✨ Features

- **MariaDB Connectivity:**
  Enables Swift applications to connect to and interact with MariaDB servers.

- **Cross-Platform Static Library Integration:**
  Showcases a robust method for linking platform-specific static C libraries (`.a` files) for macOS and iOS.

- **SPM C Module Wrapper:**
  Uses a dedicated C target (`CPrivateMariaDBHeaders`) with a `module.modulemap` and an umbrella header
  to expose MariaDB C client headers (`mysql.h`, `errmsg.h`, etc.) to Swift code in a clean, modular way.

- **Swift Abstraction Layer:**
  The `Perfect_MariaDB` target provides a Swift-friendly interface over the underlying C API.

- **Platform Support:**
  - macOS 11.0+
  - iOS 14.0+

---

## 📋 Requirements

- Swift **6.1+** (`swift-tools-version: 6.1`)
- Xcode (latest version compatible with Swift 6.1 recommended)
- MariaDB C client static libraries:
  - `libmariadbclient-ios.a`
  - `libmariadbclient-macos.a`

*(These are currently expected to be included within the package source at
`Sources/Perfect_MariaDB/PrivateCModule_Private/libs/`)*

---

## 📦 Installation

To use SwiftDataSQL (which provides the `Perfect_MariaDB` module) in your Swift package,
add it as a dependency in your `Package.swift` file:

```swift
// In your Package.swift
dependencies: [
    .package(url: "https://github.com/your-username/SwiftDataSQL.git", from: "0.0.3")
],
targets: [
    .target(
        name: "YourAppTarget",
        dependencies: [
            .product(name: "SwiftDataSQL", package: "SwiftDataSQL")
            // Through the "SwiftDataSQL" product, you get access to "Perfect_MariaDB"
        ]
    ),
]
```

---

## 🧱 Package Structure and C Interoperability

### `CPrivateMariaDBHeaders` (C Target)

**Path:** `Sources/Perfect_MariaDB/PrivateCModule_Private/`

This target is responsible for exposing the MariaDB C client headers. It contains:

- `PrivateCModule.h`: An umbrella header that includes all necessary MariaDB C headers (e.g., `mysql.h`, `errmsg.h`).
  These headers are included using `""` (e.g., `#import "mysql.h"`) as they reside in the same directory.
- `module.modulemap`: Defines the Swift module `CPrivateMariaDBHeaders` and points to `PrivateCModule.h` as its umbrella header.
- `dummy.c`: An empty C file to ensure SPM correctly processes this as a C-language target.
- The actual MariaDB C header files (`.h`).
- The `libs/` subdirectory containing the static libraries (`.a` files).

The `Package.swift` defines this target and its path. `publicHeadersPath` is set to `"."` relative to its path.

---

### `Perfect_MariaDB` (Swift Target)

This target contains Swift code providing a user-friendly API for MariaDB operations.

- Declares a dependency on the `CPrivateMariaDBHeaders` target, allowing Swift to import and use the C functions and types.
- Excludes the `PrivateCModule_Private/` directory from its own sources to avoid conflicts.
- Uses `linkerSettings` with `.unsafeFlags` to link against the appropriate static MariaDB client library (`libmariadbclient-ios.a` or `libmariadbclient-macos.a`) depending on the platform.

---

### `SwiftDataSQL` (Main Swift Target & Product)

This is the main library target and product.

- Depends on `Perfect_MariaDB`.
- Users of this package will typically depend on the `SwiftDataSQL` product to access all functionality.

This setup ensures C headers are modularized and accessible to Swift, and the correct static library is linked per platform.

---

## 📚 Managing MariaDB Client Libraries

The MariaDB C client static libraries (`libmariadbclient-ios.a`, `libmariadbclient-macos.a`)
are currently included directly within:

```
Sources/Perfect_MariaDB/PrivateCModule_Private/libs/
```


## 📄 License

This project is licensed under the terms of the BSD 3-Clause License.
See the `LICENSE` file for more details.
