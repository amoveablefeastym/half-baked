#!/bin/zsh
# Build Half-Baked.app. Usage: ./build.sh [install]
set -e
cd "$(dirname "$0")"
APP="build/Half-Baked.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "Compiling…"
swiftc -O -swift-version 5 \
  -target "$(uname -m)-apple-macos14.0" \
  Sources/*.swift -o "$APP/Contents/MacOS/HalfBaked"

mkdir -p "$APP/Contents/Resources/Fonts"
cp Resources/Fonts/*.ttf "$APP/Contents/Resources/Fonts/"

echo "Making icon…"
TMP=$(mktemp -d)
swift scripts/make-icon.swift "$TMP/icon.png"
mkdir "$TMP/AppIcon.iconset"
for s in 16 32 128 256 512; do
  sips -z $s $s "$TMP/icon.png" --out "$TMP/AppIcon.iconset/icon_${s}x${s}.png" >/dev/null
  sips -z $((s*2)) $((s*2)) "$TMP/icon.png" --out "$TMP/AppIcon.iconset/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$TMP/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$TMP"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>Half-Baked</string>
  <key>CFBundleDisplayName</key><string>Half-Baked</string>
  <key>CFBundleIdentifier</key><string>local.halfbaked</string>
  <key>CFBundleExecutable</key><string>HalfBaked</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST

codesign --force --sign - "$APP" >/dev/null 2>&1
echo "Built $APP"

if [[ "$1" == "install" ]]; then
  pkill -x HalfBaked 2>/dev/null || true
  mkdir -p ~/Applications
  rm -rf ~/Applications/Half-Baked.app
  cp -R "$APP" ~/Applications/
  rm -f ~/Desktop/Half-Baked
  ln -s ~/Applications/Half-Baked.app ~/Desktop/Half-Baked
  echo "Installed to ~/Applications/Half-Baked.app (shortcut on Desktop)"
fi
