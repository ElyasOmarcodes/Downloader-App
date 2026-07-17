package com.elyasomar.apksigner.data.repository

import com.elyasomar.apksigner.data.inspect.CertificateInspector
import com.elyasomar.apksigner.data.keystore.KeystoreGenerator
import com.elyasomar.apksigner.data.storage.DocumentStorage
import com.elyasomar.apksigner.di.IoDispatcher
import com.elyasomar.apksigner.domain.model.KeystoreGenerationSuccess
import com.elyasomar.apksigner.domain.model.KeystoreSpec
import com.elyasomar.apksigner.domain.repository.KeystoreRepository
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.withContext
import javax.inject.Inject
import kotlin.coroutines.coroutineContext

/**
 * Generates a keystore off the main thread and writes it to the user-selected
 * folder. Passwords held in the spec are zeroed once generation completes.
 */
class KeystoreRepositoryImpl @Inject constructor(
    private val storage: DocumentStorage,
    private val generator: KeystoreGenerator,
    private val certificateInspector: CertificateInspector,
    @IoDispatcher private val ioDispatcher: CoroutineDispatcher,
) : KeystoreRepository {

    override suspend fun generateKeystore(spec: KeystoreSpec): KeystoreGenerationSuccess =
        withContext(ioDispatcher) {
            try {
                val generated = generator.generate(spec)
                coroutineContext.ensureActive()

                val certificateInfo = certificateInspector.inspect(generated.certificate)
                val fileName = ensureExtension(spec.fileName, spec.format.fileExtension)
                val savedName =
                    storage.writeBytesToTree(spec.outputTreeUri, generated.bytes, fileName)

                KeystoreGenerationSuccess(
                    outputFileName = savedName,
                    alias = generated.alias,
                    certificateInfo = certificateInfo,
                )
            } finally {
                spec.storePassword.fill(' ')
                spec.keyPassword.fill(' ')
            }
        }

    private fun ensureExtension(fileName: String, extension: String): String {
        val trimmed = fileName.trim().ifBlank { "keystore" }
        return if (trimmed.endsWith(".$extension", ignoreCase = true)) {
            trimmed
        } else {
            "$trimmed.$extension"
        }
    }
}
