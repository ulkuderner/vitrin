#!/usr/bin/env bash
# Vitrin — dağıtıma hazır sürüm üretir.
#
# Mac App Store hedeflenmiyor: uygulama _AXUIElementGetWindow özel sembolünü
# kullanıyor ve sandbox içinden kurulamayan bir CGEvent tap açıyor. Dağıtım
# yolu Developer ID + noterleme; bu betik onu uçtan uca yapar.
#
# Kullanım:
#   ./Scripts/release.sh                 # derle, imzala, DMG üret
#   NOTARIZE=1 ./Scripts/release.sh      # ayrıca noterle ve mühürle
#
# Noterleme kimliği (bir kez):
#   xcrun notarytool store-credentials vitrin-notary \
#     --apple-id "sen@ornek.com" --team-id "TEAMID" --password "<uygulamaya-ozel-parola>"

set -euo pipefail

APP="Vitrin"
BUNDLE_ID="com.profelis.vitrin"
VERSION="${VERSION:-0.1.0}"
BUILD="${BUILD:-$(date +%Y%m%d%H%M)}"
NOTARY_PROFILE="${NOTARY_PROFILE:-vitrin-notary}"
DIST="dist"

if [ -z "${SIGN_ID:-}" ]; then
  SIGN_ID=$(security find-identity -v -p codesigning \
            | grep "Developer ID Application" | head -1 \
            | sed -E 's/.*"(.*)"/\1/') || true
fi
if [ -z "${SIGN_ID:-}" ]; then
  echo "hata: Developer ID Application sertifikasi bulunamadi." >&2
  echo "      developer.apple.com > Certificates bolumunden olustur ve indir." >&2
  echo "      Yerel test icin: SIGN_ID=\"Vitrin Dev\" ./build.sh" >&2
  exit 1
fi
echo "imza kimligi: $SIGN_ID"

rm -rf "$DIST" && mkdir -p "$DIST"

echo "derleniyor (arm64 + x86_64)..."
swift build -c release --arch arm64 --arch x86_64
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/$APP"
[ -x "$BIN" ] || { echo "derleme ciktisi yok: $BIN" >&2; exit 1; }
lipo -info "$BIN"

APPDIR="$DIST/$APP.app"
mkdir -p "$APPDIR/Contents/MacOS" "$APPDIR/Contents/Resources"
cp "$BIN" "$APPDIR/Contents/MacOS/$APP"

if [ ! -f AppIcon.icns ]; then
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
  <key>CFBundleDisplayName</key><string>$APP</string>
  <key>CFBundleExecutable</key><string>$APP</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$BUILD</string>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSHumanReadableCopyright</key><string>(c) 2026 Caglar Ulkuderner</string>
  <key>CFBundleLocalizations</key>
  <array>
    <string>en</string><string>tr</string><string>de</string><string>fr</string>
    <string>es</string><string>it</string><string>pt</string><string>nl</string>
    <string>pl</string><string>ru</string><string>ja</string><string>ko</string>
  </array>
</dict>
</plist>
PLIST

# Guclendirilmis calisma zamani noterleme icin zorunlu.
codesign --force --options runtime --timestamp \
         --entitlements Vitrin.entitlements \
         --sign "$SIGN_ID" "$APPDIR"

echo "--- imza dogrulama ---"
codesign --verify --deep --strict --verbose=2 "$APPDIR"
spctl -a -vvv -t exec "$APPDIR" 2>&1 || echo "(noterlenmeden spctl reddi normaldir)"

DMG="$DIST/$APP-$VERSION.dmg"
STAGE="$DIST/stage"
mkdir -p "$STAGE"
cp -R "$APPDIR" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "$APP" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"
codesign --force --timestamp --sign "$SIGN_ID" "$DMG"
echo "paket: $DMG"

if [ "${NOTARIZE:-0}" = "1" ]; then
  echo "noterleniyor... (birkac dakika surebilir)"
  xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG"
  xcrun stapler staple "$APPDIR"
  echo "--- noterleme sonrasi ---"
  spctl -a -vvv -t exec "$APPDIR"
  echo "muhurlendi: $DMG"
else
  echo "not: noterlemek icin NOTARIZE=1 ile calistir."
fi
