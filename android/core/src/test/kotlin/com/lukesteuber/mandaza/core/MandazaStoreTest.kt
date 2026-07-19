package com.lukesteuber.mandaza.core

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class MandazaStoreTest {
    @Test
    fun `history stays newest first and bounded`() {
        val store = MandazaCollectionStore(historyLimit = 3)
        repeat(5) { index -> store.remember(snapshot("seed-$index")) }

        assertEquals(listOf("seed-4", "seed-3", "seed-2"), store.history.map { it.seed })
    }

    @Test
    fun `favorites toggle by stable seed`() {
        val store = MandazaCollectionStore()
        val item = snapshot("favorite")

        assertTrue(store.toggleFavorite(item))
        assertTrue(store.isFavorite(item.seed))
        assertFalse(store.toggleFavorite(item))
        assertFalse(store.isFavorite(item.seed))
    }

    private fun snapshot(seed: String) = MandazaSnapshot(
        seed = seed,
        paletteId = "aurora",
        config = EngineConfig(),
        createdAtEpochMs = 1L,
    )
}
