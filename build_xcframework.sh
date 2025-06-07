#!/bin/zsh
set -e

# --- Configuration ---
PACKAGE_ROOT=$(pwd)
XCFRAMEWORK_FILENAME="libmariadbclient"
SWIFT_MODULE_NAME="CMariaDBClient"

# Define the correct base path for C connector sources first
# It's inside the top-level "Sources" directory of the package
MARIADB_C_CONNECTOR_SRC_DIR="Sources/CConector_Sources/PrivateCModule_Private" # <<< CORRECTED PATH

# Now define other paths based on the correct base path
MARIADB_HEADERS_DIR="$PACKAGE_ROOT/$MARIADB_C_CONNECTOR_SRC_DIR"
MARIADB_LIBS_DIR="$PACKAGE_ROOT/$MARIADB_C_CONNECTOR_SRC_DIR/libs"

IOS_FAT_LIB_FILENAME="libmariadbclient-ios.a"
MACOS_FAT_LIB_FILENAME="libmariadbclient-macos.a"

TEMP_BUILD_DIR="xcframework_build_temp"
XCFW_OUTPUT_DIR="Frameworks"
# --- End of Configuration ---

create_module_files() {
  local headers_dir="$1"; local module_name_arg="$2"
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
echo "🚀 Building XCFramework: iOS Device (arm64) + macOS (fat arm64, x86_64) ONLY"
ABSOLUTE_TEMP_BUILD_DIR="$PACKAGE_ROOT/$TEMP_BUILD_DIR"
ABSOLUTE_XCFW_OUTPUT_DIR="$PACKAGE_ROOT/$XCFW_OUTPUT_DIR"

echo "🧹 Cleaning up old directories..."
rm -rf "$ABSOLUTE_TEMP_BUILD_DIR"
rm -rf "$ABSOLUTE_XCFW_OUTPUT_DIR/$XCFRAMEWORK_FILENAME.xcframework"
mkdir -p "$ABSOLUTE_XCFW_OUTPUT_DIR"
mkdir -p "$ABSOLUTE_TEMP_BUILD_DIR"

XCFW_ARGS=()
ORIGINAL_IOS_FAT_LIB_PATH="$MARIADB_LIBS_DIR/$IOS_FAT_LIB_FILENAME"
ORIGINAL_MACOS_FAT_LIB_PATH="$MARIADB_LIBS_DIR/$MACOS_FAT_LIB_FILENAME"

# --- DEBUGGING ---
echo "--- DEBUG PATHS ---"
echo "PACKAGE_ROOT: $PACKAGE_ROOT"
echo "MARIADB_C_CONNECTOR_SRC_DIR (relative): $MARIADB_C_CONNECTOR_SRC_DIR"
echo "MARIADB_LIBS_DIR (absolute): $MARIADB_LIBS_DIR"
echo "IOS_FAT_LIB_FILENAME: $IOS_FAT_LIB_FILENAME"
echo "ORIGINAL_IOS_FAT_LIB_PATH (to be used by lipo): $ORIGINAL_IOS_FAT_LIB_PATH"
echo "Does ORIGINAL_IOS_FAT_LIB_PATH exist? Output of ls -l:"
ls -l "$ORIGINAL_IOS_FAT_LIB_PATH" || echo "File NOT FOUND at $ORIGINAL_IOS_FAT_LIB_PATH"
echo "--- END DEBUG PATHS ---"
# --- END DEBUGGING ---

# --- Prepare Slices ---

# 1. iOS Device Slice (arm64) - THIN
IOS_DEVICE_SLICE_STAGING_DIR="$ABSOLUTE_TEMP_BUILD_DIR/iphoneos-arm64"
IOS_DEVICE_HEADERS_DIR="$IOS_DEVICE_SLICE_STAGING_DIR/Headers"
IOS_DEVICE_LIB_PATH="$IOS_DEVICE_SLICE_STAGING_DIR/$XCFRAMEWORK_FILENAME.a"
echo "🛠️  Preparing slice for iOS Device (arm64)..."
mkdir -p "$IOS_DEVICE_HEADERS_DIR"
lipo "$ORIGINAL_IOS_FAT_LIB_PATH" -extract arm64 -output "$IOS_DEVICE_LIB_PATH"
find "$MARIADB_HEADERS_DIR" -maxdepth 1 -name "*.h" -exec cp {} "$IOS_DEVICE_HEADERS_DIR/" \;
create_module_files "$IOS_DEVICE_HEADERS_DIR" "$SWIFT_MODULE_NAME"
XCFW_ARGS+=(-library "$IOS_DEVICE_LIB_PATH" -headers "$IOS_DEVICE_HEADERS_DIR")

# 2. macOS Slice (using the original FAT library)
MACOS_SLICE_STAGING_DIR="$ABSOLUTE_TEMP_BUILD_DIR/macosx-combined"
MACOS_HEADERS_DIR="$MACOS_SLICE_STAGING_DIR/Headers"
MACOS_STAGED_LIB_PATH="$MACOS_SLICE_STAGING_DIR/$XCFRAMEWORK_FILENAME.a"
echo "🛠️  Preparing slice for macOS (using fat lib)..."
mkdir -p "$MACOS_HEADERS_DIR"
cp "$ORIGINAL_MACOS_FAT_LIB_PATH" "$MACOS_STAGED_LIB_PATH"
find "$MARIADB_HEADERS_DIR" -maxdepth 1 -name "*.h" -exec cp {} "$MACOS_HEADERS_DIR/" \;
create_module_files "$MACOS_HEADERS_DIR" "$SWIFT_MODULE_NAME"
XCFW_ARGS+=(-library "$MACOS_STAGED_LIB_PATH" -headers "$MACOS_HEADERS_DIR")

# --- Build the XCFramework ---
if [ ${#XCFW_ARGS[@]} -lt 2 ]; then
  echo "❌ Not enough library slices were prepared. Need iOS device and macOS. Aborting."
  exit 1
fi

echo "🏗️  Building $XCFRAMEWORK_FILENAME.xcframework..."
echo "xcodebuild -create-xcframework \\"
for arg_group_index in $(seq 0 2 $((${#XCFW_ARGS[@]} - 1))); do
    echo "    ${XCFW_ARGS[arg_group_index]} ${XCFW_ARGS[arg_group_index+1]} \\"
done
echo "    -output \"$ABSOLUTE_XCFW_OUTPUT_DIR/$XCFRAMEWORK_FILENAME.xcframework\""

xcodebuild -create-xcframework \
    "${XCFW_ARGS[@]}" \
    -output "$ABSOLUTE_XCFW_OUTPUT_DIR/$XCFRAMEWORK_FILENAME.xcframework"

echo "🧹 Cleaning up temporary build directory..."
rm -rf "$ABSOLUTE_TEMP_BUILD_DIR"
echo "✅ $XCFRAMEWORK_FILENAME.xcframework successfully created in $ABSOLUTE_XCFW_OUTPUT_DIR/!"
echo "🎉 Process completed."


