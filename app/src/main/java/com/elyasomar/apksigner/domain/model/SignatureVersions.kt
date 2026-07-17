package com.elyasomar.apksigner.domain.model

/**
 * The set of APK signature schemes to apply. By default V2, V3 and V4 are
 * enabled while the legacy V1 (JAR) scheme is left off, matching modern
 * `apksigner` recommendations.
 */
data class SignatureVersions(
    val v1: Boolean = false,
    val v2: Boolean = true,
    val v3: Boolean = true,
    val v4: Boolean = true,
) {
    /** At least one scheme must be selected for signing to be possible. */
    val hasAnyEnabled: Boolean
        get() = v1 || v2 || v3 || v4

    /**
     * V4 signatures anchor their Merkle tree to a V2 or V3 signature, so V4
     * can only be produced when at least one of those is also enabled.
     */
    val isV4Satisfied: Boolean
        get() = !v4 || v2 || v3
}
