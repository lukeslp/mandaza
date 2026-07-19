package com.lukesteuber.mandaza.core

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotEquals
import kotlin.test.assertTrue

class MandazaEngineTest {
    @Test
    fun `same seed and configuration produce identical geometry`() {
        val first = MandazaEngine().generate(1080.0, 1800.0, "parity-seed")
        val second = MandazaEngine().generate(1080.0, 1800.0, "parity-seed")

        assertEquals(first.fingerprint(), second.fingerprint())
        assertTrue(first.loops.isNotEmpty())
    }

    @Test
    fun `different seeds produce different geometry`() {
        val first = MandazaEngine().generate(1080.0, 1800.0, "seed-a")
        val second = MandazaEngine().generate(1080.0, 1800.0, "seed-b")

        assertNotEquals(first.fingerprint(), second.fingerprint())
    }

    @Test
    fun `external configuration rejects unsafe ranges`() {
        assertTrue(EngineConfig().isValidForExternalRendering)
        assertFalse(EngineConfig(lineWidth = 12.0).isValidForExternalRendering)
        assertFalse(EngineConfig(density = -0.1).isValidForExternalRendering)
    }

    @Test
    fun `palette catalog preserves all iOS palette ids`() {
        assertEquals(
            listOf(
                "aurora", "sunset", "ember", "bioluminescent", "vaporwave", "cyberpunk",
                "risograph", "oxblood", "canopy", "dichromat", "amber", "terrain",
            ),
            MandazaPalettes.all.map { it.id },
        )
    }
}
