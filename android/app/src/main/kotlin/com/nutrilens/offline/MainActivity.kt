package com.nutrilens.offline

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.ParcelFileDescriptor
import android.provider.OpenableColumns
import android.system.Os
import android.system.OsConstants
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest

class MainActivity : FlutterActivity() {
    private var pending: MethodChannel.Result? = null
    private var extensions = listOf<String>()

    // Keep the descriptors alive across Activity recreation. Native runtimes open
    // these links in this same process; the OS closes them on process death.
    companion object {
        private const val PICK_MODEL = 4182
        private val descriptors = mutableMapOf<String, ParcelFileDescriptor>()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "nutrilens/model_documents")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "pick" -> {
                            if (pending != null) {
                                result.error("busy", "Pemilihan model masih berlangsung.", null)
                            } else {
                                extensions = call.argument<List<String>>("extensions") ?: emptyList()
                                pending = result
                                startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                                    addCategory(Intent.CATEGORY_OPENABLE)
                                    type = "*/*"
                                    putExtra(Intent.EXTRA_LOCAL_ONLY, true)
                                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                        Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
                                }, PICK_MODEL)
                            }
                        }
                        "open" -> result.success(openDocument(Uri.parse(call.argument<String>("uri")!!)))
                        "release" -> {
                            val uri = Uri.parse(call.argument<String>("uri")!!)
                            releaseDocument(uri)
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    if (call.method == "pick") pending = null
                    result.error("model_document", error.message ?: "File model tidak dapat dibuka.", null)
                }
            }
    }

    private fun releaseDocument(uri: Uri) {
        descriptors.remove(uri.toString())?.close()
        val dir = linkDirectory(uri)
        // Delete our symlinks only, never the referenced file.
        dir.listFiles()?.forEach { it.delete() }
        dir.delete()
        try {
            contentResolver.releasePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
        } catch (_: SecurityException) { }
    }

    private fun linkDirectory(uri: Uri): File {
        val key = MessageDigest.getInstance("SHA-256").digest(uri.toString().toByteArray())
            .joinToString("") { "%02x".format(it) }
        return File(filesDir, "model_links/$key")
    }

    private fun nameOf(uri: Uri): String {
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use {
            if (it.moveToFirst()) return it.getString(0)
        }
        throw IllegalArgumentException("Nama file model tidak tersedia.")
    }

    private fun openDocument(uri: Uri): Map<String, Any> {
        require(uri.scheme == "content") { "Pilih dokumen model dari penyimpanan perangkat." }
        val name = nameOf(uri)
        val key = uri.toString()
        var descriptor = descriptors[key]
        if (descriptor == null) {
            descriptor = contentResolver.openFileDescriptor(uri, "r")
                ?: throw IllegalArgumentException("File asli tidak tersedia. Pilih ulang model.")
            try {
                val stat = Os.fstat(descriptor.fileDescriptor)
                require(OsConstants.S_ISREG(stat.st_mode) && stat.st_size > 0) {
                    "Pilih file lokal yang dapat dibaca langsung; stream/cloud tidak didukung tanpa salinan."
                }
                Os.lseek(descriptor.fileDescriptor, 0, OsConstants.SEEK_SET)
                descriptors[key] = descriptor
            } catch (error: Exception) {
                descriptor.close()
                throw error
            }
        }
        val directory = linkDirectory(uri).apply { mkdirs() }
        val safeName = name.replace(Regex("[^a-zA-Z0-9._-]"), "_")
        val link = File(directory, "${directory.name.take(16)}_$safeName")
        // unlink removes only the old link, including a stale link after restart.
        if (link.exists() || java.nio.file.Files.isSymbolicLink(link.toPath())) link.delete()
        Os.symlink("/proc/self/fd/${descriptor.fd}", link.absolutePath)
        return mapOf("uri" to key, "name" to name, "path" to link.absolutePath)
    }

    @Deprecated("Activity result bridge for Flutter")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != PICK_MODEL) return
        val result = pending ?: return
        pending = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return
        }
        val alreadyGranted = contentResolver.persistedUriPermissions.any { it.uri == uri && it.isReadPermission }
        try {
            val name = nameOf(uri)
            require(extensions.any { name.endsWith(".$it", ignoreCase = true) }) {
                "Pilih file model dengan ekstensi ${extensions.joinToString("/")}."
            }
            contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
            result.success(openDocument(uri))
        } catch (error: Exception) {
            if (!alreadyGranted) releaseDocument(uri)
            result.error("model_document", error.message ?: "Tidak dapat mengakses file asli.", null)
        }
    }
}
