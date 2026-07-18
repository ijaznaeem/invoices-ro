package com.octavions.invoices_ro

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.octavions.invoices_ro/files"
        ).setMethodCallHandler { call, result ->
            if (call.method != "savePublicFile") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            try {
                val fileName = call.argument<String>("fileName")!!
                val mimeType = call.argument<String>("mimeType")!!
                val bytes = call.argument<ByteArray>("bytes")!!
                val collection = call.argument<String>("collection") ?: "downloads"
                val subfolder = call.argument<String>("subfolder") ?: "Ledger"
                result.success(savePublicFile(fileName, mimeType, bytes, collection, subfolder))
            } catch (error: Exception) {
                result.error("SAVE_FAILED", error.message, null)
            }
        }
    }

    private fun savePublicFile(
        fileName: String,
        mimeType: String,
        bytes: ByteArray,
        collection: String,
        subfolder: String
    ): String {
        val root = if (collection == "documents") {
            Environment.DIRECTORY_DOCUMENTS
        } else {
            Environment.DIRECTORY_DOWNLOADS
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
                put(MediaStore.MediaColumns.RELATIVE_PATH, "$root/$subfolder")
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
            val uri = contentResolver.insert(
                if (collection == "documents") {
                    MediaStore.Files.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
                } else {
                    MediaStore.Downloads.EXTERNAL_CONTENT_URI
                },
                values
            ) ?: error("Could not create the public file.")
            try {
                contentResolver.openOutputStream(uri)?.use { it.write(bytes) }
                    ?: error("Could not open the public file.")
                values.clear()
                values.put(MediaStore.MediaColumns.IS_PENDING, 0)
                contentResolver.update(uri, values, null, null)
                return "$root/$subfolder/$fileName"
            } catch (error: Exception) {
                contentResolver.delete(uri, null, null)
                throw error
            }
        }

        @Suppress("DEPRECATION")
        val directory = File(
            Environment.getExternalStoragePublicDirectory(root),
            subfolder
        )
        directory.mkdirs()
        val file = File(directory, fileName)
        file.writeBytes(bytes)
        return file.absolutePath
    }
}
