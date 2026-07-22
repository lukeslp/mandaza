package com.lukesteuber.mandaza.core

import kotlinx.serialization.Serializable
import java.util.Locale

@Serializable
data class EngineConfig(
    val cellSizeRandom: Boolean = false,
    val density: Double = 0.5,
    val randomPattern: Boolean = true,
    val geometry: Int = 6,
    val withMargin: Boolean = true,
    val concentric: Boolean = true,
    val centered: Boolean = true,
    val regularity: Double = 5.0,
    val drawSpeed: Double = 0.707,
    val glow: Boolean = false,
    val glowStrength: Double = 1.0,
    val idlePulse: Boolean = true,
    val lineWidth: Double = 1.2,
) {
    val isValidForExternalRendering: Boolean
        get() = density.isFinite() && density in 0.0..1.0 &&
            geometry in 0..6 && regularity.isFinite() && regularity in 0.0..100.0 &&
            drawSpeed.isFinite() && drawSpeed in 0.0..1.0 &&
            lineWidth.isFinite() && lineWidth in 0.1..10.0 &&
            glowStrength.isFinite() && glowStrength in 0.18..1.0
}

@Serializable
data class MandazaSnapshot(
    val seed: String,
    val paletteId: String,
    val config: EngineConfig,
    val createdAtEpochMs: Long,
)

data class MandazaPoint(val x: Double, val y: Double)

data class MandazaCubic(
    val start: MandazaPoint,
    val control1: MandazaPoint,
    val control2: MandazaPoint,
    val end: MandazaPoint,
)

data class MandazaLoop(
    val curves: List<MandazaCubic>,
    val colorIndex: Int,
    val colorTotal: Int,
)

data class GeneratedMandaza(
    val width: Double,
    val height: Double,
    val radius: Double,
    val seed: String,
    val loops: List<MandazaLoop>,
) {
    fun fingerprint(): String = buildString {
        append(seed).append('|').append("%.4f".format(Locale.ROOT, radius)).append('|')
        loops.forEach { loop ->
            loop.curves.forEach { curve ->
                append("%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f;".format(Locale.ROOT,
                    curve.start.x, curve.start.y,
                    curve.control1.x, curve.control1.y,
                    curve.control2.x, curve.control2.y,
                    curve.end.x, curve.end.y,
                ))
            }
            append('/')
        }
    }
}
