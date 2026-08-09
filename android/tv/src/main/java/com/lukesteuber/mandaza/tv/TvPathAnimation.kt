package com.lukesteuber.mandaza.tv

import com.lukesteuber.mandaza.core.MandazaCubic
import com.lukesteuber.mandaza.core.MandazaLoop
import com.lukesteuber.mandaza.core.MandazaPoint
import kotlin.math.hypot

internal data class PreparedCurve(
    val cubic: MandazaCubic,
    val length: Double,
)

internal data class PreparedLoop(
    val source: MandazaLoop,
    val curves: List<PreparedCurve>,
    val totalLength: Double,
)

internal fun prepareLoop(loop: MandazaLoop): PreparedLoop {
    val curves = loop.curves.map { cubic ->
        PreparedCurve(cubic, cubicLengthEstimate(cubic).coerceAtLeast(0.001))
    }
    return PreparedLoop(loop, curves, curves.sumOf(PreparedCurve::length))
}

/** Matches the physical drawing speed used by mandaza.app and MandazaCore. */
internal fun drawDistanceAt(elapsedMs: Double, drawSpeed: Double): Double {
    val pixelsPerMs = (10.0 + 1990.0 * drawSpeed * drawSpeed) / 1000.0
    return elapsedMs.coerceAtLeast(0.0) * pixelsPerMs
}

/** Returns complete cubics plus the in-flight cubic fragment at [distance]. */
internal fun visibleCubics(loop: PreparedLoop, distance: Double): List<MandazaCubic> {
    if (distance <= 0.0) return emptyList()
    val visible = ArrayList<MandazaCubic>(loop.curves.size)
    var remaining = distance
    for (prepared in loop.curves) {
        if (remaining >= prepared.length) {
            visible += prepared.cubic
            remaining -= prepared.length
            continue
        }
        if (remaining > 0.0) {
            visible += splitCubic(prepared.cubic, remaining / prepared.length).first
        }
        break
    }
    return visible
}

/** De Casteljau split. The first result is the visible fragment from 0...t. */
internal fun splitCubic(cubic: MandazaCubic, t: Double): Pair<MandazaCubic, MandazaCubic> {
    val amount = t.coerceIn(0.0, 1.0)
    val a = lerp(cubic.start, cubic.control1, amount)
    val b = lerp(cubic.control1, cubic.control2, amount)
    val c = lerp(cubic.control2, cubic.end, amount)
    val d = lerp(a, b, amount)
    val e = lerp(b, c, amount)
    val midpoint = lerp(d, e, amount)
    return MandazaCubic(cubic.start, a, d, midpoint) to
        MandazaCubic(midpoint, e, c, cubic.end)
}

/** Four-chord estimate used by the web and Apple renderers. */
private fun cubicLengthEstimate(cubic: MandazaCubic): Double {
    val halves = splitCubic(cubic, 0.5)
    val quarters = listOf(
        splitCubic(halves.first, 0.5),
        splitCubic(halves.second, 0.5),
    )
    return quarters.sumOf { (first, second) ->
        distance(first.start, first.end) + distance(second.start, second.end)
    }
}

private fun lerp(a: MandazaPoint, b: MandazaPoint, t: Double) = MandazaPoint(
    x = t * b.x + (1.0 - t) * a.x,
    y = t * b.y + (1.0 - t) * a.y,
)

private fun distance(a: MandazaPoint, b: MandazaPoint): Double = hypot(b.x - a.x, b.y - a.y)
