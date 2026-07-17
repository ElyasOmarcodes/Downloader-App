package com.elyasomar.apksigner.domain.model

/**
 * Raised for any user-recoverable failure during signing (wrong password,
 * missing alias, unreadable APK, …). The [message] is safe to show directly
 * to the user.
 */
class SigningException(message: String, cause: Throwable? = null) :
    Exception(message, cause)
