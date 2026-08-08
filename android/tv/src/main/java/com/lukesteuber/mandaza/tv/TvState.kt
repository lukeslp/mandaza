package com.lukesteuber.mandaza.tv

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.core.content.edit
import com.lukesteuber.mandaza.core.EngineConfig
import com.lukesteuber.mandaza.core.MandazaPalettes
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.util.UUID

@Serializable
private data class PersistedTv(
    val seed: String = UUID.randomUUID().toString(),
    val paletteId: String = "aurora",
    val config: EngineConfig = EngineConfig(
        density = 0.45,
        glow = true,
        glowStrength = 0.85,
        lineWidth = 1.35,
    ),
    val showClock: Boolean = true,
    val showDate: Boolean = true,
    val paperTheme: Boolean = false,
    val randomPalette: Boolean = true,
)

/** Lightweight TV state — ambient-first; separate prefs from phone Mandaza. */
class TvState(context: Context) {
    private val preferences = context.getSharedPreferences("mandaza_tv", Context.MODE_PRIVATE)
    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }
    private val initial = preferences.getString("state", null)?.let {
        runCatching { json.decodeFromString<PersistedTv>(it) }.getOrNull()
    } ?: PersistedTv()

    var seed by mutableStateOf(initial.seed); private set
    var paletteId by mutableStateOf(initial.paletteId)
    var config by mutableStateOf(initial.config)
    var showClock by mutableStateOf(initial.showClock)
    var showDate by mutableStateOf(initial.showDate)
    var paperTheme by mutableStateOf(initial.paperTheme)
    var randomPalette by mutableStateOf(initial.randomPalette)

    fun newPattern() {
        seed = UUID.randomUUID().toString()
        if (randomPalette) paletteId = MandazaPalettes.all.random().id
        persist()
    }

    fun cyclePalette(delta: Int) {
        val list = MandazaPalettes.all
        val index = list.indexOfFirst { it.id == paletteId }.coerceAtLeast(0)
        paletteId = list[(index + delta).mod(list.size)].id
        persist()
    }

    fun toggleClock() {
        showClock = !showClock
        persist()
    }

    fun toggleTheme() {
        paperTheme = !paperTheme
        persist()
    }

    private fun persist() {
        val state = PersistedTv(
            seed, paletteId, config, showClock, showDate, paperTheme, randomPalette,
        )
        preferences.edit { putString("state", json.encodeToString(state)) }
    }
}
