package pl.anielka.trener_jezykowy

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

/**
 * Stream-copy dużych assetów (GGUF ~1 GB) + progress przez EventChannel.
 */
class MainActivity : FlutterActivity() {
    private val methodChannel = "pl.anielka.trener_jezykowy/assets"
    private val progressChannel = "pl.anielka.trener_jezykowy/asset_progress"

    @Volatile
    private var progressSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, progressChannel)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    progressSink = events
                }

                override fun onCancel(arguments: Any?) {
                    progressSink = null
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "assetExists" -> {
                        val path = call.argument<String>("path") ?: ""
                        result.success(try {
                            assets.open(path).close()
                            true
                        } catch (_: Exception) {
                            false
                        })
                    }
                    "assetLength" -> {
                        val path = call.argument<String>("path") ?: ""
                        result.success(try {
                            assets.openFd(path).use { it.length }
                        } catch (_: Exception) {
                            try {
                                // skompresowany asset — nie znamy length z FD
                                -1L
                            } catch (_: Exception) {
                                -1L
                            }
                        })
                    }
                    "copyAsset" -> {
                        val path = call.argument<String>("path") ?: ""
                        val dest = call.argument<String>("dest") ?: ""
                        Thread {
                            try {
                                val outFile = File(dest)
                                outFile.parentFile?.mkdirs()
                                val tmp = File("$dest.partial")
                                var total = -1L
                                try {
                                    assets.openFd(path).use { total = it.length }
                                } catch (_: Exception) {
                                    total = -1L
                                }
                                var copied = 0L
                                var lastEmit = 0L
                                assets.open(path).use { input ->
                                    FileOutputStream(tmp).use { output ->
                                        val buf = ByteArray(1024 * 1024)
                                        while (true) {
                                            val n = input.read(buf)
                                            if (n <= 0) break
                                            output.write(buf, 0, n)
                                            copied += n
                                            if (copied - lastEmit >= 2L * 1024L * 1024L ||
                                                (total > 0 && copied >= total)
                                            ) {
                                                lastEmit = copied
                                                val p = if (total > 0) {
                                                    (copied.toDouble() / total.toDouble()).coerceIn(0.0, 1.0)
                                                } else {
                                                    -1.0
                                                }
                                                runOnUiThread {
                                                    progressSink?.success(
                                                        mapOf(
                                                            "phase" to "copy",
                                                            "progress" to p,
                                                            "bytes" to copied,
                                                            "total" to total,
                                                        ),
                                                    )
                                                }
                                            }
                                        }
                                    }
                                }
                                if (outFile.exists()) outFile.delete()
                                if (!tmp.renameTo(outFile)) {
                                    tmp.copyTo(outFile, overwrite = true)
                                    tmp.delete()
                                }
                                runOnUiThread {
                                    progressSink?.success(
                                        mapOf(
                                            "phase" to "done",
                                            "progress" to 1.0,
                                            "bytes" to copied,
                                            "total" to total,
                                        ),
                                    )
                                    result.success(outFile.absolutePath)
                                }
                            } catch (e: Exception) {
                                runOnUiThread {
                                    result.error("copy_failed", e.message, null)
                                }
                            }
                        }.start()
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
