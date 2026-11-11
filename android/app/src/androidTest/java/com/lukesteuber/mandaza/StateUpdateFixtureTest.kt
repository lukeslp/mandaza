package com.lukesteuber.mandaza

import android.net.Uri
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import org.junit.Test
import org.junit.runner.RunWith

/** Run createFixture on 10310, install 10311 in place, then run verifyFixture. */
@RunWith(AndroidJUnit4::class)
class StateUpdateFixtureTest {
    private val context get() = InstrumentationRegistry.getInstrumentation().targetContext
    private val seed = "81c76a23-1400-4bde-a120-62102c670452"
    private fun requireFixtureOptIn() {
        assumeTrue(InstrumentationRegistry.getArguments().getString("updateFixture") == "true")
        check(context.packageName == "app.mandaza.android.debug")
    }

    @Test fun createFixture() {
        requireFixtureOptIn()
        context.getSharedPreferences("mandaza", 0).edit().clear().commit()
        val state = MandazaAppState(context)
        val link = Uri.parse("mandaza://seed/$seed?palette=ember")
        state.handleDeepLink(link)
        state.newPattern()
        state.handleDeepLink(link)
        state.toggleFavorite()
        state.showSeconds = true
        state.parallaxEnabled = false
        state.config = state.config.copy(glow = true)
        state.persist()
        // An instrumentation-only process can exit before apply()'s disk job.
        // Flush the real app's serialized state before the installer replaces it.
        val preferences = context.getSharedPreferences("mandaza", 0)
        val serialized = checkNotNull(preferences.getString("state", null))
        assertTrue(preferences.edit().putString("state", serialized).commit())
        verifyFixture()
    }

    @Test fun verifyFixture() {
        requireFixtureOptIn()
        val state = MandazaAppState(context)
        assertEquals(seed, state.seed)
        assertEquals("ember", state.paletteId)
        assertTrue(state.favorites.any { it.seed == seed })
        assertTrue(state.history.any { it.seed == seed })
        assertTrue(state.showSeconds)
        assertFalse(state.parallaxEnabled)
        assertTrue(state.config.glow)
    }
}
