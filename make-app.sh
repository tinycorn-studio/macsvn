#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="MacSVN"
BUNDLE_ID="com.macsvn.app"
VERSION="0.4.0"
DIST="dist"

echo "==> Building release binary..."
swift build -c release

echo "==> Generating app icon..."
if [ ! -f "Resources/AppIcon.icns" ]; then
    mkdir -p Resources
    swift tools/generate_icon.swift Resources/icon_1024.png
    ICONSET="Resources/AppIcon.iconset"
    rm -rf "$ICONSET"
    mkdir -p "$ICONSET"
    for s in 16 32 128 256 512; do
        sips -z $s $s Resources/icon_1024.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
        d=$((s * 2))
        sips -z $d $d Resources/icon_1024.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
    done
    iconutil -c icns "$ICONSET" -o Resources/AppIcon.icns
    echo "    icon: Resources/AppIcon.icns"
fi

echo "==> Assembling $APP_NAME.app..."
rm -rf "$DIST"
APP="$DIST/$APP_NAME.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp ".build/release/SVNDemo" "$APP/Contents/MacOS/$APP_NAME"
cp "Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleDisplayName</key><string>$APP_NAME</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.developer-tools</string>
</dict>
</plist>
PLIST

echo "==> Ad-hoc signing..."
codesign --force --deep --sign - "$APP"
codesign --verify --deep "$APP" && echo "    signature OK"

echo "==> Creating DMG..."
hdiutil create -volname "$APP_NAME" -srcfolder "$APP" -ov -format UDZO "$DIST/$APP_NAME-$VERSION.dmg" >/dev/null
echo ""
echo "Done:"
echo "  App: $DIST/$APP_NAME.app"
echo "  DMG: $DIST/$APP_NAME-$VERSION.dmg ($(du -h "$DIST/$APP_NAME-$VERSION.dmg" | cut -f1))"
