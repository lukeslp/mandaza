package com.lukesteuber.mandaza

import android.content.ContentValues
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.core.graphics.createBitmap
import com.lukesteuber.mandaza.core.EngineConfig
import com.lukesteuber.mandaza.core.MandazaEngine
import com.lukesteuber.mandaza.core.MandazaPalettes
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream
import kotlin.math.sin

object MandazaExporter {
    suspend fun save(
        context: Context,
        seed: String,
        paletteId: String,
        config: EngineConfig,
        paperTheme: Boolean = false,
        width: Int = 1440,
        height: Int = 2560,
    ): String = withContext(Dispatchers.Default) {
        val generated = MandazaEngine(config).generate(width.toDouble(), height.toDouble(), seed)
        val bitmap = createBitmap(width, height)
        val canvas = Canvas(bitmap)
        canvas.drawColor(if (paperTheme) 0xfff1e6cf.toInt() else 0xff05060a.toInt())
        val palette = MandazaPalettes.byId(paletteId)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeCap = Paint.Cap.ROUND
            strokeJoin = Paint.Join.ROUND
            strokeWidth = (generated.radius / 30 * config.lineWidth).toFloat()
        }
        generated.loops.forEach { loop ->
            var t = if (loop.colorTotal > 1) loop.colorIndex.toDouble() / (loop.colorTotal - 1) else 0.5
            t += 0.18 * sin(loop.colorIndex * 0.6)
            if (t < 0) t = -t
            if (t > 1) t = 2 - t
            paint.color = palette.colorAt(t).toInt()
            paint.alpha = if (paperTheme) 219 else 255
            if (paperTheme) paint.setShadowLayer(
                (paint.strokeWidth * 0.8f).coerceAtLeast(1f), 0f, 1f, 0x2e000000,
            ) else if (config.glow) paint.setShadowLayer(
                (generated.radius / 5 * config.glowStrength).toFloat(), 0f, 0f, paint.color,
            ) else paint.clearShadowLayer()
            val path = Path()
            loop.curves.forEachIndexed { index, curve ->
                if (index == 0) path.moveTo(curve.start.x.toFloat(), curve.start.y.toFloat())
                path.cubicTo(
                    curve.control1.x.toFloat(), curve.control1.y.toFloat(),
                    curve.control2.x.toFloat(), curve.control2.y.toFloat(),
                    curve.end.x.toFloat(), curve.end.y.toFloat(),
                )
            }
            canvas.drawPath(path, paint)
        }

        val name = "Mandaza-${System.currentTimeMillis()}.png"
        try {
            if (Build.VERSION.SDK_INT >= 29) {
                saveWithMediaStore(context, bitmap, name)
            } else {
                saveToLegacyPictures(context, bitmap, name)
            }
            name
        } finally {
            bitmap.recycle()
        }
    }

    private fun saveWithMediaStore(context: Context, bitmap: Bitmap, name: String) {
        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, name)
            put(MediaStore.Images.Media.MIME_TYPE, "image/png")
            put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/Mandaza")
            put(MediaStore.Images.Media.IS_PENDING, 1)
        }
        val resolver = context.contentResolver
        val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
            ?: error("Unable to create image in MediaStore")
        try {
            val saved = resolver.openOutputStream(uri)?.use {
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, it)
            } ?: false
            check(saved) { "Unable to write PNG image" }
            val updated = resolver.update(uri, ContentValues().apply {
                put(MediaStore.Images.Media.IS_PENDING, 0)
            }, null, null)
            check(updated == 1) { "Unable to publish saved image" }
        } catch (error: Throwable) {
            resolver.delete(uri, null, null)
            throw error
        }
    }

    @Suppress("DEPRECATION")
    private fun saveToLegacyPictures(context: Context, bitmap: Bitmap, name: String) {
        val directory = File(
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES),
            "Mandaza",
        )
        check(directory.exists() || directory.mkdirs()) { "Unable to create Pictures/Mandaza" }
        val file = File(directory, name)
        try {
            val saved = FileOutputStream(file).use {
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, it)
            }
            check(saved) { "Unable to write PNG image" }
            MediaScannerConnection.scanFile(context, arrayOf(file.absolutePath), arrayOf("image/png"), null)
        } catch (error: Throwable) {
            file.delete()
            throw error
        }
    }
}
