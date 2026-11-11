#!/usr/bin/env bash
set -euo pipefail
if ! command -v flutter >/dev/null; then
  echo 'Flutter SDK не найден в PATH. См. раздел «Локальный запуск» в README.md.' >&2
  exit 1
fi
cd "$(dirname "$0")/../mobile"
temp_dir=$(mktemp -d)
trap 'rm -rf "$temp_dir"' EXIT
if [[ ! -d android || ! -d ios ]]; then
  flutter create --no-pub --platforms=android,ios --project-name saldo --org ru.itmo "$temp_dir/saldo"
  for platform in android ios; do
    if [[ ! -d "$platform" ]]; then
      cp -R "$temp_dir/saldo/$platform" .
    fi
  done
  python3 - <<'PLATFORMS'
from pathlib import Path
import re

android = Path("android/app/build.gradle.kts")
android.write_text(android.read_text().replace(
    "minSdk = flutter.minSdkVersion", "minSdk = 29"
))
ios = Path("ios/Runner.xcodeproj/project.pbxproj")
ios.write_text(re.sub(
    r"IPHONEOS_DEPLOYMENT_TARGET = [0-9.]+;",
    "IPHONEOS_DEPLOYMENT_TARGET = 16.0;",
    ios.read_text(),
))
PLATFORMS
fi

# The local demo API uses HTTP. Allow it in Android debug builds.
cat > android/app/src/debug/AndroidManifest.xml <<'MANIFEST'
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET"/>
    <application android:usesCleartextTraffic="true"/>
</manifest>
MANIFEST
ios_plist=ios/Runner/Info.plist
if ! grep -q NSAllowsLocalNetworking "$ios_plist"; then
  python3 - "$ios_plist" <<'PY'
import plistlib
import sys

path = sys.argv[1]
with open(path, "rb") as file:
    config = plistlib.load(file)
config.setdefault("NSAppTransportSecurity", {})["NSAllowsLocalNetworking"] = True
with open(path, "wb") as file:
    plistlib.dump(config, file)
PY
fi
flutter pub get --enforce-lockfile
