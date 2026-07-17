package com.elyasomar.apksigner.domain.repository

import com.elyasomar.apksigner.domain.model.KeystoreGenerationSuccess
import com.elyasomar.apksigner.domain.model.KeystoreSpec

/** Generates new keystores holding a single self-signed signing key. */
interface KeystoreRepository {

    /**
     * Generates a keystore per [spec] and writes it to the chosen folder.
     *
     * @throws com.elyasomar.apksigner.domain.model.SigningException on any
     *   user-recoverable failure, with a message safe to display.
     */
    suspend fun generateKeystore(spec: KeystoreSpec): KeystoreGenerationSuccess
}
