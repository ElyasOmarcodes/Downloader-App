package com.elyasomar.apksigner.ui.signer

import android.net.Uri
import com.elyasomar.apksigner.domain.model.SignatureVersions
import com.elyasomar.apksigner.domain.model.SigningSuccess

/** A user-selected document plus its display name for the UI. */
data class SelectedDocument(
    val uri: Uri,
    val displayName: String,
)

/** Complete, immutable snapshot of the signer screen. */
data class SignerUiState(
    val apk: SelectedDocument? = null,
    val keystore: SelectedDocument? = null,
    val outputFolder: SelectedDocument? = null,
    val keystorePassword: String = "",
    val keyAlias: String = "",
    val keyPassword: String = "",
    val versions: SignatureVersions = SignatureVersions(),
    val isSigning: Boolean = false,
    val result: SigningSuccess? = null,
    val errorMessage: String? = null,
) {
    /** True when the selected artifact is an app bundle (.aab) rather than an APK. */
    val isBundleSelected: Boolean
        get() = apk?.displayName?.endsWith(".aab", ignoreCase = true) == true

    /** Whether the form holds everything required to start signing. */
    val canSign: Boolean
        get() = !isSigning &&
            apk != null &&
            keystore != null &&
            outputFolder != null &&
            keystorePassword.isNotEmpty() &&
            (isBundleSelected || versions.hasAnyEnabled)
}
