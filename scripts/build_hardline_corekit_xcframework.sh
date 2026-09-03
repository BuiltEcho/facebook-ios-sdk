#!/bin/sh

set -eu

if [ "$#" -ne 1 ] || [ ! -x "$1" ]; then
  echo "usage: $0 /absolute/path/to/xcodegen-2.29.0" >&2
  exit 64
fi

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
XCODEGEN=$1
OUTPUT="$ROOT/build/hardline"
DEVICE_ARCHIVE="$OUTPUT/FBSDKCoreKit-iOS.xcarchive"
SIMULATOR_ARCHIVE="$OUTPUT/FBSDKCoreKit-Simulator.xcarchive"
XCFRAMEWORK="$OUTPUT/FBSDKCoreKit.xcframework"
ZIP="$OUTPUT/FBSDKCoreKit-Dynamic_XCFramework.zip"

if [ "$($XCODEGEN --version | sed 's/^Version: //')" != "2.29.0" ]; then
  echo "XcodeGen 2.29.0 is required" >&2
  exit 65
fi

# CoreKit and TestTools reference one another. XcodeGen validates that each
# referenced project path exists before generation, so seed the two project
# bundles exactly as upstream's all-project generator expects.
mkdir -p "$ROOT/FBSDKCoreKit/FBSDKCoreKit.xcodeproj"
mkdir -p "$ROOT/TestTools/TestTools.xcodeproj"

for kit in FBSDKCoreKit_Basics FBAEMKit FBSDKCoreKit TestTools; do
  (cd "$ROOT/$kit" && "$XCODEGEN" generate)
done

xcodebuild test \
  -workspace "$ROOT/FacebookSDK.xcworkspace" \
  -scheme FBSDKCoreKit-Dynamic \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FBSDKCoreKitTests/AppEventsDeviceInfoTests \
  EXCLUDED_SOURCE_FILE_NAMES=Info.plist

rm -rf "$OUTPUT"
mkdir -p "$OUTPUT"

archive() {
  destination=$1
  archive_path=$2
  xcodebuild archive \
    -workspace "$ROOT/FacebookSDK.xcworkspace" \
    -scheme FBSDKCoreKit-Dynamic \
    -configuration Release \
    -destination "$destination" \
    -archivePath "$archive_path" \
    SKIP_INSTALL=NO \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    CODE_SIGNING_ALLOWED=NO \
    EXCLUDED_SOURCE_FILE_NAMES=Info.plist
}

archive 'generic/platform=iOS' "$DEVICE_ARCHIVE"
archive 'generic/platform=iOS Simulator' "$SIMULATOR_ARCHIVE"

xcodebuild -create-xcframework \
  -framework "$DEVICE_ARCHIVE/Products/@rpath/FBSDKCoreKit.framework" \
  -framework "$SIMULATOR_ARCHIVE/Products/@rpath/FBSDKCoreKit.framework" \
  -output "$XCFRAMEWORK"

if grep -R -a -q 'CTTelephonyNetworkInfo' "$XCFRAMEWORK"; then
  echo "patched artifact still references CTTelephonyNetworkInfo" >&2
  exit 66
fi

find "$XCFRAMEWORK" -exec touch -h -t 202608270000.00 {} +
(cd "$OUTPUT" && find "$(basename "$XCFRAMEWORK")" -print | LC_ALL=C sort | COPYFILE_DISABLE=1 zip -X -y -q "$(basename "$ZIP")" -@)

echo "$ZIP"
