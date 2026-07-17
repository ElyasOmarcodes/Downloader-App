package com.elyasomar.apksigner.data.keystore

import java.io.ByteArrayInputStream
import java.io.DataInputStream
import java.security.KeyFactory
import java.security.MessageDigest
import java.security.PrivateKey
import java.security.cert.CertificateFactory
import java.security.cert.X509Certificate
import java.security.spec.PKCS8EncodedKeySpec

/**
 * A self-contained reader for the Sun/Oracle "JKS" keystore format.
 *
 * The Android runtime does not ship a `JKS` [java.security.KeyStore] provider
 * (only `PKCS12`, `BKS`, `AndroidKeyStore`, …), yet JKS is the format produced
 * by `keytool` and the one most developers hold. This reader parses the JKS
 * container and recovers private keys using the documented SunJCE
 * "JavaKeyStore" key-protection algorithm, so `.jks` files work on-device
 * without any native provider.
 *
 * References: OpenJDK `sun.security.provider.JavaKeyStore` and `KeyProtector`.
 */
internal object JavaKeyStoreReader {

    private const val MAGIC = 0xFEEDFEED.toInt()
    private const val VERSION_1 = 1
    private const val VERSION_2 = 2
    private const val PRIVATE_KEY_TAG = 1
    private const val TRUSTED_CERT_TAG = 2
    private const val SALT_LENGTH = 20
    private const val DIGEST_LENGTH = 20

    /** True if [bytes] begin with the JKS magic marker. */
    fun matches(bytes: ByteArray): Boolean {
        if (bytes.size < 4) return false
        val magic = ((bytes[0].toInt() and 0xFF) shl 24) or
            ((bytes[1].toInt() and 0xFF) shl 16) or
            ((bytes[2].toInt() and 0xFF) shl 8) or
            (bytes[3].toInt() and 0xFF)
        return magic == MAGIC
    }

    data class Entry(
        val alias: String,
        val privateKey: PrivateKey,
        val certificateChain: List<X509Certificate>,
    )

    /**
     * Loads the private-key entry for [alias] (or the first private-key entry
     * when [alias] is null/blank). [keyPassword] falls back to [storePassword]
     * when empty, matching keytool's default.
     */
    fun load(
        bytes: ByteArray,
        storePassword: CharArray,
        keyPassword: CharArray,
        alias: String?,
    ): Entry {
        val effectiveKeyPassword = if (keyPassword.isNotEmpty()) keyPassword else storePassword
        val certFactory = CertificateFactory.getInstance("X.509")

        DataInputStream(ByteArrayInputStream(bytes)).use { input ->
            require(input.readInt() == MAGIC) { "Not a JKS keystore." }
            val version = input.readInt()
            require(version == VERSION_1 || version == VERSION_2) {
                "Unsupported JKS version: $version"
            }
            val entryCount = input.readInt()

            var firstMatch: Entry? = null
            for (i in 0 until entryCount) {
                val tag = input.readInt()
                val entryAlias = input.readUTF()
                input.readLong() // creation timestamp — unused

                when (tag) {
                    PRIVATE_KEY_TAG -> {
                        val encodedKey = ByteArray(input.readInt())
                        input.readFully(encodedKey)

                        val chainLength = input.readInt()
                        val chain = ArrayList<X509Certificate>(chainLength)
                        repeat(chainLength) {
                            if (version == VERSION_2) input.readUTF() // cert type
                            val certBytes = ByteArray(input.readInt())
                            input.readFully(certBytes)
                            chain.add(
                                certFactory.generateCertificate(
                                    ByteArrayInputStream(certBytes),
                                ) as X509Certificate,
                            )
                        }

                        val aliasMatches = alias.isNullOrBlank() ||
                            alias.equals(entryAlias, ignoreCase = true)
                        if (aliasMatches && firstMatch == null) {
                            val key = recoverKey(encodedKey, effectiveKeyPassword)
                            firstMatch = Entry(entryAlias, key, chain)
                        }
                    }

                    TRUSTED_CERT_TAG -> {
                        if (version == VERSION_2) input.readUTF() // cert type
                        val skip = input.readInt()
                        input.skipFully(skip)
                    }

                    else -> throw IllegalStateException("Unrecognized JKS entry tag: $tag")
                }
            }

            return firstMatch
                ?: throw IllegalArgumentException(
                    if (alias.isNullOrBlank()) {
                        "The keystore contains no private-key entry."
                    } else {
                        "No private-key entry found for alias '$alias'."
                    },
                )
        }
    }

    /**
     * Decrypts an encrypted private key using the SunJCE JavaKeyStore key
     * protector: a SHA-1 keystream XOR cipher with a trailing integrity digest.
     */
    private fun recoverKey(encodedKey: ByteArray, password: CharArray): PrivateKey {
        val protectedKey = extractEncryptedPayload(encodedKey)
        require(protectedKey.size >= SALT_LENGTH + DIGEST_LENGTH) {
            "Encrypted key is too short to be valid."
        }

        val encryptedLength = protectedKey.size - SALT_LENGTH - DIGEST_LENGTH
        val passwordBytes = password.toUtf16BeBytes()
        val digest = MessageDigest.getInstance("SHA-1")

        val plainKey = ByteArray(encryptedLength)
        var keystreamSeed = protectedKey.copyOfRange(0, SALT_LENGTH) // IV = salt
        var offset = 0
        while (offset < encryptedLength) {
            digest.update(passwordBytes)
            digest.update(keystreamSeed)
            keystreamSeed = digest.digest()

            val blockLength = minOf(DIGEST_LENGTH, encryptedLength - offset)
            for (j in 0 until blockLength) {
                plainKey[offset + j] =
                    (protectedKey[SALT_LENGTH + offset + j].toInt() xor keystreamSeed[j].toInt())
                        .toByte()
            }
            offset += blockLength
        }

        // Integrity check: SHA1(password || plainKey) must equal the trailer.
        digest.update(passwordBytes)
        digest.update(plainKey)
        val computed = digest.digest()
        val stored = protectedKey.copyOfRange(protectedKey.size - DIGEST_LENGTH, protectedKey.size)
        require(computed.contentEquals(stored)) {
            "Cannot recover key — wrong key password or corrupted keystore."
        }

        return toPrivateKey(plainKey)
    }

    /**
     * The stored blob is a DER `EncryptedPrivateKeyInfo`:
     *
     * ```
     * SEQUENCE {
     *   SEQUENCE { OID algorithm, params }   -- AlgorithmIdentifier
     *   OCTET STRING encryptedData
     * }
     * ```
     *
     * We only need the `encryptedData` octet string.
     */
    private fun extractEncryptedPayload(encoded: ByteArray): ByteArray {
        val reader = DerReader(encoded)
        reader.expect(0x30) // outer SEQUENCE
        reader.readLength()
        reader.expect(0x30) // AlgorithmIdentifier SEQUENCE
        reader.skip(reader.readLength())
        reader.expect(0x04) // OCTET STRING
        val length = reader.readLength()
        return reader.readBytes(length)
    }

    /** Builds a [PrivateKey] from a PKCS#8 encoding, probing common algorithms. */
    private fun toPrivateKey(pkcs8: ByteArray): PrivateKey {
        val spec = PKCS8EncodedKeySpec(pkcs8)
        var lastError: Exception? = null
        for (algorithm in arrayOf("RSA", "EC", "DSA")) {
            try {
                return KeyFactory.getInstance(algorithm).generatePrivate(spec)
            } catch (e: Exception) {
                lastError = e
            }
        }
        throw IllegalStateException("Unsupported private-key algorithm.", lastError)
    }

    private fun CharArray.toUtf16BeBytes(): ByteArray {
        val out = ByteArray(size * 2)
        for (i in indices) {
            val code = this[i].code
            out[i * 2] = (code ushr 8).toByte()
            out[i * 2 + 1] = code.toByte()
        }
        return out
    }

    private fun DataInputStream.skipFully(count: Int) {
        var remaining = count
        while (remaining > 0) {
            val skipped = skipBytes(remaining)
            if (skipped <= 0) {
                if (read() < 0) throw java.io.EOFException()
                remaining--
            } else {
                remaining -= skipped
            }
        }
    }

    /** Minimal forward-only DER reader for the fixed structures used above. */
    private class DerReader(private val data: ByteArray) {
        private var pos = 0

        fun expect(tag: Int) {
            val actual = data[pos++].toInt() and 0xFF
            require(actual == tag) {
                "Malformed DER: expected tag 0x%02X but found 0x%02X.".format(tag, actual)
            }
        }

        fun readLength(): Int {
            var length = data[pos++].toInt() and 0xFF
            if (length and 0x80 != 0) {
                val byteCount = length and 0x7F
                require(byteCount in 1..4) { "Unsupported DER length encoding." }
                length = 0
                repeat(byteCount) { length = (length shl 8) or (data[pos++].toInt() and 0xFF) }
            }
            return length
        }

        fun skip(count: Int) {
            pos += count
        }

        fun readBytes(count: Int): ByteArray {
            val slice = data.copyOfRange(pos, pos + count)
            pos += count
            return slice
        }
    }
}
