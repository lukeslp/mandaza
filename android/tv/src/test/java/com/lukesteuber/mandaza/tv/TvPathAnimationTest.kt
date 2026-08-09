package com.lukesteuber.mandaza.tv

import com.lukesteuber.mandaza.core.MandazaCubic
import com.lukesteuber.mandaza.core.MandazaLoop
import com.lukesteuber.mandaza.core.MandazaPoint
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class TvPathAnimationTest {
    private val first = MandazaCubic(
        MandazaPoint(0.0, 0.0),
        MandazaPoint(25.0, 0.0),
        MandazaPoint(75.0, 0.0),
        MandazaPoint(100.0, 0.0),
    )
    private val second = MandazaCubic(
        MandazaPoint(100.0, 0.0),
        MandazaPoint(125.0, 0.0),
        MandazaPoint(175.0, 0.0),
        MandazaPoint(200.0, 0.0),
    )
    private val loop = prepareLoop(MandazaLoop(listOf(first, second), 0, 1))

    @Test
    fun partialDistanceProducesAnInFlightCubic() {
        val visible = visibleCubics(loop, 50.0)

        assertEquals(1, visible.size)
        assertEquals(0.0, visible.first().start.x, 0.001)
        assertEquals(50.0, visible.first().end.x, 0.001)
    }

    @Test
    fun distanceCrossingBoundaryKeepsFullAndPartialCurves() {
        val visible = visibleCubics(loop, 150.0)

        assertEquals(2, visible.size)
        assertEquals(first, visible.first())
        assertEquals(150.0, visible.last().end.x, 0.001)
    }

    @Test
    fun webAndAppleSpeedCurveIsPreserved() {
        val slow = drawDistanceAt(elapsedMs = 1_000.0, drawSpeed = 0.0)
        val default = drawDistanceAt(elapsedMs = 1_000.0, drawSpeed = 0.707)
        val fast = drawDistanceAt(elapsedMs = 1_000.0, drawSpeed = 1.0)

        assertEquals(10.0, slow, 0.001)
        assertEquals(1_004.69951, default, 0.001)
        assertEquals(2_000.0, fast, 0.001)
        assertTrue(slow < default && default < fast)
    }
}
