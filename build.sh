#!/bin/bash

# Quick build script for Jornada
# Run: ./build.sh

set -e

echo "🔨 Building Jornada..."

# 1. Build release
echo "1/6 - Building in release mode..."
cd "$(dirname "$0")"
swift build -c release

# 2. Update app bundle
echo "2/6 - Updating app bundle..."
rm -rf build/Jornada.app
mkdir -p build/Jornada.app/Contents/MacOS
mkdir -p build/Jornada.app/Contents/Resources
cp .build/release/Jornada build/Jornada.app/Contents/MacOS/Jornada

# 3. Copy icon
echo "3/6 - Copying icon..."
cp AppIcon.icns build/Jornada.app/Contents/Resources/

# 4. Configure Info.plist
echo "4/6 - Configuring Info.plist..."
cat > build/Jornada.app/Contents/Info.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>Jornada</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon.icns</string>
    <key>CFBundleIdentifier</key>
    <string>com.jornada.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Jornada</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.1</string>
    <key>CFBundleVersion</key>
    <string>2</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026. All rights reserved.</string>
</dict>
</plist>
EOF

echo -n "APPL????" > build/Jornada.app/Contents/PkgInfo

# 5b. Code sign the app bundle
echo "5/6 - Signing the bundle..."
if [ -n "${CODE_SIGN_IDENTITY}" ]; then
    codesign --deep --force --verify --verbose --sign "${CODE_SIGN_IDENTITY}" --entitlements Sources/Jornada/Jornada.entitlements build/Jornada.app
else
    echo "   CODE_SIGN_IDENTITY not set, skipping signature"
    codesign --deep --force --verify --verbose --sign - build/Jornada.app
fi

# 6. Create DMG
echo "6/6 - Creating DMG..."
rm -rf build/dmg-root
mkdir -p build/dmg-root
cp -R build/Jornada.app build/dmg-root/
ln -sf /Applications build/dmg-root/Applications
hdiutil create -volname "Jornada" -srcfolder build/dmg-root -ov -format UDZO build/Jornada.dmg
rm -rf build/dmg-root

echo ""
echo "✅ Build complete!"
echo ""
echo "Artifacts:"
echo "  - App:    build/Jornada.app"
echo "  - DMG:    build/Jornada.dmg"
echo ""
echo "To update the installed app:"
echo "  1. Open build/Jornada.dmg"
echo "  2. Drag Jornada to Applications"
echo "  3. If macOS blocks the app, go to System Settings > Privacy & Security and click 'Open Anyway'"
