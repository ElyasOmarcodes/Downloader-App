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
  export MG_PERMS=$'    <uses-permission android:name="android.permission.INTERNET"/>\n    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>\n    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>\n    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="28"/>\n    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32"/>\n    <uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE"/>\n    <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>'
  perl -0pi -e 's/(<manifest\b[^>]*>)/$1 . "\n" . $ENV{MG_PERMS}/e' "$MANIFEST"
  echo "Patched permissions into $MANIFEST."
fi

# --- 1b. Share-intent filter (receive_sharing_intent) ----------------------
if grep -q 'action.SEND' "$MANIFEST"; then
  echo "Share intent-filter already present."
else
  export MG_SHARE=$'        <intent-filter>\n            <action android:name="android.intent.action.SEND"/>\n            <category android:name="android.intent.category.DEFAULT"/>\n            <data android:mimeType="text/*"/>\n        </intent-filter>'
  # Inject the SEND intent-filter just before the activity closes.
  perl -0pi -e 's/(\s*<\/activity>)/"\n" . $ENV{MG_SHARE} . $1/e' "$MANIFEST"
  echo "Patched share intent-filter into $MANIFEST."
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

# --- 3. Align JVM target to 17 across all modules -------------------------
# Some plugins (e.g. receive_sharing_intent) compile Kotlin at JVM 17 while the
# Flutter template defaults Java to 1.8, which Gradle rejects. Force every
# module to Java/Kotlin 17.
ROOT_GRADLE="android/build.gradle"
if [[ -f "$ROOT_GRADLE" ]] && ! grep -q "MediaGrab JVM 17" "$ROOT_GRADLE"; then
  cat >> "$ROOT_GRADLE" <<'EOF'

// MediaGrab JVM 17 alignment: keep Java and Kotlin on the same target so
// plugins compiled at 17 don't clash with a Java 1.8 default. Uses lazy
// plugin/task hooks (no afterEvaluate) so it is safe even for subprojects the
// Flutter template evaluates early via evaluationDependsOn(':app').
subprojects {
    tasks.withType(org.jetbrains.kotlin.gradle.tasks.KotlinCompile).configureEach {
        kotlinOptions {
            jvmTarget = "17"
        }
    }
    plugins.withId("com.android.application") {
        extensions.getByName("android").compileOptions {
            sourceCompatibility JavaVersion.VERSION_17
            targetCompatibility JavaVersion.VERSION_17
        }
    }
    plugins.withId("com.android.library") {
        extensions.getByName("android").compileOptions {
            sourceCompatibility JavaVersion.VERSION_17
            targetCompatibility JavaVersion.VERSION_17
        }
    }
}
EOF
  echo "Appended JVM 17 alignment to $ROOT_GRADLE."
fi
