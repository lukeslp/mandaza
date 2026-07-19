package com.lukesteuber.mandaza

import android.content.ContentValues
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.os.Build
import android.provider.MediaStore
import com.lukesteuber.mandaza.core.EngineConfig
import com.lukesteuber.mandaza.core.MandazaEngine
import com.lukesteuber.mandaza.core.MandazaPalettes
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlin.math.sin

object MandazaExporter {
    suspend fun save(
        context: Context,
        seed: String,
        paletteId: String,
        config: EngineConfig,
        width: Int = 1440,
        height: Int = 2560,
    ): String = withContext(Dispatchers.Default) {
        val generated = MandazaEngine(config).generate(width.toDouble(), height.toDouble(), seed)
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        canvas.drawColor(if (config.glow) 0xff030308.toInt() else 0xff05060a.toInt())
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
            if (config.glow) paint.setShadowLayer(
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
        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, name)
            put(MediaStore.Images.Media.MIME_TYPE, "image/png")
            if (Build.VERSION.SDK_INT >= 29) put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/Mandaza")
        }
        val uri = context.contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
            ?: error("Unable to create image in MediaStore")
        context.contentResolver.openOutputStream(uri)?.use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
            ?: error("Unable to open image output")
        bitmap.recycle()
        name
    }
}
