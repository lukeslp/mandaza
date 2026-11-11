package com.lukesteuber.mandaza

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import com.lukesteuber.mandaza.core.MandazaPalettes

@Composable
fun MandazaSettings(state: MandazaAppState, onFavorites: () -> Unit) {
    Column(
        Modifier
            .fillMaxWidth()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp),
        verticalArrangement = Arrangement.spacedBy(18.dp),
    ) {
        Text("Tune Mandaza", style = MaterialTheme.typography.headlineSmall)
        SettingSection("Palette") {
            Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                MandazaPalettes.all.forEach { palette ->
                    Column(
                        Modifier.selectable(
                            selected = palette.id == state.paletteId,
                            role = Role.RadioButton,
                            onClick = { state.paletteId = palette.id; state.persist() },
                        ).padding(4.dp),
                        horizontalAlignment = Alignment.CenterHorizontally,
                    ) {
                        Row {
                            palette.colors.forEach { color ->
                                Box(Modifier.size(width = 13.dp, height = 38.dp).background(Color(color.toInt())))
                            }
                        }
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(palette.name, style = MaterialTheme.typography.labelSmall,
                                color = if (palette.id == state.paletteId) Color(0xFF48BFE3) else Color(0xFF9AA5B4))
                            if (palette.id == state.paletteId) {
                                Icon(Icons.Default.Check, contentDescription = null,
                                    modifier = Modifier.size(14.dp))
                            }
                        }
                    }
                }
            }
        }
        SettingSection("Look") {
            ToggleRow("Glow", state.config.glow) {
                state.config = state.config.copy(glow = it, glowStrength = if (it) 1.0 else state.config.glowStrength)
            }
            ToggleRow("Paper canvas", state.paperTheme) { state.paperTheme = it }
            SliderRow("Line width", state.config.lineWidth.toFloat(), 0.5f..3f) {
                state.config = state.config.copy(lineWidth = it.toDouble())
            }
        }
        SettingSection("Pattern") {
            SliderRow("Density", state.config.density.toFloat(), 0f..1f) {
                state.config = state.config.copy(density = it.toDouble())
            }
            Text("Geometry", style = MaterialTheme.typography.labelMedium, color = Color(0xFF9AA5B4))
            Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                listOf("Auto" to -1, "Sparse" to 1, "Medium" to 3, "Dense" to 5, "Busy" to 6).forEach { (label, value) ->
                    val selected = if (value < 0) state.config.randomPattern else !state.config.randomPattern && state.config.geometry == value
                    FilterChip(modifier = Modifier.heightIn(min = 52.dp), selected = selected, onClick = {
                        state.config = if (value < 0) state.config.copy(randomPattern = true)
                        else state.config.copy(randomPattern = false, geometry = value)
                    }, label = { Text(label) })
                }
            }
            ToggleRow("Randomize palette on new", state.randomPalette) { state.randomPalette = it }
        }
        SettingSection("Motion") {
            SliderRow("Drawing speed", state.config.drawSpeed.toFloat(), 0.1f..1f) {
                state.config = state.config.copy(drawSpeed = it.toDouble())
            }
            ToggleRow("Tilt parallax", state.parallaxEnabled) { state.parallaxEnabled = it }
            if (state.parallaxEnabled) SliderRow("Parallax amount", state.parallaxAmount, 0.05f..1f) {
                state.parallaxAmount = it
            }
        }
        SettingSection("Zen") {
            ToggleRow("Zen mode", state.zenMode) { state.zenMode = it }
            ToggleRow("Show clock", state.showClock) { state.showClock = it }
            ToggleRow("Show seconds", state.showSeconds) { state.showSeconds = it }
            ToggleRow("Show date", state.showDate) { state.showDate = it }
            ToggleRow("Music responsivity", state.musicResponsive) { state.musicResponsive = it }
            if (state.musicResponsive) SliderRow("Reactivity", state.reactivity, 0f..1f) { state.reactivity = it }
            Text("Clock form", style = MaterialTheme.typography.labelMedium, color = Color(0xFF9AA5B4))
            Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                listOf("digital", "stacked", "editorial").forEach { form ->
                    FilterChip(modifier = Modifier.heightIn(min = 52.dp), selected = state.clockForm == form, onClick = { state.clockForm = form }, label = { Text(form.replaceFirstChar(Char::uppercase)) })
                }
            }
            Text(
                "Microphone input is reduced to a live level value. Audio is never recorded or stored.",
                style = MaterialTheme.typography.bodySmall,
                color = Color(0xFF9AA5B4),
            )
        }
        if (state.favorites.isNotEmpty()) {
            TextButton(modifier = Modifier.heightIn(min = 52.dp), onClick = { state.persist(); onFavorites() }) {
                Text("All Favorites · ${state.favorites.size}")
            }
        }
        Text(
            "100% on-device · no account · no analytics",
            color = Color(0xFF9AA5B4),
            style = MaterialTheme.typography.bodySmall,
        )
        Spacer(Modifier.height(36.dp))
    }
}

@Composable
private fun SettingSection(title: String, content: @Composable () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text(title.uppercase(), color = Color(0xFF48BFE3), style = MaterialTheme.typography.labelMedium)
        content()
        HorizontalDivider(color = Color.White.copy(alpha = 0.10f))
    }
}

@Composable
private fun ToggleRow(label: String, checked: Boolean, onChange: (Boolean) -> Unit) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Text(label, modifier = Modifier.weight(1f))
        Switch(
            checked = checked,
            onCheckedChange = onChange,
            modifier = Modifier.semantics { contentDescription = label },
        )
    }
}

@Composable
private fun SliderRow(label: String, value: Float, range: ClosedFloatingPointRange<Float>, onChange: (Float) -> Unit) {
    Column {
        Row(Modifier.fillMaxWidth()) {
            Text(label, modifier = Modifier.weight(1f))
            Text("${(value * if (range.endInclusive <= 1f) 100 else 10).toInt()}${if (range.endInclusive <= 1f) "%" else ""}", color = Color(0xFF9AA5B4))
        }
        Slider(
            value = value,
            onValueChange = onChange,
            valueRange = range,
            modifier = Modifier.semantics { contentDescription = label },
        )
    }
}
