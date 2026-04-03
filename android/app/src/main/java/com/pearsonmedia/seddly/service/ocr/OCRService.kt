package com.pearsonmedia.seddly.service.ocr

import android.content.Context
import android.graphics.Bitmap
import android.graphics.ImageDecoder
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.util.Log
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.suspendCancellableCoroutine
import javax.inject.Inject
import javax.inject.Singleton
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/**
 * On-device OCR text extraction using Google ML Kit.
 * Mirrors the iOS OCRService using Vision framework.
 * Privacy-first: all processing happens on device.
 */
@Singleton
class OCRService @Inject constructor(
    @ApplicationContext private val context: Context
) {
    private val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)

    /**
     * Extract text from an image URI.
     * Returns the extracted text or null if extraction fails.
     */
    suspend fun extractText(imageUri: Uri): String? {
        return try {
            val bitmap = loadBitmap(imageUri) ?: return null
            val downsampled = downsampleIfNeeded(bitmap, MAX_DIMENSION)
            recognizeText(downsampled)
        } catch (e: Exception) {
            Log.e(TAG, "OCR extraction failed", e)
            null
        }
    }

    /**
     * Extract text from a Bitmap directly.
     */
    suspend fun extractText(bitmap: Bitmap): String? {
        return try {
            val downsampled = downsampleIfNeeded(bitmap, MAX_DIMENSION)
            recognizeText(downsampled)
        } catch (e: Exception) {
            Log.e(TAG, "OCR extraction from bitmap failed", e)
            null
        }
    }

    private suspend fun recognizeText(bitmap: Bitmap): String? =
        suspendCancellableCoroutine { continuation ->
            val image = InputImage.fromBitmap(bitmap, 0)
            recognizer.process(image)
                .addOnSuccessListener { result ->
                    val text = result.text.trim()
                    if (text.isNotEmpty()) {
                        continuation.resume(text)
                    } else {
                        continuation.resume(null)
                    }
                }
                .addOnFailureListener { e ->
                    Log.e(TAG, "ML Kit text recognition failed", e)
                    continuation.resumeWithException(e)
                }
        }

    @Suppress("DEPRECATION")
    private fun loadBitmap(uri: Uri): Bitmap? {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                val source = ImageDecoder.createSource(context.contentResolver, uri)
                ImageDecoder.decodeBitmap(source) { decoder, _, _ ->
                    decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
                    decoder.isMutableRequired = true
                }
            } else {
                MediaStore.Images.Media.getBitmap(context.contentResolver, uri)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load bitmap from URI: $uri", e)
            null
        }
    }

    private fun downsampleIfNeeded(bitmap: Bitmap, maxDimension: Int): Bitmap {
        val maxSide = maxOf(bitmap.width, bitmap.height)
        if (maxSide <= maxDimension) return bitmap

        val scale = maxDimension.toFloat() / maxSide
        val newWidth = (bitmap.width * scale).toInt()
        val newHeight = (bitmap.height * scale).toInt()
        return Bitmap.createScaledBitmap(bitmap, newWidth, newHeight, true)
    }

    companion object {
        private const val TAG = "OCRService"
        private const val MAX_DIMENSION = 2048
    }
}
