package com.elyasomar.apksigner.domain.model

import android.net.Uri

/** Output container format for a generated keystore. */
enum class KeystoreFormat(val displayName: String, val fileExtension: String) {
    JKS("JKS", "jks"),
    PKCS12("PKCS12", "p12"),
}

/** Supported signing-key algorithms for generation. */
enum class KeyAlgorithm(val displayName: String, val jcaName: String, val defaultKeySize: Int) {
    RSA_2048("RSA 2048", "RSA", 2048),
    RSA_4096("RSA 4096", "RSA", 4096),
    EC_P256("EC P-256", "EC", 256),
}

/** Everything required to generate a new keystore holding one self-signed key. */
data class KeystoreSpec(
    val outputTreeUri: Uri,
    val fileName: String,
    val format: KeystoreFormat,
    val algorithm: KeyAlgorithm,
    val alias: String,
    val storePassword: CharArray,
    val keyPassword: CharArray,
    val validityYears: Int,
    val commonName: String,
    val organizationalUnit: String,
    val organization: String,
    val locality: String,
    val state: String,
    val country: String,
) {
    override fun equals(other: Any?): Boolean = this === other

    override fun hashCode(): Int = System.identityHashCode(this)
}

/** Result of a completed keystore-generation operation. */
data class KeystoreGenerationSuccess(
    val outputFileName: String,
    val alias: String,
    val certificateInfo: CertificateInfo,
)
