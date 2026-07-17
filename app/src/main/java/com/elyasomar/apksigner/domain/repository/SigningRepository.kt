package com.elyasomar.apksigner.domain.repository

import com.elyasomar.apksigner.domain.model.SigningRequest
import com.elyasomar.apksigner.domain.model.SigningSuccess

/** Orchestrates the complete "load key → sign → export" pipeline. */
interface SigningRepository {

    /**
     * Signs the APK described by [request] and writes the result into the
     * user-selected output folder.
     *
     * @throws com.elyasomar.apksigner.domain.model.SigningException on any
     *   user-recoverable failure, with a message safe to display.
     */
    suspend fun signApk(request: SigningRequest): SigningSuccess
}
