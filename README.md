# SARSys App

SarSys App is dependent on SARSys API.

## Prepare release toolchain
Requires `make` on `PATH`

1. Request upload keys and passwords from @kengu
2. Install dependencies with `make toolchain`
3. Configure apps for release with `make configure`

## Build models

```bash
> make models
```

## Deploy to local android device
```
> flutter build appbundle
> bundletool build-apks --bundle=build/app/outputs/bundle/release/app.aab --output=build/app/outputs/bundle/release/app.apks --connected-device
> bundletool install-apks --apks=build/app/outputs/bundle/release/app.apks
```

## Release management for Android
* Release to internal test track: `make android-release-internal`

## Release management for iOS
* Release to beta test track: `make ios-release-beta`