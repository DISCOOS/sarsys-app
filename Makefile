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
storePassword = "$$(grep "storePassword" android/key.properties | cut -d'=' -f2)"

# Global values
ios_certificate = "XKXT735ZZ4"

.PHONY: \
	doctor toolchain configure test build install clean \
	models \
	android-configure android-build android-install android-build-without-tests \
	android-release-internal android-clean \
	ios-configure ios-build ios-release-beta ios-clean
.SILENT: \
	doctor toolchain configure test build install clean \
	models \
	android-configure android-build android-install android-build-without-tests \
	android-release-internal android-clean \
	ios-configure ios-build ios-release-beta ios-clean

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

toolchain:
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
		else echo "[!] Installing bundletool"; brew install bundletool; fi
	if hash fastlane 2>/dev/null; \
		then echo "[✓] fastlane is installed."; \
		else echo "[!] Installing fastlane"; brew cask install fastlane; fi
	if hash bundle 2>/dev/null; \
		then echo "[✓] bundler is installed."; \
		else echo "[!] Installing bundler"; sudo gem install bundler; fi
endif

configure: android-configure ios-configure

android-configure:
	echo "Initialize Android configuration..."; \
	read -p "> Enter path to upload key: " path; \
	if [ -f $$path ]; then \
		read -p "> Enter upload keystore password: " pwd; \
		echo "storePassword=$$pwd" > android/key.properties; \
		echo "keyPassword=$$pwd" >> android/key.properties; \
		echo "keyAlias=upload" >> android/key.properties; \
		echo "storeFile=$$path" >> android/key.properties; \
		echo "> Initializing fastlane..."; cd android; fastlane init; \
		echp "[✓] Android configuration complete."
	else \
		echo "[x] Android upload key $$path NOT FOUND, Skipping."; \
	fi

ios-configure:
	echo "Initialize iOS configuration..."; \
	echo "> Download iOS Distribution certificate:"; \
	echo "1. Open https://developer.apple.com/account/resources/certificates/download/$(ios_certificate)"; \
	echo "2. Download certificate to local machine"; \
	echo "3. Install sertificate (double click)"; \
	read -n 1 -s -r -p "Press any key to continue"; echo;\
	echo "open https://developer.apple.com/account/resources/certificates/download/$(ios_certificate)";
	open "https://developer.apple.com/account/resources/certificates/download/$(ios_certificate)"; \
	read -n 1 -p "Ready to continue (y/n)? " answer; \
	if [ "$$answer" == "" ] || [ "$$answer" == "y" ] || [ "$$answer" == "Y" ]; then \
		echo "> Configure signing releases with distribution certificate" ; \
		echo "1. Open ios/Runner.xcodeproj with XCode"; \
		echo "2. Goto TARGEST > Runner > Signing > Code Signing Identify > Release"; \
		echo "3. Change signing of 'Any iOS SDK' to 'iPhone Distribution: DISCO Open Source (G2C47B233E)'"; \
		read -n 1 -s -r -p "Press any key to continue"; echo; \
		echo "open ios/Runner.xcodeproj"; \
		open ios/Runner.xcodeproj; \
		read -n 1 -p "Ready to continue (y/n)? " answer; \
		if [ "$$answer" == "" ] || [ "$$answer" == "y" ] || [ "$$answer" == "Y" ]; then \
			echo "> Initializing fastlane..."; cd ios; fastlane init; \
			echo "[✓] iOS configuration complete."; \
		else echo; echo "[!] iOS configuration aborted."; fi \
	else echo; echo "[!] Initialize iOS configuration aborted."; fi \

test:
	echo "Running flutter tests...";
	echo "Testing proj4d..."
	flutter test test/proj4d.dart
	echo "Testing UserBloc..."
	flutter test test/blocs/user_tests.dart
	echo "Testing AppConfigBloc..."
	flutter test test/blocs/app_config_tests.dart
	echo "Testing AffiliationBloc..."
	flutter test test/blocs/affiliation_tests.dart
	echo "Testing OperationBloc..."
	flutter test test/blocs/operation_tests.dart
	echo "Testing DeviceBloc..."
	flutter test test/blocs/device_tests.dart
	echo "Testing PersonnelBloc..."
	flutter test test/blocs/personnel_tests.dart
	echo "Testing UnitBloc..."
	flutter test test/blocs/unit_tests.dart
	echo "Testing TrackingBloc..."
	flutter test test//utils/tracking_utils_tests.dart
#	flutter test test/blocs/tracking_tests.dart
	echo "[✓] Flutter tests complete."

models:
	echo "Generating models..."; \
	flutter packages pub run build_runner build --delete-conflicting-outputs; \
	echo "[✓] Generating models complete."

build: models test android-build ios-build
	echo "[✓] Flutter build complete."

android-build: test android-build-without-tests

android-build-without-tests:
	test ! -f "$(storeFile)" && \
		{ echo "Android upload key $(storeFile) does not exist > run 'make android-init'";  exit 0; }; \
	echo "Building Android app bundle..."; \
	flutter build appbundle
	echo "[✓] Flutter build for Android complete."

ios-build: test
	echo "Building iOS app runner..."; \
	flutter build ios --release --no-codesign; \
	echo "[✓] Flutter build for iOS complete."

install: android-install

android-install: android-build
	echo "Building Android APK set archive..."; \
	echo "> output: build/app/outputs/sarsys.apks"
	bundletool build-apks \
		--bundle=build/app/outputs/bundle/release/app.aab \
		--output=build/app/outputs/sarsys.apks \
		--ks=$(storeFile) \
		--ks-pass=pass:$(storePassword)\
		--ks-key-alias=upload \
		--overwrite; \
	echo "Deploy to connected android devices"; \
	bundletool install-apks --apks=build/app/outputs/sarsys.apks

android-release-internal: android-build
	echo "Release to Google Play 'internal test' with fastlane..."
	cd android; \
	bundle exec fastlane supply --aab ../build/app/outputs/bundle/release/app-release.aab --track internal
	echo "[✓] Release to Google Play 'internal test' complete."

ios-release-beta: ios-build
	echo "Release to Apple Store 'testflight' with fastlane..."
	cd ios; \
	bundle exec fastlane beta
	echo "[✓] Release to Apple Store 'testflight' complete."

clean: android-clean ios-clean
	echo "[✓] Clean all configurations. Complete."

android-clean:
	echo "Clean Android app configuration"; \
	if [ -f  "android/key.properties" ] ; \
		then { echo "[✓] Signing properties found"; rm "android/key.properties"; } \
		else echo "[x] Signing properties not found"; fi; \
	# TODO: Delete android/Gemfile* and android/fastlane
	echo "[✓] Android clean configuration. Complete."

ios-clean:
	echo "Clean iOS app configuration"; \
	# TODO: Delete ios/Gemfile* and ios/fastlane
	echo "[✓] iOS clean configuration complete."
