# Detect operating system in Makefile.
ifeq ($(OS),Windows_NT)
	OSNAME = WIN32
else
	UNAME_S := $(shell uname -s)
	ifeq ($(UNAME_S),Linux)
		OSNAME = LINUX
	endif
	ifeq ($(UNAME_S),Darwin)
		OSNAME = OSX
	endif
endif

.PHONY: doctor init configure build install clean toolchain-init android-init android-build android-install android-internal android-clean
.SILENT: doctor init configure build install clean toolchain-init android-init android-build android-install android-internal android-clean

doctor:
	echo "Doctor summary"
ifeq ($(OSNAME),WIN32)
	echo "Windows detected"
	echo "TODO: [!] Check if https://github.com/google/bundletool is installed"
	echo "TODO: [!] Check if https://docs.fastlane.tools is installed"
	echo "TODO: [!] Check if https://bundler.io is installed"
else
	echo "$(OSNAME) detected, checking dependencies..."
	if hash bundletool 2>/dev/null; then echo "  [✓] bundletool is installed."; else echo >&2 "  [x] bundletool is NOT installed."; fi
	if hash fastlane 2>/dev/null; then echo "  [✓] fastlane is installed."; else echo >&2 "  [x] fastelane is NOT installed."; fi
	if hash bundle 2>/dev/null; then echo "  [✓] bundler is installed."; else echo >&2 "  [x] bundler is NOT installed."; fi

endif
	echo "Android, checking configuration..."; \
	if [ -f  "android/key.properties" ]; then echo "  [✓] Signing properties found."; else echo >&2 " > Signing properties NOT found."; fi; \
	if [ -f  "android/app/key.jks" ]; then echo "  [✓] Signing key found."; else echo >&2 " > Signing key NOT found."; fi; \
	if [ -f  "android/app/key.pwd" ]; then echo "  [✓] Password file found."; else echo >&2 " > Password file NOT found."; fi;

init: toolchain-init android-init

toolchain-init:
	echo "Initialize toolchain"
	echo "$(OSNAME) detected"
ifeq ($(OSNAME),WIN32)
	echo "TODO: [!] Install https://github.com/google/bundletool"
	echo "TODO: [!] Install https://docs.fastlane.tools"
	echo "TODO: [!] Install https://bundler.io"
else ifeq ($(OSNAME),LINUX)
	echo "TODO: [!] Install https://github.com/google/bundletool"
	echo "TODO: [!] Install https://docs.fastlane.tools"
	echo "TODO: [!] Install https://bundler.io"
else ifeq ($(OSNAME),OSX)
	echo "Installing dependencies..."
	if hash bundletool 2>/dev/null; then echo "  [✓] bundletool is installed."; else echo "  [!] Installing bundletool"; brew install bundletool; fi
	if hash fastlane 2>/dev/null; then echo "  [✓] fastlane is installed."; else echo "  [!] Installing fastlane"; brew cask install fastlane; fi
	if hash bundle 2>/dev/null; then echo "  [✓] bundler is installed."; else echo "  [!] Installing bundler"; sudo gem install bundler; fi
endif

android-init:
	echo "Init Android app..."
	if [ -f android/app/key.jks ]; then \
		echo "  [!] Android signing key exist, Skipping."; \
	else \
		read -p "  > Enter signing key and store password: " pwd; \
		echo "$$pwd" > android/app/key.pwd; \
		echo "storePassword=$$pwd" > android/key.properties; \
		echo "keyPassword=$$pwd" >> android/key.properties; \
		echo "keyAlias=upload" >> android/key.properties; \
		echo "storeFile=key.jks" >> android/key.properties; \
		keytool -genkey -v -keystore android/app/key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload -storepass $$pwd; \
		echo "  [✓] Android app configured"; \
	fi
	echo "  > Initializing fastlane...; cd android; fastlane init;

build: android-build

android-build:
	test ! -f "android/app/key.jks" && { echo "Android signing key does not exist > run 'make android-init'";  exit 0; }; \
	echo "Building Android app bundle..."; \
	flutter build appbundle
	echo "Building Android APK set archive..."; \
	echo "  > output: build/app/outputs/sarsys.apks"
	bundletool build-apks \
		--bundle=build/app/outputs/bundle/release/app.aab \
		--output=build/app/outputs/sarsys.apks \
		--ks=android/app/key.jks \
		--ks-pass=file:android/app/key.pwd \
		--ks-key-alias=upload \
		--overwrite; \

install: android-install

android-install:
	echo "Deploy to connected android devices"; \
	bundletool install-apks --apks=build/app/outputs/sarsys.apks

android-internal: android-build
	echo "Release to 'internal test' on to Google Play with fastlane..."
	cd android; \
	bundle exec fastlane supply --aab ../build/app/outputs/bundle/release/app.aab --track internal


clean: android-clean

android-clean:
	echo "Clean signing for android"; \
	if [ -f  "android/key.properties" ] ; then { echo "  [✓] Signing properties found"; rm "android/key.properties"; } else echo " [x] Signing properties not found"; fi; \
    if [ -f  "android/app/key.jks" ] ; then { echo "  [✓] Signing key found"; rm "android/app/key.jks"; } else echo " [x] Signing key not found"; fi; \
    if [ -f  "android/app/key.pwd" ] ; then { echo "  [✓] Password file found"; rm "android/app/key.pwd"; } else echo " [x] Password file not found"; fi;
	# TODO: Delete android/Gemfile and android/fastlane
