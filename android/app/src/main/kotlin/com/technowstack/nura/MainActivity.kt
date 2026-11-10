package com.technowstack.nura

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.Executors
import java.util.concurrent.RejectedExecutionException

class MainActivity : FlutterActivity() {
    // Single worker: a 100+ MB copy must never run on the UI thread.
    private val copyExecutor = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method != "copyAsset") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val key = call.argument<String>("assetKey")
                val dest = call.argument<String>("destination")
                if (key == null || dest == null || !key.startsWith("assets/") || key.contains("..")) {
                    result.error("bad_args", "Invalid assetKey or destination", null)
                    return@setMethodCallHandler
                }
                val file = File(dest)
                if (!file.canonicalPath.startsWith(filesDir.parentFile.canonicalPath)) {
                    result.error("bad_args", "Destination outside app data dir", null)
                    return@setMethodCallHandler
                }
                try {
                    copyExecutor.execute {
                        try {
                            assets.open("flutter_assets/$key").use { input ->
                                FileOutputStream(file).use { out ->
                                    input.copyTo(out, BUFFER_SIZE)
                                    out.flush()
                                    out.fd.sync()
                                }
                            }
                            runOnUiThread { result.success(null) }
                        } catch (e: Throwable) {
                            file.delete()
                            runOnUiThread { result.error("copy_failed", e.message, null) }
                        }
                        }
                } catch (e: RejectedExecutionException) {
                    result.error("shutdown", "Copy executor is shut down", null)
                }
            }
    }

    override fun onDestroy() {
        copyExecutor.shutdown()
        super.onDestroy()
    }

    private companion object {
        const val CHANNEL = "com.technowstack.nura/asset_copy"
        const val BUFFER_SIZE = 1024 * 1024
    }
}
