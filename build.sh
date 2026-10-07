#!/usr/bin/env bash
# Build the receivers (mac_receiver, desktop_receiver) and mobile_app, and collect
# the artifacts in ./release.
#
# Usage: ./build.sh [all|mac|linux|windows|android|ios]...   (default: all)
#   mac      Universal (arm64 + x86_64) "VirtualPen Receiver.app" menu bar app, packed in a .dmg
#   linux    desktop_receiver for amd64 + arm64, each a .tar.gz with install-linux.sh
#   windows  desktop_receiver .exe for amd64 + arm64, each in a .zip
#   android  Release APKs per CPU (arm64 fits almost every modern phone; armv7 for old ones),
#            signed with Flutter's debug key unless you configure one
#   ios      Release IPA. Export method from IOS_EXPORT (default: development, works with a
#            free Apple ID); IOS_EXPORT=app-store|ad-hoc|enterprise need a paid Apple Developer account.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
RELEASE="$ROOT/release"
IOS_EXPORT="${IOS_EXPORT:-development}"
VERSION="$(sed -n 's/^version: *\([^+]*\).*/\1/p' "$ROOT/mobile_app/pubspec.yaml")"

targets=("$@")
if [[ ${#targets[@]} -eq 0 || " ${targets[*]} " == *" all "* ]]; then targets=(mac linux windows android ios); fi

step() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }

build_mac() {
  step "mac_receiver (universal .app in a .dmg)"
  cd "$ROOT/mac_receiver"
  swift build -c release --arch arm64 --arch x86_64

  local stage app dmg="$RELEASE/VirtualPenReceiver-$VERSION.dmg"
  stage="$(mktemp -d)"
  app="$stage/VirtualPen Receiver.app"
  mkdir -p "$app/Contents/MacOS"
  cp .build/apple/Products/Release/PPTReceiver "$app/Contents/MacOS/"
  cp Info.plist "$app/Contents/Info.plist"
  plutil -replace CFBundleShortVersionString -string "$VERSION" "$app/Contents/Info.plist"
  # Ad-hoc sign so TCC can track the app's Accessibility/Bluetooth permissions.
  codesign --force --sign - "$app"

  # Drag-to-install layout: the app next to a shortcut to /Applications.
  ln -s /Applications "$stage/Applications"
  rm -f "$dmg"
  hdiutil create -quiet -volname "VirtualPen Receiver" -srcfolder "$stage" -format UDZO "$dmg"
  rm -rf "$stage"
}

# Cross-compile desktop_receiver (pure Go, no cgo) for one OS, both CPU types.
build_desktop() {
  local goos="$1" arch name stage
  cd "$ROOT/desktop_receiver"
  for arch in amd64 arm64; do
    name="VirtualPenReceiver-$VERSION-$goos-$arch"
    stage="$(mktemp -d)/$name"
    mkdir -p "$stage"
    if [[ $goos == windows ]]; then
      CGO_ENABLED=0 GOOS=windows GOARCH=$arch go build -trimpath -ldflags "-s -w" -o "$stage/VirtualPenReceiver.exe" .
      rm -f "$RELEASE/$name.zip"
      (cd "$stage/.." && zip -qr "$RELEASE/$name.zip" "$name")
    else
      CGO_ENABLED=0 GOOS=linux GOARCH=$arch go build -trimpath -ldflags "-s -w" -o "$stage/virtualpen-receiver" .
      cp install-linux.sh "$stage/"
      tar -czf "$RELEASE/$name.tar.gz" -C "$stage/.." "$name"
    fi
    rm -rf "$(dirname "$stage")"
  done
}

build_linux() {
  step "desktop_receiver (Linux)"
  build_desktop linux
}

build_windows() {
  step "desktop_receiver (Windows)"
  build_desktop windows
}

build_android() {
  step "mobile_app (Android APK)"
  cd "$ROOT/mobile_app"
  # Java 24+ warns when Gradle's launcher loads its native library; harmless, but noisy.
  GRADLE_OPTS="${GRADLE_OPTS:-} --enable-native-access=ALL-UNNAMED" \
    flutter build apk --release --split-per-abi --target-platform android-arm,android-arm64
  cp build/app/outputs/flutter-apk/app-arm64-v8a-release.apk "$RELEASE/VirtualPenRemote-$VERSION-arm64.apk"
  cp build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk "$RELEASE/VirtualPenRemote-$VERSION-armv7.apk"
}

build_ios() {
  step "mobile_app (iOS IPA, export: $IOS_EXPORT)"
  cd "$ROOT/mobile_app"
  # flutter exits 0 even when the export step fails, so check for the IPA ourselves
  # (and clear old output so a stale IPA can't be shipped).
  rm -rf build/ios/ipa
  flutter build ipa --release --export-method "$IOS_EXPORT"
  local ipa
  ipa="$(ls build/ios/ipa/*.ipa 2>/dev/null | head -1)"
  if [[ -z "$ipa" ]]; then
    echo "❌ IPA export ($IOS_EXPORT) failed — see errors above (signing/Apple Developer account)." >&2
    exit 1
  fi
  cp "$ipa" "$RELEASE/VirtualPenRemote-$VERSION.ipa"
}

for t in "${targets[@]}"; do
  case "$t" in
    mac|linux|windows|android|ios) ;;
    *) echo "Unknown target: $t (use all|mac|linux|windows|android|ios)" >&2; exit 1 ;;
  esac
done

# Each target runs in its own subshell so one failure (e.g. APK) doesn't stop
# the others (e.g. IPA). errexit is ignored inside `if`/`||`, hence the explicit
# `set +e` / status capture instead of `( ... ) || failed+=...`.
mkdir -p "$RELEASE"
succeeded=() failed=()
for t in "${targets[@]}"; do
  set +e
  ( set -e; "build_$t" )
  status=$?
  set -e
  if [[ $status -eq 0 ]]; then succeeded+=("$t"); else failed+=("$t"); fi
done

step "Done → $RELEASE"
ls -lh "$RELEASE"
[[ ${#succeeded[@]} -gt 0 ]] && printf '\033[1;32m✓ OK:     %s\033[0m\n' "${succeeded[*]}"
if [[ ${#failed[@]} -gt 0 ]]; then
  printf '\033[1;31m✗ FAILED: %s\033[0m\n' "${failed[*]}" >&2
  exit 1
fi
