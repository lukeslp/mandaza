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
import kotlin.random.Random

@Serializable
private data class PersistedTv(
    val seed: String = UUID.randomUUID().toString(),
    val paletteId: String = "aurora",
    val config: EngineConfig = EngineConfig(
        density = 0.45,
        glow = false,
        idlePulse = false,
        lineWidth = 1.35,
    ),
    val showClock: Boolean = true,
    val showDate: Boolean = true,
    val paperTheme: Boolean = false,
    val randomPalette: Boolean = true,
    val zenMode: Boolean = false,
)

/** Lightweight TV state — ambient-first; separate prefs from phone Mandaza. */
class TvState(context: Context) {
    private val preferences = context.getSharedPreferences("mandaza_tv", Context.MODE_PRIVATE)
    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }
    private val restored = preferences.getString("state", null)?.let {
        runCatching { json.decodeFromString<PersistedTv>(it) }.getOrNull()
    } ?: PersistedTv()
    // Normalize prior installs that persisted randomly enabled Fire bloom/pulse.
    private val initial = restored.copy(
        config = restored.config.copy(glow = false, idlePulse = false),
    )

    var seed by mutableStateOf(initial.seed); private set
    var paletteId by mutableStateOf(initial.paletteId)
    var config by mutableStateOf(initial.config)
    var showClock by mutableStateOf(initial.showClock)
    var showDate by mutableStateOf(initial.showDate)
    var paperTheme by mutableStateOf(initial.paperTheme)
    var randomPalette by mutableStateOf(initial.randomPalette)
    var zenMode by mutableStateOf(initial.zenMode); private set

    fun newPattern() {
        seed = UUID.randomUUID().toString()
        val random = Random.Default
        config = randomizedTvConfig(config, random)
        if (randomPalette) {
            paletteId = MandazaPalettes.all.filter { it.id != paletteId }.random(random).id
        }
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

    fun enterZen() {
        zenMode = true
        persist()
    }

    fun exitZen() {
        zenMode = false
        persist()
    }

    private fun persist() {
        val state = PersistedTv(
            seed = seed,
            paletteId = paletteId,
            config = config,
            showClock = showClock,
            showDate = showDate,
            paperTheme = paperTheme,
            randomPalette = randomPalette,
            zenMode = zenMode,
        )
        preferences.edit { putString("state", json.encodeToString(state)) }
    }
}

/** Mobile Mandaza-style pattern variety, with a Fire TV-safe drawing-speed floor. */
internal fun randomizedTvConfig(
    current: EngineConfig,
    random: Random = Random.Default,
): EngineConfig {
    val geometry = listOf(null, 1, 3, 5, 6).random(random)
    return current.copy(
        density = random.nextDouble(0.12, 0.92),
        drawSpeed = random.nextDouble(0.45, 1.0),
        lineWidth = random.nextDouble(0.65, 2.8),
        randomPattern = geometry == null,
        geometry = geometry ?: current.geometry,
        glow = false,
        idlePulse = false,
        glowStrength = 1.0,
    )
}
