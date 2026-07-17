package com.elyasomar.apksigner.data.signing

import com.android.apksig.ApkSigner
import com.android.apksig.apk.MinSdkVersionException
import com.elyasomar.apksigner.data.keystore.LoadedKey
import com.elyasomar.apksigner.domain.model.SignatureVersions
import com.elyasomar.apksigner.domain.model.SigningException
import java.io.File
import java.security.InvalidKeyException
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Signs an APK using [ApkSigner] from `com.android.tools.build:apksig` — the
 * exact library that backs the command-line `apksigner` tool. Working on plain
 * [File]s keeps the API identical to the desktop tool; the repository is
 * responsible for staging content-URIs into cache files first.
 */
@Singleton
class ApkSignerService @Inject constructor() {

    /**
     * @param idSignatureFile destination for the V4 `.idsig` companion file;
     *   required (and only used) when [SignatureVersions.v4] is enabled.
     */
    fun sign(
        inputApk: File,
        outputApk: File,
        idSignatureFile: File?,
        key: LoadedKey,
        versions: SignatureVersions,
    ) {
        val signerConfig = ApkSigner.SignerConfig.Builder(
            key.alias.ifBlank { "CERT" },
            key.privateKey,
            key.certificateChain,
        ).build()

        val builder = ApkSigner.Builder(listOf(signerConfig))
            .setInputApk(inputApk)
            .setOutputApk(outputApk)
            .setV1SigningEnabled(versions.v1)
            .setV2SigningEnabled(versions.v2)
            .setV3SigningEnabled(versions.v3)
            .setV4SigningEnabled(versions.v4)

        if (versions.v4) {
            val idsig = idSignatureFile
                ?: throw SigningException("A V4 signature output path is required.")
            builder.setV4SignatureOutputFile(idsig)
        }

        try {
            builder.build().sign()
        } catch (e: MinSdkVersionException) {
            throw SigningException(
                "Could not determine the APK's minimum SDK version. " +
                    "The file may be corrupt or not a valid APK.",
                e,
            )
        } catch (e: InvalidKeyException) {
            throw SigningException(
                "The signing key is not compatible with the selected signature schemes.",
                e,
            )
        } catch (e: Exception) {
            throw SigningException(
                e.message?.takeIf { it.isNotBlank() } ?: "APK signing failed.",
                e,
            )
        }
    }
}
