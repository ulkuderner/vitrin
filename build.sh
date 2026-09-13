#!/usr/bin/env bash
# Vitrin'i derler ve .app paketi üretir.
#   ./build.sh            -> ./Vitrin.app
#   ./build.sh install    -> ~/Applications/Vitrin.app
set -euo pipefail

APP="Vitrin"
BUNDLE_ID="com.profelis.vitrin"
VERSION="0.1.0"

swift build -c release

BIN=".build/release/$APP"
[ -x "$BIN" ] || { echo "derleme çıktısı yok: $BIN" >&2; exit 1; }

APPDIR="$APP.app"
rm -rf "$APPDIR"
mkdir -p "$APPDIR/Contents/MacOS" "$APPDIR/Contents/Resources"
cp "$BIN" "$APPDIR/Contents/MacOS/$APP"

# İkon: yoksa koddan üret. Tools/MakeIcon.swift değişince silip yeniden çalıştır.
if [ ! -f AppIcon.icns ]; then
  echo "ikon uretiliyor…"
  rm -rf Icon.iconset
  swift Tools/MakeIcon.swift Icon.iconset >/dev/null
  iconutil -c icns Icon.iconset -o AppIcon.icns
fi
cp AppIcon.icns "$APPDIR/Contents/Resources/AppIcon.icns"

cat > "$APPDIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>$APP</string>
  <key>CFBundleExecutable</key><string>$APP</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

# İmzalama kimliği. Ad-hoc (-) imzada TeamIdentifier olmadığı için TCC izni
# cdhash'e bağlanır ve her derlemede geçersizleşir. Sabit bir kendinden imzalı
# sertifika kullanırsan izinler derlemeler arası korunur:
#   Keychain Access > Sertifika Yardımcısı > Sertifika Oluştur
#   Ad: "Vitrin Dev", Tip: Kod İmzalama
# Sonra:  SIGN_ID="Vitrin Dev" ./build.sh
SIGN_ID="${SIGN_ID:--}"
codesign --force --sign "$SIGN_ID" "$APPDIR" >/dev/null

if [ "$SIGN_ID" = "-" ]; then
  echo "uyarı: ad-hoc imza — her derlemede Erişilebilirlik izni sıfırlanır"
  echo "       kalıcı çözüm: SIGN_ID=\"Vitrin Dev\" ./build.sh"
fi

echo "hazır: $APPDIR"

if [ "${1:-}" = "install" ]; then
  mkdir -p "$HOME/Applications"
  rm -rf "$HOME/Applications/$APPDIR"
  cp -R "$APPDIR" "$HOME/Applications/"
  echo "kuruldu: $HOME/Applications/$APPDIR"
fi
