package com.elyasomar.apksigner.data.signing

import com.elyasomar.apksigner.data.keystore.LoadedKey
import com.elyasomar.apksigner.domain.model.SigningException
import org.bouncycastle.cert.jcajce.JcaCertStore
import org.bouncycastle.cms.CMSProcessableByteArray
import org.bouncycastle.cms.CMSSignedDataGenerator
import org.bouncycastle.cms.jcajce.JcaSignerInfoGeneratorBuilder
import org.bouncycastle.operator.jcajce.JcaContentSignerBuilder
import org.bouncycastle.operator.jcajce.JcaDigestCalculatorProviderBuilder
import java.io.ByteArrayOutputStream
import java.io.File
import java.security.MessageDigest
import java.security.PrivateKey
import java.util.Base64
import java.util.zip.ZipEntry
import java.util.zip.ZipInputStream
import java.util.zip.ZipOutputStream
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Signs an Android App Bundle (`.aab`) with a JAR (v1-scheme) signature — the
 * same signing `jarsigner`/Gradle applies to bundles, and what the Play Console
 * expects for upload. APK signature schemes v2–v4 do not apply to bundles.
 *
 * The signature block is a detached CMS/PKCS#7 structure produced with
 * BouncyCastle. Output is verifiable with `jarsigner -verify`.
 */
@Singleton
class JarSignerService @Inject constructor() {

    fun sign(inputBundle: File, outputBundle: File, key: LoadedKey) {
        try {
            val entries = readEntries(inputBundle)
            val certificate = key.certificateChain.first()

            val mainSection = buildMainSection()
            val (manifestBytes, sectionBytes) = buildManifest(mainSection, entries)
            val signatureFile = buildSignatureFile(mainSection, manifestBytes, sectionBytes)
            val signatureBlock = signSignatureFile(signatureFile, key.privateKey, certificate)

            val blockName = "META-INF/CERT.${blockExtension(key.privateKey)}"
            writeSignedBundle(
                outputBundle = outputBundle,
                manifestBytes = manifestBytes,
                signatureFile = signatureFile,
                signatureBlockName = blockName,
                signatureBlock = signatureBlock,
                entries = entries,
            )
        } catch (e: SigningException) {
            throw e
        } catch (e: Exception) {
            throw SigningException(
                e.message?.takeIf { it.isNotBlank() } ?: "Failed to sign the app bundle.",
                e,
            )
        }
    }

    private fun readEntries(bundle: File): LinkedHashMap<String, ByteArray> {
        val entries = LinkedHashMap<String, ByteArray>()
        ZipInputStream(bundle.inputStream().buffered()).use { zis ->
            var entry = zis.nextEntry
            while (entry != null) {
                val name = entry.name
                if (!entry.isDirectory && !isSignatureRelated(name)) {
                    entries[name] = zis.readBytes()
                }
                zis.closeEntry()
                entry = zis.nextEntry
            }
        }
        if (entries.isEmpty()) {
            throw SigningException("The selected bundle is empty or unreadable.")
        }
        return entries
    }

    private fun isSignatureRelated(name: String): Boolean {
        if (!name.startsWith("META-INF/")) return false
        val upper = name.uppercase()
        return upper == "META-INF/MANIFEST.MF" ||
            upper.endsWith(".SF") ||
            upper.endsWith(".RSA") ||
            upper.endsWith(".EC") ||
            upper.endsWith(".DSA")
    }

    private fun buildMainSection(): ByteArray {
        val out = ByteArrayOutputStream()
        out.writeManifestLine("Manifest-Version", "1.0")
        out.writeManifestLine("Created-By", CREATED_BY)
        out.writeCrlf()
        return out.toByteArray()
    }

    private fun buildManifest(
        mainSection: ByteArray,
        entries: Map<String, ByteArray>,
    ): Pair<ByteArray, LinkedHashMap<String, ByteArray>> {
        val manifest = ByteArrayOutputStream()
        manifest.write(mainSection)
        val sectionBytes = LinkedHashMap<String, ByteArray>()
        for ((name, content) in entries) {
            val section = ByteArrayOutputStream()
            section.writeManifestLine("Name", name)
            section.writeManifestLine("SHA-256-Digest", base64(sha256(content)))
            section.writeCrlf()
            val bytes = section.toByteArray()
            sectionBytes[name] = bytes
            manifest.write(bytes)
        }
        return manifest.toByteArray() to sectionBytes
    }

    private fun buildSignatureFile(
        mainSection: ByteArray,
        manifestBytes: ByteArray,
        sectionBytes: Map<String, ByteArray>,
    ): ByteArray {
        val sf = ByteArrayOutputStream()
        sf.writeManifestLine("Signature-Version", "1.0")
        sf.writeManifestLine("SHA-256-Digest-Manifest-Main-Attributes", base64(sha256(mainSection)))
        sf.writeManifestLine("SHA-256-Digest-Manifest", base64(sha256(manifestBytes)))
        sf.writeManifestLine("Created-By", CREATED_BY)
        sf.writeCrlf()
        for ((name, bytes) in sectionBytes) {
            sf.writeManifestLine("Name", name)
            sf.writeManifestLine("SHA-256-Digest", base64(sha256(bytes)))
            sf.writeCrlf()
        }
        return sf.toByteArray()
    }

    private fun signSignatureFile(
        signatureFile: ByteArray,
        privateKey: PrivateKey,
        certificate: java.security.cert.X509Certificate,
    ): ByteArray {
        val generator = CMSSignedDataGenerator()
        val contentSigner = JcaContentSignerBuilder(signatureAlgorithm(privateKey)).build(privateKey)
        generator.addSignerInfoGenerator(
            JcaSignerInfoGeneratorBuilder(JcaDigestCalculatorProviderBuilder().build())
                .setDirectSignature(true)
                .build(contentSigner, certificate),
        )
        generator.addCertificates(JcaCertStore(listOf(certificate)))
        val signed = generator.generate(CMSProcessableByteArray(signatureFile), false)
        return signed.encoded
    }

    private fun writeSignedBundle(
        outputBundle: File,
        manifestBytes: ByteArray,
        signatureFile: ByteArray,
        signatureBlockName: String,
        signatureBlock: ByteArray,
        entries: Map<String, ByteArray>,
    ) {
        ZipOutputStream(outputBundle.outputStream().buffered()).use { zos ->
            zos.putEntry("META-INF/MANIFEST.MF", manifestBytes)
            zos.putEntry("META-INF/CERT.SF", signatureFile)
            zos.putEntry(signatureBlockName, signatureBlock)
            for ((name, content) in entries) {
                zos.putEntry(name, content)
            }
        }
    }

    private fun signatureAlgorithm(key: PrivateKey): String = when (key.algorithm.uppercase()) {
        "RSA" -> "SHA256withRSA"
        "EC" -> "SHA256withECDSA"
        "DSA" -> "SHA256withDSA"
        else -> throw SigningException("Unsupported key algorithm: ${key.algorithm}")
    }

    private fun blockExtension(key: PrivateKey): String = when (key.algorithm.uppercase()) {
        "RSA" -> "RSA"
        "EC" -> "EC"
        "DSA" -> "DSA"
        else -> "RSA"
    }

    private fun sha256(data: ByteArray): ByteArray =
        MessageDigest.getInstance("SHA-256").digest(data)

    private fun base64(data: ByteArray): String =
        Base64.getEncoder().encodeToString(data)

    private fun ByteArrayOutputStream.writeCrlf() {
        write('\r'.code)
        write('\n'.code)
    }

    /** Writes a manifest attribute, wrapping at 72 bytes per the JAR spec. */
    private fun ByteArrayOutputStream.writeManifestLine(name: String, value: String) {
        val bytes = "$name: $value".toByteArray(Charsets.UTF_8)
        var start = 0
        var first = true
        while (bytes.size - start > MANIFEST_LINE_WIDTH) {
            val chunk = if (first) MANIFEST_LINE_WIDTH else MANIFEST_LINE_WIDTH - 1
            if (!first) write(' '.code)
            write(bytes, start, chunk)
            writeCrlf()
            start += chunk
            first = false
        }
        if (!first) write(' '.code)
        write(bytes, start, bytes.size - start)
        writeCrlf()
    }

    private fun ZipOutputStream.putEntry(name: String, data: ByteArray) {
        putNextEntry(ZipEntry(name))
        write(data)
        closeEntry()
    }

    private companion object {
        const val CREATED_BY = "APK Signer"
        const val MANIFEST_LINE_WIDTH = 72
    }
}
