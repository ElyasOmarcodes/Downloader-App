package com.elyasomar.apksigner.data.keystore

import com.elyasomar.apksigner.domain.model.KeyAlgorithm
import com.elyasomar.apksigner.domain.model.KeystoreFormat
import com.elyasomar.apksigner.domain.model.KeystoreSpec
import com.elyasomar.apksigner.domain.model.SigningException
import org.bouncycastle.asn1.x500.X500Name
import org.bouncycastle.asn1.x500.X500NameBuilder
import org.bouncycastle.asn1.x500.style.BCStyle
import org.bouncycastle.asn1.x509.SubjectPublicKeyInfo
import org.bouncycastle.cert.jcajce.JcaX509CertificateConverter
import org.bouncycastle.cert.jcajce.JcaX509v3CertificateBuilder
import org.bouncycastle.operator.jcajce.JcaContentSignerBuilder
import java.io.ByteArrayOutputStream
import java.math.BigInteger
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.SecureRandom
import java.security.cert.X509Certificate
import java.security.spec.ECGenParameterSpec
import java.util.Calendar
import java.util.Date
import javax.inject.Inject
import javax.inject.Singleton

/** A freshly generated key together with its self-signed certificate. */
data class GeneratedKeystore(
    val alias: String,
    val certificate: X509Certificate,
    val bytes: ByteArray,
)

/**
 * Generates a new signing key with a self-signed X.509 certificate and packages
 * it into a JKS or PKCS#12 keystore. Certificate creation uses BouncyCastle;
 * JKS containers are written by [JavaKeyStoreWriter] (Android has no JKS
 * provider), while PKCS#12 uses the platform provider.
 */
@Singleton
class KeystoreGenerator @Inject constructor() {

    fun generate(spec: KeystoreSpec): GeneratedKeystore {
        try {
            val keyPair = generateKeyPair(spec.algorithm)
            val certificate = createSelfSignedCertificate(spec, keyPair)

            val bytes = when (spec.format) {
                KeystoreFormat.JKS -> JavaKeyStoreWriter.write(
                    alias = spec.alias,
                    privateKey = keyPair.private,
                    certificateChain = listOf(certificate),
                    storePassword = spec.storePassword,
                    keyPassword = spec.keyPassword,
                )

                KeystoreFormat.PKCS12 -> writePkcs12(
                    alias = spec.alias,
                    privateKey = keyPair.private,
                    certificate = certificate,
                    storePassword = spec.storePassword,
                    keyPassword = spec.keyPassword,
                )
            }

            return GeneratedKeystore(spec.alias, certificate, bytes)
        } catch (e: SigningException) {
            throw e
        } catch (e: Exception) {
            throw SigningException(
                e.message?.takeIf { it.isNotBlank() } ?: "Failed to generate the keystore.",
                e,
            )
        }
    }

    private fun generateKeyPair(algorithm: KeyAlgorithm) =
        KeyPairGenerator.getInstance(algorithm.jcaName).apply {
            when (algorithm) {
                KeyAlgorithm.EC_P256 -> initialize(ECGenParameterSpec("secp256r1"), SecureRandom())
                else -> initialize(algorithm.defaultKeySize, SecureRandom())
            }
        }.generateKeyPair()

    private fun createSelfSignedCertificate(
        spec: KeystoreSpec,
        keyPair: java.security.KeyPair,
    ): X509Certificate {
        val subject = buildX500Name(spec)
        val now = System.currentTimeMillis()
        val notBefore = Date(now)
        val notAfter = Calendar.getInstance().apply {
            time = notBefore
            add(Calendar.YEAR, spec.validityYears.coerceIn(1, 1000))
        }.time
        val serial = BigInteger.valueOf(now).max(BigInteger.ONE)

        val certBuilder = JcaX509v3CertificateBuilder(
            subject,
            serial,
            notBefore,
            notAfter,
            subject,
            keyPair.public,
        )
        val signer = JcaContentSignerBuilder(signatureAlgorithm(spec.algorithm))
            .build(keyPair.private)
        val holder = certBuilder.build(signer)
        return JcaX509CertificateConverter().getCertificate(holder)
    }

    private fun buildX500Name(spec: KeystoreSpec): X500Name {
        if (spec.commonName.isBlank()) {
            throw SigningException("A Common Name (CN) is required for the certificate.")
        }
        val builder = X500NameBuilder(BCStyle.INSTANCE)
        fun add(oid: org.bouncycastle.asn1.ASN1ObjectIdentifier, value: String) {
            val trimmed = value.trim()
            if (trimmed.isNotEmpty()) builder.addRDN(oid, trimmed)
        }
        // Order from most to least specific, as is conventional for a DN.
        add(BCStyle.CN, spec.commonName)
        add(BCStyle.OU, spec.organizationalUnit)
        add(BCStyle.O, spec.organization)
        add(BCStyle.L, spec.locality)
        add(BCStyle.ST, spec.state)
        add(BCStyle.C, spec.country)
        return builder.build()
    }

    private fun writePkcs12(
        alias: String,
        privateKey: java.security.PrivateKey,
        certificate: X509Certificate,
        storePassword: CharArray,
        keyPassword: CharArray,
    ): ByteArray {
        val keyStore = KeyStore.getInstance("PKCS12").apply {
            load(null, null)
            setKeyEntry(alias, privateKey, keyPassword, arrayOf(certificate))
        }
        return ByteArrayOutputStream().use { out ->
            keyStore.store(out, storePassword)
            out.toByteArray()
        }
    }

    private fun signatureAlgorithm(algorithm: KeyAlgorithm): String = when (algorithm) {
        KeyAlgorithm.EC_P256 -> "SHA256withECDSA"
        else -> "SHA256withRSA"
    }
}
