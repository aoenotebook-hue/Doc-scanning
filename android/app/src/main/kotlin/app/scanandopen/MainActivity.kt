package app.scanandopen

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import com.google.mlkit.vision.documentscanner.GmsDocumentScannerOptions
import com.google.mlkit.vision.documentscanner.GmsDocumentScanning
import com.google.mlkit.vision.documentscanner.GmsDocumentScanningResult
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
  private val channelName = "app.scanandopen/platform"
  private var pending: MethodChannel.Result? = null
  private var saveSource: String? = null
  private val shared = mutableListOf<String>()
  override fun onCreate(state: Bundle?) { super.onCreate(state); receive(intent) }
  override fun onNewIntent(value: Intent) { super.onNewIntent(value); receive(value) }
  override fun configureFlutterEngine(engine: FlutterEngine) {
    super.configureFlutterEngine(engine)
    MethodChannel(engine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result -> when(call.method) {
      "scanDocument" -> scan(result)
      "consumeSharedImages" -> { result.success(shared.toList()); shared.clear() }
      "saveAs" -> { pending=result; saveSource=call.argument("path"); startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).apply { addCategory(Intent.CATEGORY_OPENABLE); type=call.argument<String>("mime"); putExtra(Intent.EXTRA_TITLE,call.argument<String>("filename")) }, 902) }
      else -> result.notImplemented()
    }}
  }
  private fun scan(result: MethodChannel.Result) {
    pending=result
    val options=GmsDocumentScannerOptions.Builder().setGalleryImportAllowed(true).setPageLimit(50).setResultFormats(GmsDocumentScannerOptions.RESULT_FORMAT_JPEG).setScannerMode(GmsDocumentScannerOptions.SCANNER_MODE_FULL).build()
    GmsDocumentScanning.getClient(options).getStartScanIntent(this).addOnSuccessListener { startIntentSenderForResult(it,901,null,0,0,0) }.addOnFailureListener { pending?.error("SCAN",it.localizedMessage,null);pending=null }
  }
  override fun onActivityResult(request:Int,resultCode:Int,data:Intent?) { super.onActivityResult(request,resultCode,data)
    if(request==901){ if(resultCode!=Activity.RESULT_OK){pending?.success(emptyList<String>())}else{val scan=GmsDocumentScanningResult.fromActivityResultIntent(data);val paths=scan?.pages?.mapIndexed { i,p -> copy(p.imageUri,"scan_$i.jpg") }?: emptyList();pending?.success(paths)};pending=null }
    if(request==902){ if(resultCode!=Activity.RESULT_OK||data?.data==null){pending?.success(false)}else try{File(saveSource!!).inputStream().use{input->contentResolver.openOutputStream(data.data!!)!!.use{input.copyTo(it)}};pending?.success(true)}catch(e:Exception){pending?.error("SAVE",e.localizedMessage,null)};pending=null;saveSource=null }
  }
  private fun receive(value:Intent){ val uris=when(value.action){Intent.ACTION_SEND->listOfNotNull(value.getParcelableExtra(Intent.EXTRA_STREAM,Uri::class.java));Intent.ACTION_SEND_MULTIPLE->value.getParcelableArrayListExtra(Intent.EXTRA_STREAM,Uri::class.java)?: emptyList();else->emptyList()};uris.forEachIndexed{i,u->shared.add(copy(u,"shared_${System.currentTimeMillis()}_$i"))};value.action=null }
  private fun copy(uri:Uri,name:String):String { val out=File(cacheDir,name);contentResolver.openInputStream(uri)!!.use{input->out.outputStream().use{input.copyTo(it)}};return out.path }
}
