package com.elyasomar.apksigner.data.keystore

import java.io.ByteArrayOutputStream
import java.io.DataOutputStream
import java.security.MessageDigest
import java.security.PrivateKey
import java.security.SecureRandom
import java.security.cert.X509Certificate

/**
 * Writes a private-key entry into the Sun/Oracle "JKS" keystore format.
 *
 * Android has no `JKS` [java.security.KeyStore] provider, so this produces the
 * container by hand — the exact inverse of [JavaKeyStoreReader]. The private key
 * is protected with the SunJCE "JavaKeyStore" key-protection algorithm and the
 * store is sealed with the standard trailing SHA-1 integrity digest, so the
 * result loads in `keytool` and any JDK JKS reader.
 */
internal object JavaKeyStoreWriter {

    private const val MAGIC = 0xFEEDFEED.toInt()
    private const val VERSION_2 = 2
    private const val PRIVATE_KEY_TAG = 1
    private const val KEY_PROTECTOR_OID = "1.3.6.1.4.1.42.2.17.1.1"
    private const val SALT_LENGTH = 20

    // Salt phrase mixed into the store integrity digest by the JKS format.
    private val STORE_DIGEST_SALT = "Mighty Aphrodite".toByteArray(Charsets.UTF_8)

    fun write(
        alias: String,
        privateKey: PrivateKey,
        certificateChain: List<X509Certificate>,
        storePassword: CharArray,
        keyPassword: CharArray,
    ): ByteArray {
        val body = ByteArrayOutputStream()
        DataOutputStream(body).use { out ->
            out.writeInt(MAGIC)
            out.writeInt(VERSION_2)
            out.writeInt(1) // a single private-key entry
            out.writeInt(PRIVATE_KEY_TAG)
            out.writeUTF(alias)
            out.writeLong(System.currentTimeMillis())

            val protectedKey = protectKey(privateKey.encoded, keyPassword)
            out.writeInt(protectedKey.size)
            out.write(protectedKey)

            out.writeInt(certificateChain.size)
            for (certificate in certificateChain) {
                out.writeUTF("X.509")
                val encoded = certificate.encoded
                out.writeInt(encoded.size)
                out.write(encoded)
            }
        }

        val bodyBytes = body.toByteArray()
        val checksum = MessageDigest.getInstance("SHA-1").apply {
            update(storePassword.toUtf16BeBytes())
            update(STORE_DIGEST_SALT)
            update(bodyBytes)
        }.digest()

        return bodyBytes + checksum
    }

    /**
     * Encrypts a PKCS#8 private key with the SunJCE key protector and wraps it
     * in a DER `EncryptedPrivateKeyInfo`.
     */
    private fun protectKey(pkcs8: ByteArray, password: CharArray): ByteArray {
        val salt = ByteArray(SALT_LENGTH).also { SecureRandom().nextBytes(it) }
        val passwordBytes = password.toUtf16BeBytes()
        val digest = MessageDigest.getInstance("SHA-1")

        val encrypted = ByteArray(pkcs8.size)
        var keystream = salt
        var offset = 0
        while (offset < pkcs8.size) {
            digest.update(passwordBytes)
            digest.update(keystream)
            keystream = digest.digest()
            val block = minOf(SALT_LENGTH, pkcs8.size - offset)
            for (i in 0 until block) {
                encrypted[offset + i] = (pkcs8[offset + i].toInt() xor keystream[i].toInt()).toByte()
            }
            offset += block
        }

        digest.update(passwordBytes)
        digest.update(pkcs8)
        val check = digest.digest()

        val protectedKey = salt + encrypted + check
        return encodeEncryptedPrivateKeyInfo(protectedKey)
    }

    /** DER: `SEQUENCE { SEQUENCE { OID }, OCTET STRING protectedKey }`. */
    private fun encodeEncryptedPrivateKeyInfo(protectedKey: ByteArray): ByteArray {
        val algorithmId = derTlv(0x30, derTlv(0x06, encodeOid(KEY_PROTECTOR_OID)))
        val octetString = derTlv(0x04, protectedKey)
        return derTlv(0x30, algorithmId + octetString)
    }

    private fun derTlv(tag: Int, content: ByteArray): ByteArray =
        byteArrayOf(tag.toByte()) + derLength(content.size) + content

    private fun derLength(length: Int): ByteArray = when {
        length < 0x80 -> byteArrayOf(length.toByte())
        length < 0x100 -> byteArrayOf(0x81.toByte(), length.toByte())
        else -> byteArrayOf(0x82.toByte(), (length ushr 8).toByte(), length.toByte())
    }

    private fun encodeOid(oid: String): ByteArray {
        val parts = oid.split(".").map { it.toInt() }
        val out = ByteArrayOutputStream()
        out.write(parts[0] * 40 + parts[1])
        for (i in 2 until parts.size) {
            var value = parts[i]
            val stack = ArrayDeque<Int>()
            stack.addFirst(value and 0x7F)
            value = value ushr 7
            while (value > 0) {
                stack.addFirst((value and 0x7F) or 0x80)
                value = value ushr 7
            }
            stack.forEach { out.write(it) }
        }
        return out.toByteArray()
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
}
