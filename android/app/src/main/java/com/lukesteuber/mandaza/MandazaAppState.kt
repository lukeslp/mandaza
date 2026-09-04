package com.lukesteuber.mandaza

import android.content.Context
import android.net.Uri
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.core.content.edit
import com.lukesteuber.mandaza.core.EngineConfig
import com.lukesteuber.mandaza.core.MandazaPalettes
import com.lukesteuber.mandaza.core.MandazaSnapshot
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.util.UUID

internal const val DEFAULT_MUSIC_RESPONSIVE = false

@Serializable
private data class PersistedMandaza(
    val seed: String = UUID.randomUUID().toString(),
    val paletteId: String = "aurora",
    val config: EngineConfig = EngineConfig(),
    val history: List<MandazaSnapshot> = emptyList(),
    val favorites: List<MandazaSnapshot> = emptyList(),
    val zenMode: Boolean = false,
    val showClock: Boolean = true,
    val showSeconds: Boolean = false,
    val showDate: Boolean = true,
    val clockForm: String = "digital",
    val musicResponsive: Boolean = DEFAULT_MUSIC_RESPONSIVE,
    val reactivity: Float = 0.35f,
    val parallaxEnabled: Boolean = true,
    val parallaxAmount: Float = 0.32f,
    val paperTheme: Boolean = false,
    val randomPalette: Boolean = true,
)

class MandazaAppState(context: Context) {
    private val preferences = context.getSharedPreferences("mandaza", Context.MODE_PRIVATE)
    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }
    private val initial = preferences.getString("state", null)?.let {
        runCatching { json.decodeFromString<PersistedMandaza>(it) }.getOrNull()
    } ?: PersistedMandaza()

    var seed by mutableStateOf(initial.seed); private set
    var paletteId by mutableStateOf(initial.paletteId)
    var config by mutableStateOf(initial.config)
    var history by mutableStateOf(initial.history); private set
    var favorites by mutableStateOf(initial.favorites); private set
    var zenMode by mutableStateOf(initial.zenMode)
    var showClock by mutableStateOf(initial.showClock)
    var showSeconds by mutableStateOf(initial.showSeconds)
    var showDate by mutableStateOf(initial.showDate)
    var clockForm by mutableStateOf(initial.clockForm)
    var musicResponsive by mutableStateOf(initial.musicResponsive)
    var reactivity by mutableFloatStateOf(initial.reactivity)
    var parallaxEnabled by mutableStateOf(initial.parallaxEnabled)
    var parallaxAmount by mutableFloatStateOf(initial.parallaxAmount)
    var paperTheme by mutableStateOf(initial.paperTheme)
    var randomPalette by mutableStateOf(initial.randomPalette)

    val currentSnapshot: MandazaSnapshot
        get() = MandazaSnapshot(seed, paletteId, config, System.currentTimeMillis())

    fun newPattern() {
        history = (listOf(currentSnapshot) + history.filterNot { it.seed == seed }).take(8)
        seed = UUID.randomUUID().toString()
        if (randomPalette) paletteId = MandazaPalettes.all.random().id
        persist()
    }

    fun toggleFavorite(): Boolean {
        val existing = favorites.indexOfFirst { it.seed == seed }
        val nowFavorite = existing < 0
        favorites = if (nowFavorite) listOf(currentSnapshot) + favorites
        else favorites.toMutableList().also { it.removeAt(existing) }
        persist()
        return nowFavorite
    }

    fun isFavorite() = favorites.any { it.seed == seed }

    fun load(snapshot: MandazaSnapshot) {
        seed = snapshot.seed
        paletteId = snapshot.paletteId
        config = snapshot.config
        persist()
    }

    fun handleDeepLink(uri: Uri?) {
        if (uri?.scheme != "mandaza" || uri.host != "seed") return
        val candidate = uri.pathSegments.singleOrNull()?.takeIf { it.isNotBlank() } ?: return
        val incoming = runCatching { UUID.fromString(candidate).toString() }.getOrNull()
            ?: candidate.takeIf { it.startsWith("widget-") && it.length <= 512 }
            ?: return
        seed = incoming
        uri.getQueryParameter("palette")?.let { paletteId = MandazaPalettes.byId(it).id }
        persist()
    }

    fun persist() {
        val state = PersistedMandaza(
            seed, paletteId, config, history, favorites, zenMode, showClock,
            showSeconds, showDate, clockForm, musicResponsive, reactivity,
            parallaxEnabled, parallaxAmount, paperTheme, randomPalette,
        )
        preferences.edit { putString("state", json.encodeToString(state)) }
    }
}
