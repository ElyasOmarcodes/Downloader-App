package com.elyasomar.apksigner.data.keystore

import com.elyasomar.apksigner.domain.model.SigningException
import java.io.ByteArrayInputStream
import java.security.KeyStore
import java.security.PrivateKey
import java.security.UnrecoverableKeyException
import java.security.cert.X509Certificate
import javax.inject.Inject
import javax.inject.Singleton

/** A private key together with its certificate chain, ready for signing. */
data class LoadedKey(
    val alias: String,
    val privateKey: PrivateKey,
    val certificateChain: List<X509Certificate>,
)

/**
 * Loads a signing key from raw keystore bytes. JKS containers are handled by
 * [JavaKeyStoreReader]; everything else is delegated to the platform
 * [KeyStore] providers (`PKCS12`, then `BKS`).
 */
@Singleton
class KeystoreLoader @Inject constructor() {

    fun load(
        keystoreBytes: ByteArray,
        storePassword: CharArray,
        keyAlias: String,
        keyPassword: CharArray,
    ): LoadedKey {
        if (JavaKeyStoreReader.matches(keystoreBytes)) {
            return loadJks(keystoreBytes, storePassword, keyAlias, keyPassword)
        }
        return loadPlatform(keystoreBytes, storePassword, keyAlias, keyPassword)
    }

    private fun loadJks(
        bytes: ByteArray,
        storePassword: CharArray,
        keyAlias: String,
        keyPassword: CharArray,
    ): LoadedKey {
        val entry = try {
            JavaKeyStoreReader.load(bytes, storePassword, keyPassword, keyAlias)
        } catch (e: IllegalArgumentException) {
            throw SigningException(e.message ?: "Failed to read the JKS keystore.", e)
        } catch (e: IllegalStateException) {
            throw SigningException(e.message ?: "Failed to read the JKS keystore.", e)
        }
        if (entry.certificateChain.isEmpty()) {
            throw SigningException("The selected key has no certificate chain.")
        }
        return LoadedKey(entry.alias, entry.privateKey, entry.certificateChain)
    }

    private fun loadPlatform(
        bytes: ByteArray,
        storePassword: CharArray,
        keyAlias: String,
        keyPassword: CharArray,
    ): LoadedKey {
        val effectiveKeyPassword = if (keyPassword.isNotEmpty()) keyPassword else storePassword
        var lastError: Exception? = null

        for (type in PLATFORM_TYPES) {
            val keyStore = runCatching { KeyStore.getInstance(type) }.getOrNull() ?: continue
            try {
                keyStore.load(ByteArrayInputStream(bytes), storePassword)
            } catch (e: Exception) {
                lastError = e
                continue // Not this format, or wrong store password — try the next type.
            }

            val alias = resolveAlias(keyStore, keyAlias)
            val key = try {
                keyStore.getKey(alias, effectiveKeyPassword) as? PrivateKey
            } catch (e: UnrecoverableKeyException) {
                throw SigningException("Wrong key password for alias '$alias'.", e)
            } ?: throw SigningException("Alias '$alias' is not a private-key entry.")

            val chain = keyStore.getCertificateChain(alias)
                ?.filterIsInstance<X509Certificate>()
                .orEmpty()
            if (chain.isEmpty()) {
                throw SigningException("The selected key has no certificate chain.")
            }
            return LoadedKey(alias, key, chain)
        }

        throw SigningException(
            "Unable to read the keystore. Check that the file and keystore password are correct.",
            lastError,
        )
    }

    private fun resolveAlias(keyStore: KeyStore, requested: String): String {
        if (requested.isNotBlank()) {
            if (!keyStore.containsAlias(requested)) {
                throw SigningException("No entry found for alias '$requested'.")
            }
            return requested
        }
        val aliases = keyStore.aliases()
        while (aliases.hasMoreElements()) {
            val alias = aliases.nextElement()
            if (keyStore.isKeyEntry(alias)) return alias
        }
        throw SigningException("The keystore contains no private-key entry.")
    }

    private companion object {
        val PLATFORM_TYPES = listOf("PKCS12", "BKS")
    }
}
