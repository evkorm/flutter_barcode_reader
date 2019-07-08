package com.apptreesoftware.barcodescan

import android.app.Activity
import android.content.Intent
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.PluginRegistry
import io.flutter.plugin.common.PluginRegistry.Registrar

class BarcodeScanPlugin(private val activity: Activity): MethodCallHandler,
    PluginRegistry.ActivityResultListener {
  private var result : Result? = null
  companion object {
    @JvmStatic
    fun registerWith(registrar: Registrar) {
      val channel = MethodChannel(registrar.messenger(), "com.apptreesoftware.barcode_scan")
      val plugin = BarcodeScanPlugin(registrar.activity())
      channel.setMethodCallHandler(plugin)
      registrar.addActivityResultListener(plugin)
    }
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    if (call.method == "scan") {
      this.result = result
      showBarcodeView(
              call.argument("text") ?: "",
              call.argument("frontCamera") ?: false
      )
    } else {
      result.notImplemented()
    }
  }

  private fun showBarcodeView(text: String, frontCamera: Boolean) {
    val intent = Intent(activity, BarcodeScannerActivity::class.java)
    intent.putExtra("text", text)
    intent.putExtra("frontCamera", frontCamera)
    activity.startActivityForResult(intent, 100)
  }

  override fun onActivityResult(code: Int, resultCode: Int, data: Intent?): Boolean {
    if (code == 100) {
      if (resultCode == Activity.RESULT_OK) {
        val barcode = data?.getStringExtra("SCAN_RESULT")
        barcode?.let { this.result?.success(barcode) }
      } else {
        val errorCode = data?.getStringExtra("ERROR_CODE")
        this.result?.error(errorCode, null, null)
      }
      return true
    }
    return false
  }
}
