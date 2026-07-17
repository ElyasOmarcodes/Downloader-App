# APK Signer

A modern Android application for signing APK files, built with **Kotlin** and
**Jetpack Compose**. Signing is performed on-device by the official
`com.android.tools.build:apksig` library — the exact engine behind the
command-line `apksigner` tool.

## Features

### Sign
- **Select an APK or an AAB** (Android App Bundle) via the Storage Access
  Framework.
- **Select a keystore** — `.jks` (Java KeyStore) and `.p12/.pfx` (PKCS#12)
  are both supported.
- **Enter credentials** — keystore password, key alias, and an optional key
  password (defaults to the keystore password when left blank).
- **Choose signature schemes** — V1 (JAR), V2, V3 and V4 for APKs (V2/V3/V4 on
  by default). App bundles are signed with a JAR (v1) signature, as the Play
  Console expects.
- **Sign** with a single tap; the signed artifact (plus the V4 `.idsig`
  companion for APKs, when applicable) is written to a folder you choose.
- **APK & certificate summary** — package name, version, min SDK, certificate
  subject/issuer, serial, signature algorithm, **SHA-256 fingerprint** and
  **validity** dates.

### Create Keystore
- **Generate a new signing key** with a self-signed certificate and save it as
  a **JKS** or **PKCS#12** keystore.
- Choose the **algorithm** (RSA 2048/4096 or EC P-256), **alias**, **validity**,
  keystore/key **passwords**, and the certificate **Distinguished Name**
  (CN, OU, O, L, ST, C).

### Everywhere
- **Clear feedback** — a progress indicator during work, and explicit success or
  error messages afterwards.
- **Material 3** design with dynamic color and full **light / dark** support.

## Architecture

The project follows **MVVM** with a clean separation of layers:

```
ui/            Jetpack Compose screens (tabbed: Sign / Create Keystore),
               Material 3 theme, ViewModels + UI state
domain/        Models, repository contracts, error types
data/          Repository implementations and services:
  keystore/    JKS reader & writer, unified KeystoreLoader (PKCS12/BKS/JKS),
               KeystoreGenerator (keypair + self-signed cert)
  signing/     ApkSignerService (apksig) and JarSignerService (AAB, JAR/CMS)
  inspect/     APK and certificate metadata extraction
  storage/     Storage Access Framework <-> File bridging
di/            Hilt modules (repository bindings, dispatcher qualifier)
```

App bundle signing and certificate generation are backed by **BouncyCastle**
(certificate creation and CMS/PKCS#7 signature blocks). This adds to the APK
size but is required for on-device keystore generation and JAR signing.

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
