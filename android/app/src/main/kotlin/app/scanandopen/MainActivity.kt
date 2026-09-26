package app.scanandopen

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import com.google.mlkit.vision.documentscanner.GmsDocumentScannerOptions
import com.google.mlkit.vision.documentscanner.GmsDocumentScanning
import com.google.mlkit.vision.documentscanner.GmsDocumentScanningResult
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID

class MainActivity : FlutterActivity() {
    private var pending: MethodChannel.Result? = null
    private var saveSource: String? = null

    override fun onCreate(state: Bundle?) {
        super.onCreate(state)
        receive(intent)
    }

    override fun onNewIntent(value: Intent) {
        super.onNewIntent(value)
        setIntent(value)
        receive(value)
    }

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "scanDocument" -> scan(result)
                "consumeSharedImages" -> result.success(pendingSharedImages())
                "saveAs" -> {
                    if (pending != null) {
                        result.error("BUSY", "Another system operation is already open.", null)
                        return@setMethodCallHandler
                    }
                    val source = call.argument<String>("path")
                    if (source == null || !File(source).isFile) {
                        result.error("MISSING_FILE", "The generated file is unavailable.", null)
                        return@setMethodCallHandler
                    }
                    pending = result
                    saveSource = source
                    startActivityForResult(
                        Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = call.argument<String>("mime") ?: "application/octet-stream"
                            putExtra(Intent.EXTRA_TITLE, call.argument<String>("filename") ?: File(source).name)
                        },
                        SAVE_REQUEST,
                    )
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun scan(result: MethodChannel.Result) {
        if (pending != null) {
            result.error("BUSY", "Another system operation is already open.", null)
            return
        }
        pending = result
        val options = GmsDocumentScannerOptions.Builder()
            .setGalleryImportAllowed(true)
            .setPageLimit(50)
            .setResultFormats(GmsDocumentScannerOptions.RESULT_FORMAT_JPEG)
            .setScannerMode(GmsDocumentScannerOptions.SCANNER_MODE_FULL)
            .build()
        GmsDocumentScanning.getClient(options).getStartScanIntent(this)
            .addOnSuccessListener {
                startIntentSenderForResult(it, SCAN_REQUEST, null, 0, 0, 0)
            }
            .addOnFailureListener {
                pending?.error("SCAN", it.localizedMessage, null)
                pending = null
            }
    }

    override fun onActivityResult(request: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(request, resultCode, data)
        when (request) {
            SCAN_REQUEST -> finishScan(resultCode, data)
            SAVE_REQUEST -> finishSave(resultCode, data)
        }
    }

    private fun finishScan(resultCode: Int, data: Intent?) {
        if (resultCode != Activity.RESULT_OK) {
            pending?.success(emptyList<String>())
            pending = null
            return
        }
        try {
            val scan = GmsDocumentScanningResult.fromActivityResultIntent(data)
            val paths = scan?.pages?.map { page ->
                copyUri(page.imageUri, File(cacheDir, "scan_${UUID.randomUUID()}.jpg"))
            } ?: emptyList()
            pending?.success(paths)
        } catch (error: Exception) {
            pending?.error("SCAN_COPY", error.localizedMessage, null)
        } finally {
            pending = null
        }
    }

    private fun finishSave(resultCode: Int, data: Intent?) {
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            pending?.success(false)
            pending = null
            saveSource = null
            return
        }
        try {
            val destination = data.data ?: error("No destination returned")
            File(saveSource ?: error("No source file")).inputStream().use { input ->
                contentResolver.openOutputStream(destination, "w")?.use { output -> input.copyTo(output) }
                    ?: error("The destination could not be opened")
            }
            pending?.success(true)
        } catch (error: Exception) {
            pending?.error("SAVE", error.localizedMessage, null)
        } finally {
            pending = null
            saveSource = null
        }
    }

    private fun receive(value: Intent) {
        if (value.action in setOf(Intent.ACTION_SEND, Intent.ACTION_SEND_MULTIPLE) &&
            value.type?.startsWith("image/") != true
        ) {
            value.action = null
            return
        }
        val uris = when (value.action) {
            Intent.ACTION_SEND -> streamUri(value)?.let(::listOf) ?: emptyList()
            Intent.ACTION_SEND_MULTIPLE -> streamUris(value)
            else -> emptyList()
        }
        uris.take(MAX_SHARED_IMAGES).forEach { uri ->
            try {
                val declaredType = contentResolver.getType(uri)
                if (declaredType != null && !declaredType.startsWith("image/")) return@forEach
                copyUri(
                    uri,
                    File(cacheDir, "shared_${UUID.randomUUID()}"),
                    MAX_SHARED_IMAGE_BYTES,
                )
            } catch (_: Exception) {
                // An individual provider can revoke access. Other shared images remain usable.
            }
        }
        value.action = null
    }

    private fun pendingSharedImages(): List<String> {
        val expiry = System.currentTimeMillis() - CLAIM_LIFETIME_MS
        cacheDir.listFiles()
            ?.filter { it.name.startsWith("claimed_") && it.lastModified() < expiry }
            ?.forEach(File::delete)
        return cacheDir.listFiles()
            ?.filter { it.isFile && it.name.startsWith("shared_") }
            ?.sortedBy { it.lastModified() }
            ?.mapNotNull { source ->
                val claimed = File(cacheDir, source.name.replaceFirst("shared_", "claimed_"))
                if (source.renameTo(claimed)) claimed.absolutePath else null
            }
            ?: emptyList()
    }

    @Suppress("DEPRECATION")
    private fun streamUri(value: Intent): Uri? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        value.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
    } else {
        value.getParcelableExtra(Intent.EXTRA_STREAM)
    }

    @Suppress("DEPRECATION")
    private fun streamUris(value: Intent): List<Uri> = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        value.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java) ?: emptyList()
    } else {
        value.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM) ?: emptyList()
    }

    private fun copyUri(uri: Uri, destination: File, maximumBytes: Long? = null): String {
        try {
            contentResolver.openInputStream(uri)?.use { input ->
                destination.outputStream().use { output ->
                    val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                    var total = 0L
                    while (true) {
                        val count = input.read(buffer)
                        if (count < 0) break
                        total += count
                        if (maximumBytes != null && total > maximumBytes) {
                            error("The shared image exceeds the size limit")
                        }
                        output.write(buffer, 0, count)
                    }
                }
            } ?: error("The shared image could not be opened")
            return destination.absolutePath
        } catch (error: Exception) {
            destination.delete()
            throw error
        }
    }

    companion object {
        private const val CHANNEL = "app.scanandopen/platform"
        private const val SCAN_REQUEST = 901
        private const val SAVE_REQUEST = 902
        private const val CLAIM_LIFETIME_MS = 24 * 60 * 60 * 1000L
        private const val MAX_SHARED_IMAGES = 50
        private const val MAX_SHARED_IMAGE_BYTES = 100L * 1024 * 1024
    }
}
