# sarsys mobile

SarSys Mobile is dependent on SarSys API.

## Prepare release toolchain
Requires `make` on `PATH`

1. Request upload keys and passwords from @kengu
2. Install dependencies with `make toolchain`
3. Configure apps for release with `make configure`

## Build models

```bash
> make models
```

## Release management for Android
* Release to internal test track: `make android-release-internal`