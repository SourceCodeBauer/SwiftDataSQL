#!/bin/zsh
set -e

# --- Configuration ---
PACKAGE_ROOT=$(pwd)
XCFRAMEWORK_FILENAME="libmariadbclient"
SWIFT_MODULE_NAME="CMariaDBClient"
MARIADB_C_CONNECTOR_SRC_DIR="Sources/SwiftDataSQL_MariaDB/PrivateCModule_Private"
MARIADB_HEADERS_DIR="$PACKAGE_ROOT/$MARIADB_C_CONNECTOR_SRC_DIR"
MARIADB_LIBS_DIR="$PACKAGE_ROOT/$MARIADB_C_CONNECTOR_SRC_DIR/libs"

# This is your FAT iOS library (x86_64, arm64)
IOS_FAT_LIB_FILENAME="libmariadbclient-ios.a"
MACOS_FAT_LIB_FILENAME="libmariadbclient-macos.a" # Assuming fat (arm64, x86_64)

TEMP_BUILD_DIR="xcframework_build_temp"
XCFW_OUTPUT_DIR="Frameworks"
# --- End of Configuration ---

# ... (create_module_files function remains the same) ...
create_module_files() {
  local headers_dir="$1"
  local module_name_arg="$2"
  echo "Creating module.modulemap in $headers_dir for module $module_name_arg"
  cat << EOF > "$headers_dir/module.modulemap"
module $module_name_arg {
    umbrella header "$module_name_arg.h"
    export *
}
EOF
  echo "Creating umbrella header $module_name_arg.h in $headers_dir"
  cat << EOF > "$headers_dir/$module_name_arg.h"
#ifndef ${module_name_arg}_h
#define ${module_name_arg}_h
#include "mysql.h"
#include "errmsg.h"
#endif /* ${module_name_arg}_h */
EOF
}


# --- Script Start ---
echo "🚀 Starting build of $XCFRAMEWORK_FILENAME.xcframework..."
ABSOLUTE_TEMP_BUILD_DIR="$PACKAGE_ROOT/$TEMP_BUILD_DIR"
ABSOLUTE_XCFW_OUTPUT_DIR="$PACKAGE_ROOT/$XCFW_OUTPUT_DIR"

echo "🧹 Cleaning up old directories..."
rm -rf "$ABSOLUTE_TEMP_BUILD_DIR"
rm -rf "$ABSOLUTE_XCFW_OUTPUT_DIR/$XCFRAMEWORK_FILENAME.xcframework"
mkdir -p "$ABSOLUTE_XCFW_OUTPUT_DIR"
mkdir -p "$ABSOLUTE_TEMP_BUILD_DIR"

XCFW_ARGS=()

# --- Prepare Slices ---

# 1. iOS Simulator Slice (using your fat libmariadbclient-ios.a)
IOS_SIM_SLICE_DIR="$ABSOLUTE_TEMP_BUILD_DIR/ios-arm64_x86_64-simulator"
IOS_SIM_HEADERS_DIR="$IOS_SIM_SLICE_DIR/Headers"
echo "🛠️  Preparing slice for iOS Simulator (arm64, x86_64)..."
mkdir -p "$IOS_SIM_HEADERS_DIR"
cp "$MARIADB_LIBS_DIR/$IOS_FAT_LIB_FILENAME" "$IOS_SIM_SLICE_DIR/$XCFRAMEWORK_FILENAME.a"
find "$MARIADB_HEADERS_DIR" -maxdepth 1 -name "*.h" -exec cp {} "$IOS_SIM_HEADERS_DIR/" \;
create_module_files "$IOS_SIM_HEADERS_DIR" "$SWIFT_MODULE_NAME"
XCFW_ARGS+=(-library "$IOS_SIM_SLICE_DIR/$XCFRAMEWORK_FILENAME.a" -headers "$IOS_SIM_HEADERS_DIR")

# 2. iOS Device Slice (extracting arm64 from the fat iOS library)
IOS_DEVICE_SLICE_DIR="$ABSOLUTE_TEMP_BUILD_DIR/ios-arm64"
IOS_DEVICE_HEADERS_DIR="$IOS_DEVICE_SLICE_DIR/Headers"
IOS_DEVICE_THIN_LIB_PATH="$IOS_DEVICE_SLICE_DIR/$XCFRAMEWORK_FILENAME.a"
echo "🛠️  Preparing slice for iOS Device (arm64)..."
mkdir -p "$IOS_DEVICE_HEADERS_DIR"
echo "Extracting arm64 from $MARIADB_LIBS_DIR/$IOS_FAT_LIB_FILENAME to $IOS_DEVICE_THIN_LIB_PATH"
lipo "$MARIADB_LIBS_DIR/$IOS_FAT_LIB_FILENAME" -thin arm64 -output "$IOS_DEVICE_THIN_LIB_PATH"
find "$MARIADB_HEADERS_DIR" -maxdepth 1 -name "*.h" -exec cp {} "$IOS_DEVICE_HEADERS_DIR/" \;
create_module_files "$IOS_DEVICE_HEADERS_DIR" "$SWIFT_MODULE_NAME"
XCFW_ARGS+=(-library "$IOS_DEVICE_THIN_LIB_PATH" -headers "$IOS_DEVICE_HEADERS_DIR")

# 3. macOS Slice (assuming fat binary for arm64 and x86_64)
MACOS_SLICE_DIR="$ABSOLUTE_TEMP_BUILD_DIR/macos-arm64_x86_64"
MACOS_HEADERS_DIR="$MACOS_SLICE_DIR/Headers"
echo "🛠️  Preparing slice for macOS (arm64, x86_64)..."
mkdir -p "$MACOS_HEADERS_DIR"
cp "$MARIADB_LIBS_DIR/$MACOS_FAT_LIB_FILENAME" "$MACOS_SLICE_DIR/$XCFRAMEWORK_FILENAME.a"
find "$MARIADB_HEADERS_DIR" -maxdepth 1 -name "*.h" -exec cp {} "$MACOS_HEADERS_DIR/" \;
create_module_files "$MACOS_HEADERS_DIR" "$SWIFT_MODULE_NAME"
XCFW_ARGS+=(-library "$MACOS_SLICE_DIR/$XCFRAMEWORK_FILENAME.a" -headers "$MACOS_HEADERS_DIR")

# --- Build the XCFramework ---
if [ ${#XCFW_ARGS[@]} -lt 2 ]; then # Expecting at least device and macOS, ideally sim too
  echo "❌ Not enough library slices were prepared. Need at least iOS device and macOS. Aborting."
  exit 1
fi

echo "🏗️  Building $XCFRAMEWORK_FILENAME.xcframework..."
xcodebuild -create-xcframework \
    "${XCFW_ARGS[@]}" \
    -output "$ABSOLUTE_XCFW_OUTPUT_DIR/$XCFRAMEWORK_FILENAME.xcframework"

# ... (rest of script: cleanup, optional zip/checksum) ...
echo "🧹 Cleaning up temporary build directory..."
rm -rf "$ABSOLUTE_TEMP_BUILD_DIR"
echo "✅ $XCFRAMEWORK_FILENAME.xcframework successfully created in $ABSOLUTE_XCFW_OUTPUT_DIR/!"
echo "🎉 Process completed."
