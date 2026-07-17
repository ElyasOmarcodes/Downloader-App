# Keep the APK signing library intact — it relies on reflection-free but
# security-sensitive class structures that must not be renamed away.
-keep class com.android.apksig.** { *; }
-dontwarn com.android.apksig.**

# Conscrypt / BouncyCastle providers referenced by the signing stack are optional.
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**

# Optional compile-time annotations referenced by apksig / Guava-style code.
-dontwarn javax.annotation.**
-dontwarn com.google.errorprone.annotations.**
-dontwarn org.checkerframework.**
