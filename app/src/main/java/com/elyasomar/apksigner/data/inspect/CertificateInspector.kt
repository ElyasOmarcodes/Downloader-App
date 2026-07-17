package com.elyasomar.apksigner.data.inspect

import com.elyasomar.apksigner.domain.model.CertificateInfo
import java.security.MessageDigest
import java.security.cert.X509Certificate
import java.text.DateFormat
import java.util.Date
import java.util.Locale
import javax.inject.Inject
import javax.inject.Singleton

/** Derives display metadata from a signing certificate. */
@Singleton
class CertificateInspector @Inject constructor() {

    fun inspect(certificate: X509Certificate): CertificateInfo {
        val now = Date()
        val isValid = runCatching {
            certificate.checkValidity(now)
        }.isSuccess

        return CertificateInfo(
            subject = certificate.subjectX500Principal.name,
            issuer = certificate.issuerX500Principal.name,
            serialNumber = certificate.serialNumber.toString(16).uppercase(Locale.ROOT),
            sha256Fingerprint = fingerprint(certificate),
            signatureAlgorithm = certificate.sigAlgName,
            validFrom = DATE_FORMAT.format(certificate.notBefore),
            validUntil = DATE_FORMAT.format(certificate.notAfter),
            isCurrentlyValid = isValid,
        )
    }

    private fun fingerprint(certificate: X509Certificate): String {
        val digest = MessageDigest.getInstance("SHA-256").digest(certificate.encoded)
        return digest.joinToString(":") { "%02X".format(it) }
    }

    private companion object {
        val DATE_FORMAT: DateFormat =
            DateFormat.getDateTimeInstance(DateFormat.MEDIUM, DateFormat.SHORT, Locale.getDefault())
    }
}
