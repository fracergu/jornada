#!/bin/bash

# Script de compilación rápida para Jornada
# Ejecuta: ./build.sh

set -e  # Salir si hay errores

echo "🔨 Compilando Jornada..."

# 1. Build release
echo "1/6 - Compilando en modo release..."
cd "$(dirname "$0")"
swift build -c release

# 2. Generar icono ICNS si existe icon.png
echo "2/6 - Generando icono..."
if [ -f "icon.png" ]; then
    mkdir -p AppIcon.iconset
    sips -z 16 16 icon.png --out AppIcon.iconset/icon_16x16.png 2>/dev/null
    sips -z 32 32 icon.png --out AppIcon.iconset/icon_16x16@2x.png 2>/dev/null
    sips -z 32 32 icon.png --out AppIcon.iconset/icon_32x32.png 2>/dev/null
    sips -z 64 64 icon.png --out AppIcon.iconset/icon_32x32@2x.png 2>/dev/null
    sips -z 128 128 icon.png --out AppIcon.iconset/icon_128x128.png 2>/dev/null
    sips -z 256 256 icon.png --out AppIcon.iconset/icon_128x128@2x.png 2>/dev/null
    sips -z 256 256 icon.png --out AppIcon.iconset/icon_256x256.png 2>/dev/null
    sips -z 512 512 icon.png --out AppIcon.iconset/icon_256x256@2x.png 2>/dev/null
    sips -z 512 512 icon.png --out AppIcon.iconset/icon_512x512.png 2>/dev/null
    sips -z 1024 1024 icon.png --out AppIcon.iconset/icon_512x512@2x.png 2>/dev/null
    iconutil -c icns AppIcon.iconset
    rm -rf AppIcon.iconset
    echo "   Icono ICNS generado"
else
    echo "   No se encontró icon.png, usando icono por defecto"
fi

# 3. Actualizar app bundle
echo "3/6 - Actualizando app bundle..."
rm -rf build/Jornada.app
mkdir -p build/Jornada.app/Contents/MacOS
mkdir -p build/Jornada.app/Contents/Resources
cp .build/release/Jornada build/Jornada.app/Contents/MacOS/Jornada

# 4. Copiar icono si existe
if [ -f "AppIcon.icns" ]; then
    cp AppIcon.icns build/Jornada.app/Contents/Resources/
    echo "   Icono copiado al bundle"
fi

# 5. Configurar Info.plist
echo "4/6 - Configurando Info.plist..."
cat > build/Jornada.app/Contents/Info.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>es</string>
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
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
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
echo "5/6 - Firmando el bundle..."
if [ -n "${CODE_SIGN_IDENTITY}" ]; then
    codesign --deep --force --verify --verbose --sign "${CODE_SIGN_IDENTITY}" --entitlements Sources/Jornada/Jornada.entitlements build/Jornada.app
else
    echo "   CODE_SIGN_IDENTITY no configurada, saltando firma"
    # Aun así, reemplazar con firma ad-hoc para evitar cuarentena
    codesign --deep --force --verify --verbose --sign - build/Jornada.app
fi

# 6. Actualizar DMG
echo "6/6 - Creando DMG..."
rm -rf build/dmg-root
mkdir -p build/dmg-root
cp -R build/Jornada.app build/dmg-root/
ln -sf /Applications build/dmg-root/Applications
hdiutil create -volname "Jornada" -srcfolder build/dmg-root -ov -format UDZO build/Jornada.dmg
rm -rf build/dmg-root

echo ""
echo "✅ ¡Compilación completada!"
echo ""
echo "Artefactos:"
echo "  - App:    build/Jornada.app"
echo "  - DMG:    build/Jornada.dmg"
echo ""
echo "Para actualizar la app instalada:"
echo "  1. Abre build/Jornada.dmg"
echo "  2. Arrastra Jornada a Applications"
echo "  3. Si macOS bloquea la app, ve a Ajustes > Seguridad y pulsa 'Abrir de todos modos'"
