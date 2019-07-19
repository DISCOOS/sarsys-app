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

# Utility functions
storeFile = "$$(grep "storeFile" android/key.properties | cut -d'=' -f2)"

.PHONY: \
	doctor init configure build install clean toolchain-init \
	android-init android-build android-install android-release-internal android-clean
.SILENT: \
	doctor init configure build install clean toolchain-init \
	android-init android-build android-install android-release-internal android-clean

doctor:
	echo "Doctor summary"
ifeq ($(OSNAME),WIN32)
	echo "Windows detected"
	echo "TODO: [!] Check if https://github.com/google/bundletool is installed"
	echo "TODO: [!] Check if https://docs.fastlane.tools is installed"
	echo "TODO: [!] Check if https://bundler.io is installed"
else
	echo "$(OSNAME) detected, checking dependencies..."
	if hash bundletool 2>/dev/null; \
		then echo "[✓] bundletool is installed."; \
		else echo >&2 "[x] bundletool is NOT installed."; fi
	if hash fastlane 2>/dev/null; \
		then echo "[✓] fastlane is installed."; \
		else echo >&2 "[x] fastelane is NOT installed."; fi
	if hash bundle 2>/dev/null; \
		then echo "[✓] bundler is installed."; \
		else echo >&2 "[x] bundler is NOT installed."; fi

endif
	echo "Android, checking configuration..."; \
	if [ -f  "android/key.properties" ]; \
		then echo "[✓] Signing properties found."; \
		else echo >&2 "[x] Signing properties NOT found > run 'make android-init'"; fi; \
	if [ -f $(storeFile) ]; \
		then echo "[✓] Upload key $(storeFile) found."; \
		else echo >&2 "[x] Upload key $(storeFile) NOT found > run 'make android-init'"; fi; \

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
	if hash bundletool 2>/dev/null; \
		then echo "[✓] bundletool is installed."; \
		else echo "[!] Installing bundletool"; brew itall bundletool; fi
	if hash fastlane 2>/dev/null; \
		then echo "[✓] fastlane is installed."; \
		else echo "[!] Installing fastlane"; brew cask install fastlane; fi
	if hash bundle 2>/dev/null; \
		then echo "[✓] bundler is installed."; \
		else echo "[!] Installing bundler"; sudo gem install bundler; fi
endif

android-init:
	echo "Initialize Android configuration..."; \
	read -p "> Enter path to upload key: " path; \
	if [ -f $$path ]; then \
		read -p "> Enter upload keystore password: " pwd; \
		echo "storePassword=$$pwd" > android/key.properties; \
		echo "keyPassword=$$pwd" >> android/key.properties; \
		echo "keyAlias=upload" >> android/key.properties; \
		echo "storeFile=$$path" >> android/key.properties; \
		echo "> Initializing fastlane..."; cd android; fastlane init; \
	else \
		echo "[x] Android upload key $$path NOT FOUND, Skipping."; \
	fi

build: android-build
	echo "[✓] Build complete."

android-build:
	test ! -f "$(storeFile)" && \
		{ echo "Android upload key $(storeFile) does not exist > run 'make android-init'";  exit 0; }; \
	echo "Building Android app bundle..."; \
	flutter build appbundle
	echo "[✓] Android build complete."

install: android-install

android-install: android-build
	echo "Building Android APK set archive..."; \
	echo "> output: build/app/outputs/sarsys.apks"
	bundletool build-apks \
		--bundle=build/app/outputs/bundle/release/app.aab \
		--output=build/app/outputs/sarsys.apks \
		--ks=$(storeFile) \
		--ks-pass=pass:$(android/key.properties,storePassword)\
		--ks-key-alias=upload \
		--overwrite; \
	echo "Deploy to connected android devices"; \
	bundletool install-apks --apks=build/app/outputs/sarsys.apks

android-release-internal: android-build
	echo "Release to 'internal test' to Google Play with fastlane..."
	cd android; \
	bundle exec fastlane supply --aab ../build/app/outputs/bundle/release/app.aab --track internal
	echo "[✓] Release to 'internal test' complete."

clean: android-clean
	echo "[✓] Clean complete."

android-clean:
	echo "Clean Android signing properties"; \
	if [ -f  "android/key.properties" ] ; \
		then { echo "[✓] Signing properties found"; rm "android/key.properties"; } \
		else echo "[x] Signing properties not found"; fi; \
	# TODO: Delete android/Gemfile and android/fastlane
	echo "[✓] Android clean complete."
