#!/usr/bin/env bash
set -e

cd "$(dirname "${BASH_SOURCE[0]}")"

PLATFORM="${1:-}"
if [ "$PLATFORM" != "--ios" ] && [ "$PLATFORM" != "--android" ]; then
  echo "Usage: run.sh --ios | --android"
  exit 1
fi

# Prerequisites
check() { command -v "$1" &>/dev/null || { echo "Missing: $2"; exit 1; }; }
check git    "git — https://git-scm.com"
check python3 "python3 — https://python.org"
check flutter "Flutter SDK — https://flutter.dev/docs/get-started/install"
[ "$PLATFORM" = "--ios" ]     && check pod  "CocoaPods — run: sudo gem install cocoapods"
[ "$PLATFORM" = "--android" ] && check adb  "ADB — install Android SDK platform-tools: https://developer.android.com/tools/releases/platform-tools"

# Clone and set up Cactus
[ ! -d "cactus" ] && git clone https://github.com/cactus-compute/cactus && git -C cactus checkout c768b0457f4ce07d3ea00b5d486079c4c8d95dbd
source cactus/setup
cp cactus/flutter/cactus.dart lib/cactus.dart

# Convert model
[ ! -d "models/smart-home-model" ] && cactus convert distil-labs/distil-home-assistant-functiongemma models/smart-home-model --precision INT8

# Build and copy native libs (skip if already built)
NEEDS_BUILD=0
[ "$PLATFORM" = "--android" ] && [ ! -f "android/app/src/main/jniLibs/arm64-v8a/libcactus.so" ] && NEEDS_BUILD=1
[ "$PLATFORM" = "--ios" ]     && [ ! -d "ios/cactus.xcframework" ] && NEEDS_BUILD=1
if [ "$NEEDS_BUILD" = 1 ]; then
  if [ "$PLATFORM" = "--ios" ]; then
    cactus build --apple
  else
    cactus build --android
  fi
  if [ -f "cactus/android/libcactus.so" ]; then
    mkdir -p android/app/src/main/jniLibs/arm64-v8a
    cp cactus/android/libcactus.so android/app/src/main/jniLibs/arm64-v8a/
  fi
  if [ -d "cactus/apple/cactus-ios.xcframework" ]; then
    rm -rf ios/cactus.xcframework ios/Pods ios/Podfile.lock
    cp -R cactus/apple/cactus-ios.xcframework ios/cactus.xcframework
  fi
fi

# iOS: CocoaPods (skip if already installed)
if [ "$PLATFORM" = "--ios" ] && [ ! -d "ios/Pods" ]; then
  flutter pub get
  (cd ios && pod install)
fi

# ---------------------------------------------------------------------------
# Run on device
# ---------------------------------------------------------------------------

if [ "$PLATFORM" = "--ios" ]; then
  DEVICE=$(flutter devices --machine 2>/dev/null | python3 -c "
import sys, json
try:
  devices = [d for d in json.load(sys.stdin) if 'ios' in d.get('targetPlatform','') and not d.get('emulator', True)]
  print(devices[0]['id'] if devices else '')
except: print('')
" 2>/dev/null)
  [ -z "$DEVICE" ] && { echo "No iOS device found."; exit 1; }
  echo "iOS device: $DEVICE"
  echo "Copying model to device..."
  xcrun devicectl device copy to \
    --device "$DEVICE" \
    --source models/smart-home-model \
    --destination Documents/smart-home-model \
    --domain-type appDataContainer \
    --domain-identifier com.distillabs.mobile 2>/dev/null || true
  flutter run --release --device-id "$DEVICE"

else
  DEVICE=$(adb devices 2>/dev/null | grep -v "List\|offline" | grep "device$" | head -1 | awk '{print $1}')
  [ -z "$DEVICE" ] && { echo "No Android device found."; exit 1; }
  echo "Android device: $DEVICE"
  echo "Building APK..."
  flutter build apk --release
  echo "Installing..."
  adb -s "$DEVICE" install -r build/app/outputs/flutter-apk/app-release.apk
  echo "Copying model..."
  adb -s "$DEVICE" push models/smart-home-model /sdcard/smart-home-model
  echo "Launching..."
  adb -s "$DEVICE" shell am start -n com.distillabs.mobile/.MainActivity
fi
