package com.example.per_app

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "per_viewer/open_file"
    private var pendingFilePath: String? = null
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

        methodChannel?.setMethodCallHandler { call, result ->
            if (call.method == "getInitialFile") {
                result.success(pendingFilePath)
                pendingFilePath = null
            } else {
                result.notImplemented()
            }
        }

        handleIncomingIntent(intent, sendIfReady = true)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIncomingIntent(intent, sendIfReady = true)
    }

    private fun handleIncomingIntent(intent: Intent?, sendIfReady: Boolean) {
        if (intent == null) return
        if (intent.action != Intent.ACTION_VIEW) return

        val uri: Uri? = intent.data
        if (uri == null) return

        val filePath = copyUriToTempFile(uri)
        if (filePath != null) {
            pendingFilePath = filePath
            if (sendIfReady) {
                methodChannel?.invokeMethod("onFileOpened", filePath)
            }
        }
    }

    private fun copyUriToTempFile(uri: Uri): String? {
        return try {
            val inputStream = contentResolver.openInputStream(uri) ?: return null
            val fileName = "opened_${System.currentTimeMillis()}.per"
            val tempFile = File(cacheDir, fileName)
            val outputStream = FileOutputStream(tempFile)
            inputStream.copyTo(outputStream)
            inputStream.close()
            outputStream.close()
            tempFile.absolutePath
        } catch (e: Exception) {
            null
        }
    }
}