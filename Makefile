# Vitrin — geliştirme ve dağıtım hedefleri
#
#   make            derle ve yeniden başlat (yerel geliştirme)
#   make run        derle, kur, çalıştır
#   make icon       ikonu koddan yeniden üret
#   make creds      noterleme kimliğini anahtar zincirine kaydet (bir kez)
#   make release    Developer ID ile imzalı DMG üret
#   make notarize   imzala + noterlet + mühürle
#   make check      imza, mimari ve Gatekeeper durumunu göster
#   make clean      derleme çıktılarını sil
#
# Parolalar burada tutulmaz. `make creds` parolayı sorar, notarytool onu
# anahtar zincirine yazar; sonraki komutlar yalnızca profil adını kullanır.

APP          := Vitrin
BUNDLE_ID    := com.profelis.vitrin
VERSION      ?= 0.1.0
# Dağıtım kimlikleri ortamdan gelir; public repoda kişisel bilgi tutulmaz.
#   export APPLE_ID="sen@ornek.com"
#   export TEAM_ID="XXXXXXXXXX"
# ya da: make creds APPLE_ID=... TEAM_ID=...
APPLE_ID     ?=
TEAM_ID      ?=
NOTARY_PROFILE ?= vitrin-notary

# Yerel geliştirme imzası: sabit kimlik sayesinde TCC izinleri derlemeler
# arasında korunur.
DEV_SIGN_ID  ?= Vitrin Dev

.DEFAULT_GOAL := run
.PHONY: build run install icon creds release notarize check clean help

## Yerel geliştirme

build:
	SIGN_ID="$(DEV_SIGN_ID)" bash build.sh

run: build
	@pkill -x $(APP) 2>/dev/null || true
	@sleep 1
	open $(APP).app
	@echo "calisiyor: $$(pgrep -lf $(APP) | head -1)"

install:
	SIGN_ID="$(DEV_SIGN_ID)" bash build.sh install

icon:
	rm -rf Icon.iconset AppIcon.icns
	swift Tools/MakeIcon.swift Icon.iconset
	iconutil -c icns Icon.iconset -o AppIcon.icns
	@echo "ikon uretildi: AppIcon.icns"

## Dağıtım

# Uygulamaya özel parolayı appleid.apple.com > Oturum Açma ve Güvenlik
# bölümünden üret. Parola ekrana yazılmaz ve bu dosyada saklanmaz.
creds:
	@[ -n "$(APPLE_ID)" ] || { echo "APPLE_ID gerekli: make creds APPLE_ID=... TEAM_ID=..."; exit 1; }
	@[ -n "$(TEAM_ID)" ]  || { echo "TEAM_ID gerekli: make creds APPLE_ID=... TEAM_ID=..."; exit 1; }
	@printf "Uygulamaya ozel parola: "; \
	stty -echo; read -r PW; stty echo; echo; \
	xcrun notarytool store-credentials "$(NOTARY_PROFILE)" \
		--apple-id "$(APPLE_ID)" --team-id "$(TEAM_ID)" --password "$$PW"

release:
	VERSION=$(VERSION) bash Scripts/release.sh

notarize:
	VERSION=$(VERSION) NOTARIZE=1 NOTARY_PROFILE=$(NOTARY_PROFILE) \
		bash Scripts/release.sh

## Doğrulama

check:
	@echo "--- imzalama kimlikleri ---"
	@security find-identity -v -p codesigning | grep -E "Developer ID|$(DEV_SIGN_ID)" || echo "kimlik yok"
	@echo "--- noterleme profili ---"
	@xcrun notarytool history --keychain-profile "$(NOTARY_PROFILE)" 2>&1 | head -3
	@if [ -d dist/$(APP).app ]; then \
		echo "--- paket imzasi ---"; \
		codesign -dvvv dist/$(APP).app 2>&1 | grep -E "Authority|TeamIdentifier|Runtime|Timestamp"; \
		echo "--- mimari ---"; \
		lipo -info dist/$(APP).app/Contents/MacOS/$(APP); \
		echo "--- gatekeeper ---"; \
		spctl -a -vvv -t exec dist/$(APP).app 2>&1 | head -3; \
	else echo "(dist/ bos - once 'make release')"; fi

clean:
	rm -rf .build dist Icon.iconset $(APP).app
	@echo "temizlendi (AppIcon.icns korundu; silmek icin 'make icon')"

help:
	@grep -E '^##|^[a-z]+:' Makefile | sed 's/:.*//'
