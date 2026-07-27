package com.example.tower_lens

import com.tom_roush.pdfbox.android.PDFBoxResourceLoader
import com.tom_roush.pdfbox.pdmodel.PDDocument
import com.tom_roush.pdfbox.text.PDFTextStripper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayInputStream

class MainActivity : FlutterActivity() {
    private val documentImportChannel = "com.example.tower_lens/document_import"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        PDFBoxResourceLoader.init(applicationContext)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            documentImportChannel,
        ).setMethodCallHandler { call, result ->
            if (call.method != "extractPdfText") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val bytes = call.argument<ByteArray>("bytes")
            if (bytes == null || bytes.isEmpty()) {
                result.error(
                    "invalid_pdf",
                    "Tower Lens could not read that PDF.",
                    null,
                )
                return@setMethodCallHandler
            }

            Thread {
                try {
                    val text = ByteArrayInputStream(bytes).use { stream ->
                        PDDocument.load(stream).use { document ->
                            PDFTextStripper().getText(document)
                        }
                    }
                    runOnUiThread { result.success(text) }
                } catch (error: Exception) {
                    runOnUiThread {
                        result.error(
                            "pdf_extraction_failed",
                            "Tower Lens could not extract readable text from that PDF.",
                            error.message,
                        )
                    }
                }
            }.start()
        }
    }
}
