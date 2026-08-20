#!/bin/sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
FRAMEWORK_DIR="$ROOT_DIR/ios/SmartWearableLinkSDK/Frameworks"
TMP_DIR="${TMPDIR:-/private/tmp}/smartwearablelink-xcframeworks"

mkdir -p "$TMP_DIR"

make_stub_framework() {
  name="$1"
  kind="$2"
  real_framework="$FRAMEWORK_DIR/$name.framework"
  stub_root="$TMP_DIR/$name"
  stub_framework="$stub_root/$name.framework"
  rm -rf "$stub_root"
  mkdir -p "$stub_framework"
  cp -R "$real_framework/Headers" "$stub_framework/"
  if [ -d "$real_framework/Modules" ]; then
    cp -R "$real_framework/Modules" "$stub_framework/"
  fi
  cp "$real_framework/Info.plist" "$stub_framework/Info.plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleExecutable $name" "$stub_framework/Info.plist" >/dev/null
  rm -f "$stub_framework/$name" "$stub_framework/_CodeSignature/CodeResources"
  case "$kind" in
    dynamic)
      printf 'int smartwearablelink_stub(void) { return 0; }\n' > "$stub_root/empty.c"
      mkdir -p "$stub_root/arm64" "$stub_root/x86_64"
      xcrun clang -dynamiclib \
        -arch arm64 \
        -target arm64-apple-ios15.1-simulator \
        -isysroot "$(xcrun --sdk iphonesimulator --show-sdk-path)" \
        -install_name "@rpath/$name.framework/$name" \
        "$stub_root/empty.c" \
        -o "$stub_root/arm64/$name"
      xcrun clang -dynamiclib \
        -arch x86_64 \
        -target x86_64-apple-ios15.1-simulator \
        -isysroot "$(xcrun --sdk iphonesimulator --show-sdk-path)" \
        -install_name "@rpath/$name.framework/$name" \
        "$stub_root/empty.c" \
        -o "$stub_root/x86_64/$name"
      lipo -create "$stub_root/arm64/$name" "$stub_root/x86_64/$name" -output "$stub_framework/$name"
      ;;
    static)
      printf 'int smartwearablelink_stub(void) { return 0; }\n' > "$stub_root/empty.c"
      mkdir -p "$stub_root/arm64" "$stub_root/x86_64"
      xcrun clang -c \
        -arch arm64 \
        -target arm64-apple-ios15.1-simulator \
        -isysroot "$(xcrun --sdk iphonesimulator --show-sdk-path)" \
        "$stub_root/empty.c" \
        -o "$stub_root/arm64/empty.o"
      xcrun clang -c \
        -arch x86_64 \
        -target x86_64-apple-ios15.1-simulator \
        -isysroot "$(xcrun --sdk iphonesimulator --show-sdk-path)" \
        "$stub_root/empty.c" \
        -o "$stub_root/x86_64/empty.o"
      xcrun libtool -static -o "$stub_root/arm64/$name" "$stub_root/arm64/empty.o"
      xcrun libtool -static -o "$stub_root/x86_64/$name" "$stub_root/x86_64/empty.o"
      lipo -create "$stub_root/arm64/$name" "$stub_root/x86_64/$name" -output "$stub_framework/$name"
      ;;
    *)
      echo "unknown framework kind: $kind" >&2
      exit 1
      ;;
  esac
  xcodebuild -create-xcframework \
    -framework "$real_framework" \
    -framework "$stub_framework" \
    -output "$FRAMEWORK_DIR/$name.xcframework"
}

make_stub_framework VeepooBleSDK static
make_stub_framework JL_BLEKit static
make_stub_framework JLDialUnit dynamic
make_stub_framework GRDFUSDK dynamic
make_stub_framework ABParTool dynamic
make_stub_framework ZipZap dynamic

echo "xcframeworks written to $FRAMEWORK_DIR"
