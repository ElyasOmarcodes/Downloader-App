# APK Signer

A modern Android application for signing APK files, built with **Kotlin** and
**Jetpack Compose**. Signing is performed on-device by the official
`com.android.tools.build:apksig` library — the exact engine behind the
command-line `apksigner` tool.

## Features

- **Select an APK** to sign via the Storage Access Framework.
- **Select a keystore** — `.jks` (Java KeyStore) and `.p12/.pfx` (PKCS#12)
  are both supported.
- **Enter credentials** — keystore password, key alias, and an optional key
  password (defaults to the keystore password when left blank).
- **Choose signature schemes** — V1 (JAR), V2, V3 and V4. By default **V2, V3
  and V4** are enabled, matching modern `apksigner` recommendations.
- **Sign** with a single tap; the signed APK (and the V4 `.idsig` companion,
  when applicable) is written to a folder you choose.
- **Clear feedback** — a progress indicator while signing, and an explicit
  success or error message afterwards.
- **APK & certificate summary** — package name, version, min SDK, certificate
  subject/issuer, serial, signature algorithm, **SHA-256 fingerprint** and
  **validity** dates.
- **Material 3** design with dynamic color and full **light / dark** support.

## Architecture

The project follows **MVVM** with a clean separation of layers:

```
ui/            Jetpack Compose screens, Material 3 theme, ViewModel + UI state
domain/        Models, the SigningRepository contract, error types
data/          Repository implementation and services:
  keystore/    JKS reader + unified KeystoreLoader (PKCS12 / BKS / JKS)
  signing/     ApkSignerService (wraps the official apksig library)
  inspect/     APK and certificate metadata extraction
  storage/     Storage Access Framework <-> File bridging
di/            Hilt modules (repository binding, dispatcher qualifier)
```

- **Hilt** for dependency injection.
- **Coroutines** run all I/O and cryptographic work off the main thread.
- **StateFlow** drives an immutable, single-source-of-truth UI state.

### On-device JKS support

Android ships no `JKS` `KeyStore` provider (only `PKCS12`, `BKS`,
`AndroidKeyStore`, …), yet JKS is the format `keytool` produces by default.
`data/keystore/JavaKeyStoreReader.kt` is a self-contained reader for the JKS
container and the SunJCE key-protection algorithm, so `.jks` files work
on-device with no native provider. PKCS#12 and BKS keystores are delegated to
the platform providers.

## Requirements

- Android Studio (Ladybug or newer recommended)
- Android SDK 34
- JDK 17
- Minimum device: Android 8.0 (API 26)

## Building

```bash
./gradlew assembleDebug        # build a debug APK
./gradlew installDebug         # build and install on a connected device
./gradlew assembleRelease      # build a minified release APK
```

## Security note

Keystore bytes and passwords are held only in memory for the duration of a
signing operation and are zeroed out immediately afterwards. Nothing sensitive
is written to disk, logged, or included in backups.
