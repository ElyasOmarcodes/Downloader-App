package com.elyasomar.apksigner.domain.model

import android.net.Uri

/**
 * A fully specified request to sign an APK. All fields are validated by the
 * repository before any file I/O or cryptographic work begins.
 */
data class SigningRequest(
    val apkUri: Uri,
    val keystoreUri: Uri,
    val outputTreeUri: Uri,
    val keystorePassword: CharArray,
    val keyAlias: String,
    val keyPassword: CharArray,
    val versions: SignatureVersions,
) {
    // CharArray-based equals/hashCode are intentionally identity-like; these
    // requests are never compared or used as map keys, but the overrides keep
    // the linter and data-class contract honest.
    override fun equals(other: Any?): Boolean = this === other

    override fun hashCode(): Int = System.identityHashCode(this)
}

/** Human-readable metadata extracted from the APK being signed. */
data class ApkInfo(
    val packageName: String,
    val versionName: String,
    val versionCode: Long,
    val minSdk: Int,
)

/** Human-readable metadata about the signing certificate. */
data class CertificateInfo(
    val subject: String,
    val issuer: String,
    val serialNumber: String,
    val sha256Fingerprint: String,
    val signatureAlgorithm: String,
    val validFrom: String,
    val validUntil: String,
    val isCurrentlyValid: Boolean,
)

/** Outcome of a completed signing operation. */
data class SigningSuccess(
    val outputFileName: String,
    val apkInfo: ApkInfo,
    val certificateInfo: CertificateInfo,
)
