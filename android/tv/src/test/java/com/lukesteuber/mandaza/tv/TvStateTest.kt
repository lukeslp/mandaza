package com.lukesteuber.mandaza.tv

import com.lukesteuber.mandaza.core.MandazaPalettes
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

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
}
