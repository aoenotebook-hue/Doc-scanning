package app.scanandopen

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.webkit.MimeTypeMap
import androidx.core.content.IntentCompat
import com.google.mlkit.vision.documentscanner.GmsDocumentScannerOptions
import com.google.mlkit.vision.documentscanner.GmsDocumentScanning
import com.google.mlkit.vision.documentscanner.GmsDocumentScanningResult
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID

class MainActivity : FlutterActivity() {
  private val channelName = "app.scanandopen/platform"
  private val scanRequest = 901
  private val saveRequest = 902
  // Scanning and saving are tracked separately so one flow never answers the other.
  private var pendingScan: MethodChannel.Result? = null
  private var pendingSave: MethodChannel.Result? = null
  private var saveSource: String? = null
  private val shared = mutableListOf<String>()

  override fun onCreate(state: Bundle?) { super.onCreate(state); receive(intent) }
  override fun onNewIntent(value: Intent) { super.onNewIntent(value); receive(value) }

  override fun configureFlutterEngine(engine: FlutterEngine) {
    super.configureFlutterEngine(engine)
    MethodChannel(engine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result -> when (call.method) {
      "scanDocument" -> scan(result)
      "consumeSharedImages" -> { result.success(shared.toList()); shared.clear() }
      "saveAs" -> {
        if (pendingSave != null) { result.error("BUSY", "A save is already in progress", null); return@setMethodCallHandler }
        pendingSave = result; saveSource = call.argument("path")
        startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
          addCategory(Intent.CATEGORY_OPENABLE); type = call.argument<String>("mime"); putExtra(Intent.EXTRA_TITLE, call.argument<String>("filename"))
        }, saveRequest)
      }
      else -> result.notImplemented()
    }}
  }

  private fun scan(result: MethodChannel.Result) {
    if (pendingScan != null) { result.error("BUSY", "A scan is already in progress", null); return }
    pendingScan = result
    val options = GmsDocumentScannerOptions.Builder().setGalleryImportAllowed(true).setPageLimit(50)
      .setResultFormats(GmsDocumentScannerOptions.RESULT_FORMAT_JPEG).setScannerMode(GmsDocumentScannerOptions.SCANNER_MODE_FULL).build()
    GmsDocumentScanning.getClient(options).getStartScanIntent(this)
      .addOnSuccessListener { startIntentSenderForResult(it, scanRequest, null, 0, 0, 0) }
      .addOnFailureListener { pendingScan?.error("SCAN", it.localizedMessage, null); pendingScan = null }
  }

  @Deprecated("Required for ML Kit and SAF results on all supported API levels")
  override fun onActivityResult(request: Int, resultCode: Int, data: Intent?) {
    super.onActivityResult(request, resultCode, data)
    if (request == scanRequest) {
      val result = pendingScan; pendingScan = null
      if (resultCode != Activity.RESULT_OK) { result?.success(emptyList<String>()); return }
      try {
        val pages = GmsDocumentScanningResult.fromActivityResultIntent(data)?.pages ?: emptyList()
        result?.success(pages.map { copy(it.imageUri, "scan_${UUID.randomUUID()}.jpg") })
      } catch (e: Exception) { result?.error("SCAN", e.localizedMessage, null) }
    }
    if (request == saveRequest) {
      val result = pendingSave; val source = saveSource; pendingSave = null; saveSource = null
      val target = data?.data
      if (resultCode != Activity.RESULT_OK || target == null || source == null) { result?.success(false); return }
      try {
        File(source).inputStream().use { input -> contentResolver.openOutputStream(target)!!.use { input.copyTo(it) } }
        result?.success(true)
      } catch (e: Exception) { result?.error("SAVE", e.localizedMessage, null) }
    }
  }

  private fun receive(value: Intent) {
    val uris: List<Uri> = when (value.action) {
      Intent.ACTION_SEND -> listOfNotNull(IntentCompat.getParcelableExtra(value, Intent.EXTRA_STREAM, Uri::class.java))
      Intent.ACTION_SEND_MULTIPLE -> IntentCompat.getParcelableArrayListExtra(value, Intent.EXTRA_STREAM, Uri::class.java) ?: emptyList()
      else -> emptyList()
    }
    // Only content:// grants are accepted. file:// and other schemes could point at this
    // app's own private files or at paths the sender should not be able to reach.
    for (uri in uris.filter { it.scheme == "content" }) {
      try { shared.add(copy(uri, "shared_${UUID.randomUUID()}.${extensionOf(uri)}")) } catch (e: Exception) { /* Skip unreadable items; the rest still import. */ }
    }
    value.action = null
  }

  private fun extensionOf(uri: Uri): String =
    contentResolver.getType(uri)?.let { MimeTypeMap.getSingleton().getExtensionFromMimeType(it) } ?: "jpg"

  private fun copy(uri: Uri, name: String): String {
    val dir = File(cacheDir, "incoming").apply { mkdirs() }
    val out = File(dir, name)
    contentResolver.openInputStream(uri)!!.use { input -> out.outputStream().use { input.copyTo(it) } }
    return out.path
  }
}
