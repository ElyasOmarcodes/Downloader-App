package com.elyasomar.apksigner.ui.keystore

import com.elyasomar.apksigner.domain.model.KeyAlgorithm
import com.elyasomar.apksigner.domain.model.KeystoreFormat
import com.elyasomar.apksigner.domain.model.KeystoreGenerationSuccess
import com.elyasomar.apksigner.ui.signer.SelectedDocument

/** Complete, immutable snapshot of the "Create Keystore" screen. */
data class KeystoreUiState(
    val outputFolder: SelectedDocument? = null,
    val fileName: String = "my-release-key",
    val format: KeystoreFormat = KeystoreFormat.JKS,
    val algorithm: KeyAlgorithm = KeyAlgorithm.RSA_2048,
    val alias: String = "key0",
    val storePassword: String = "",
    val keyPassword: String = "",
    val validityYears: String = "25",
    val commonName: String = "",
    val organizationalUnit: String = "",
    val organization: String = "",
    val locality: String = "",
    val state: String = "",
    val country: String = "",
    val isGenerating: Boolean = false,
    val result: KeystoreGenerationSuccess? = null,
    val errorMessage: String? = null,
) {
    private val validityValid: Boolean
        get() = validityYears.toIntOrNull()?.let { it in 1..1000 } == true

    /** Whether the form holds everything required to generate a keystore. */
    val canGenerate: Boolean
        get() = !isGenerating &&
            outputFolder != null &&
            fileName.isNotBlank() &&
            alias.isNotBlank() &&
            commonName.isNotBlank() &&
            storePassword.length >= MIN_PASSWORD_LENGTH &&
            keyPassword.length >= MIN_PASSWORD_LENGTH &&
            validityValid

    companion object {
        const val MIN_PASSWORD_LENGTH = 6
    }
}
