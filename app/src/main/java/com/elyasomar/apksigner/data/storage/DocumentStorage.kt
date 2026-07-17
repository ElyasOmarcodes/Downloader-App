package com.elyasomar.apksigner.data.storage

import android.content.Context
import android.net.Uri
import android.provider.OpenableColumns
import androidx.documentfile.provider.DocumentFile
import com.elyasomar.apksigner.domain.model.SigningException
import dagger.hilt.android.qualifiers.ApplicationContext
import java.io.File
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Bridges the Storage Access Framework (content URIs) and the plain [File] API
 * that `apksig` requires. Input documents are staged into the app cache; output
 * is written back into the user-selected tree.
 */
@Singleton
class DocumentStorage @Inject constructor(
    @ApplicationContext private val context: Context,
) {

    private val mimeApk = "application/vnd.android.package-archive"

    /** Reads the entire contents of a document URI into memory. */
    fun readBytes(uri: Uri): ByteArray {
        return context.contentResolver.openInputStream(uri)?.use { it.readBytes() }
            ?: throw SigningException("Could not open the selected file.")
    }

    /** Copies a document URI into a freshly created cache file. */
    fun copyToCache(uri: Uri, fileName: String): File {
        val target = File(context.cacheDir, fileName)
        context.contentResolver.openInputStream(uri)?.use { input ->
            target.outputStream().use { output -> input.copyTo(output) }
        } ?: throw SigningException("Could not open the selected file.")
        return target
    }

    /** The user-visible name of a document, or a fallback when unavailable. */
    fun displayName(uri: Uri, fallback: String): String {
        context.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
            ?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (index >= 0) {
                        cursor.getString(index)?.takeIf { it.isNotBlank() }?.let { return it }
                    }
                }
            }
        return fallback
    }

    /**
     * Copies [source] into the SAF tree [treeUri] under [displayName],
     * replacing any existing file of the same name, and returns the final name.
     */
    fun writeToTree(treeUri: Uri, source: File, displayName: String): String {
        val tree = DocumentFile.fromTreeUri(context, treeUri)
            ?: throw SigningException("The selected output folder is not accessible.")
        if (!tree.canWrite()) {
            throw SigningException("The app cannot write to the selected output folder.")
        }

        tree.findFile(displayName)?.delete()
        val created = tree.createFile(mimeFor(displayName), displayName)
            ?: throw SigningException("Could not create the output file.")

        context.contentResolver.openOutputStream(created.uri)?.use { output ->
            source.inputStream().use { input -> input.copyTo(output) }
        } ?: throw SigningException("Could not write to the output file.")

        return created.name ?: displayName
    }

    private fun mimeFor(fileName: String): String =
        if (fileName.endsWith(".apk", ignoreCase = true)) mimeApk else "application/octet-stream"
}
