package pl.anielka.trener_jezykowy

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

/**
 * Stream-copy dużych assetów (GGUF ~1 GB) bez ładowania całości do RAMu Dart.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "pl.anielka.trener_jezykowy/assets"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
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
                    "copyAsset" -> {
                        val path = call.argument<String>("path") ?: ""
                        val dest = call.argument<String>("dest") ?: ""
                        Thread {
                            try {
                                val outFile = File(dest)
                                outFile.parentFile?.mkdirs()
                                val tmp = File("$dest.partial")
                                assets.open(path).use { input ->
                                    FileOutputStream(tmp).use { output ->
                                        val buf = ByteArray(1024 * 1024)
                                        while (true) {
                                            val n = input.read(buf)
                                            if (n <= 0) break
                                            output.write(buf, 0, n)
                                        }
                                    }
                                }
                                if (outFile.exists()) outFile.delete()
                                if (!tmp.renameTo(outFile)) {
                                    tmp.copyTo(outFile, overwrite = true)
                                    tmp.delete()
                                }
                                runOnUiThread { result.success(outFile.absolutePath) }
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
