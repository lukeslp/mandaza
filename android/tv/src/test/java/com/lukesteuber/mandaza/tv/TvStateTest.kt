package com.lukesteuber.mandaza.tv

import com.lukesteuber.mandaza.core.EngineConfig
import com.lukesteuber.mandaza.core.MandazaPalettes
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.random.Random

/**
 * Pure logic checks that do not need a Context-backed TvState.
 * Full TvState persistence is covered on-device.
 */
class TvStateTest {
    @Test
    fun paletteCycleWraps() {
        val list = MandazaPalettes.all
        val start = 0
        val next = (start + 1).mod(list.size)
        val prev = (start - 1).mod(list.size)
        assertEquals(1, next)
        assertEquals(list.size - 1, prev)
        assertTrue(list.isNotEmpty())
    }

    @Test
    fun allPalettesHaveDistinctIds() {
        val ids = MandazaPalettes.all.map { it.id }
        assertEquals(ids.size, ids.toSet().size)
        assertNotEquals(0, ids.size)
    }

    @Test
    fun newPatternLooksStayValidAndVaryComposition() {
        val random = Random(0x4D414E44)
        val looks = List(100) { randomizedTvConfig(EngineConfig(), random) }

        assertTrue(looks.all { it.isValidForExternalRendering })
        assertTrue(looks.all { it.density in 0.12..0.92 })
        assertTrue(looks.all { it.drawSpeed in 0.45..1.0 })
        assertTrue(looks.all { it.lineWidth in 0.65..2.8 })
        assertTrue(looks.any(EngineConfig::randomPattern))
        assertTrue(looks.any { !it.randomPattern })
        assertTrue(looks.map { it.geometry }.toSet().size > 2)
        assertTrue(looks.any(EngineConfig::glow))
        assertTrue(looks.any { !it.glow })
    }

    @Test
    fun remoteSelectionWrapsWithinTheActiveRail() {
        val remote = TvRemoteBridge()

        remote.moveHorizontal(-1)
        assertEquals(2, remote.selectedIndex)

        remote.tuneOpen = true
        remote.selectedRow = TvRemoteBridge.TUNE_ROW
        remote.selectedIndex = 0
        remote.moveHorizontal(-1)
        assertEquals(3, remote.selectedIndex)

        remote.moveHorizontal(1)
        assertEquals(0, remote.selectedIndex)
    }
}
