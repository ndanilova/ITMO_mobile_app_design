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

# Native file selection and local storage do not require cleartext HTTP.
python3 - <<'LOCAL'
from pathlib import Path
import plistlib
p = Path("ios/Runner/Info.plist")
with p.open("rb") as file:
    config = plistlib.load(file)
security = config.get("NSAppTransportSecurity", {})
security.pop("NSAllowsLocalNetworking", None)
if not security:
    config.pop("NSAppTransportSecurity", None)
with p.open("wb") as file:
    plistlib.dump(config, file)
manifest = Path("android/app/src/debug/AndroidManifest.xml")
if manifest.exists():
    manifest.write_text(manifest.read_text().replace(' android:usesCleartextTraffic="true"', ""))
LOCAL
flutter pub get --enforce-lockfile
