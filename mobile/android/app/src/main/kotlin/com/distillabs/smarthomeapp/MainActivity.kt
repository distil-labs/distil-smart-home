package com.distillabs.smarthomeapp

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.distillabs.smarthome/model")
            .setMethodCallHandler { call, result ->
                if (call.method == "getBundledModelPath") {
                    val target = File(filesDir, "smart-home-model")
                    if (target.exists()) {
                        result.success(target.absolutePath)
                        return@setMethodCallHandler
                    }
                    val files = try { assets.list("smart-home-model") } catch (_: Exception) { null }
                    if (files.isNullOrEmpty()) {
                        result.success(null)
                        return@setMethodCallHandler
                    }
                    Thread {
                        try {
                            target.mkdirs()
                            for (name in files) {
                                assets.open("smart-home-model/$name").use { input ->
                                    File(target, name).outputStream().use { output ->
                                        input.copyTo(output)
                                    }
                                }
                            }
                            runOnUiThread { result.success(target.absolutePath) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("COPY_FAILED", e.message, null) }
                        }
                    }.start()
                } else {
                    result.notImplemented()
                }
            }
    }
}
