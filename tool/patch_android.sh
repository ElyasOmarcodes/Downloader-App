#!/usr/bin/env bash
# Post-processes the Android project scaffolded by `flutter create` so it can
# build MediaGrab:
#   1. adds the runtime permissions the app needs, and
#   2. enables core-library desugaring (required by flutter_local_notifications).
# Idempotent — safe to run repeatedly.
set -euo pipefail

MANIFEST="android/app/src/main/AndroidManifest.xml"
GRADLE="android/app/build.gradle"

# --- 1. Permissions --------------------------------------------------------
if [[ ! -f "$MANIFEST" ]]; then
  echo "Manifest not found at $MANIFEST" >&2
  exit 1
fi

if grep -q "android.permission.INTERNET" "$MANIFEST"; then
  echo "Permissions already present."
else
  # Pass the permission block through the environment so the perl program
  # itself contains no XML (the '/>' in the tags would otherwise clash with
  # the s/// delimiter). The /e flag evaluates the replacement as code.
  export MG_PERMS=$'    <uses-permission android:name="android.permission.INTERNET"/>\n    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>\n    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>\n    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="28"/>\n    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32"/>\n    <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>'
  perl -0pi -e 's/(<manifest\b[^>]*>)/$1 . "\n" . $ENV{MG_PERMS}/e' "$MANIFEST"
  echo "Patched permissions into $MANIFEST."
fi

# --- 2. Core-library desugaring -------------------------------------------
if [[ ! -f "$GRADLE" ]]; then
  echo "Gradle file not found at $GRADLE (Kotlin DSL?), skipping desugar." >&2
  exit 0
fi

if grep -q "coreLibraryDesugaringEnabled" "$GRADLE"; then
  echo "Desugaring already configured."
else
  # Enable the flag inside the existing compileOptions block.
  perl -0pi -e 's/(compileOptions\s*\{)/$1\n        coreLibraryDesugaringEnabled true/' "$GRADLE"
  # Append the desugar dependency (Groovy merges multiple dependencies blocks).
  cat >> "$GRADLE" <<'EOF'

dependencies {
    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.2'
}
EOF
  echo "Enabled core-library desugaring in $GRADLE."
fi
