package com.lukesteuber.mandaza.tv

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.focusable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.lukesteuber.mandaza.core.MandazaPalettes
import kotlinx.coroutines.delay
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

private val Void = Color(0xFF05060A)
private val Deep = Color(0xF20D1018)
private val Paper = Color(0xFFF5F0E8)
private val Muted = Color(0xFF9AA5B4)
private val Cyan = Color(0xFF48BFE3)

@Composable
fun TvApp(
    state: TvState,
    remote: TvRemoteBridge,
) {
    var nowMs by remember { mutableLongStateOf(System.currentTimeMillis()) }

    LaunchedEffect(Unit) {
        while (true) {
            nowMs = System.currentTimeMillis()
            delay(1_000)
        }
    }
    val timeText = remember(nowMs) {
        SimpleDateFormat("h:mm", Locale.getDefault()).format(Date(nowMs))
    }
    val dateText = remember(nowMs) {
        SimpleDateFormat("EEE, MMM d", Locale.getDefault()).format(Date(nowMs))
    }
    val paletteName = remember(state.paletteId) {
        MandazaPalettes.byId(state.paletteId).name
    }

    BoxWithConstraints(
        modifier = Modifier
            .fillMaxSize()
            .background(Void)
            .focusable()
            .semantics { contentDescription = "Mandaza ambient canvas" },
    ) {
        MandazaCanvas(
            seed = state.seed,
            paletteId = state.paletteId,
            config = state.config,
            canvasWidth = constraints.maxWidth.toFloat().coerceAtLeast(2f),
            canvasHeight = constraints.maxHeight.toFloat().coerceAtLeast(2f),
            paperTheme = state.paperTheme,
            modifier = Modifier.fillMaxSize(),
        )

        if (state.zenMode && state.showClock) {
            Surface(
                modifier = Modifier.align(Alignment.Center),
                color = Color.Black.copy(alpha = 0.42f),
                shape = RoundedCornerShape(28.dp),
            ) {
                Column(
                    modifier = Modifier.padding(horizontal = 44.dp, vertical = 24.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Text(
                        text = timeText,
                        color = Paper,
                        fontSize = 68.sp,
                        fontWeight = FontWeight.Light,
                        fontFamily = FontFamily.SansSerif,
                    )
                    if (state.showDate) {
                        Text(
                            text = dateText,
                            color = Muted,
                            fontSize = 22.sp,
                            modifier = Modifier.padding(top = 4.dp),
                        )
                    }
                }
            }
        }

        if (state.zenMode) {
            Text(
                text = "Back  ·  leave Zen",
                color = Paper.copy(alpha = 0.46f),
                fontSize = 17.sp,
                modifier = Modifier.align(Alignment.BottomCenter).padding(bottom = 30.dp),
            )
        } else if (!remote.showChrome) {
            Text(
                text = "Select  ·  new pattern     Back  ·  controls",
                color = Paper.copy(alpha = 0.42f),
                fontSize = 17.sp,
                modifier = Modifier.align(Alignment.BottomCenter).padding(bottom = 30.dp),
            )
        }

        if (remote.showChrome && !state.zenMode) {
            Column(
                modifier = Modifier.align(Alignment.BottomCenter).padding(bottom = 34.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                if (remote.tuneOpen) {
                    Surface(
                        color = Deep,
                        shape = RoundedCornerShape(22.dp),
                        shadowElevation = 10.dp,
                    ) {
                        Column(
                            modifier = Modifier.padding(horizontal = 22.dp, vertical = 18.dp),
                            horizontalAlignment = Alignment.CenterHorizontally,
                        ) {
                            Text(
                                text = "TUNE  ·  $paletteName",
                                color = Muted,
                                fontSize = 14.sp,
                                fontWeight = FontWeight.SemiBold,
                                modifier = Modifier.padding(bottom = 12.dp),
                            )
                            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                                TvRailButton(
                                    "Previous color",
                                    selected = remote.selectedRow == TvRemoteBridge.TUNE_ROW && remote.selectedIndex == 0,
                                ) { state.cyclePalette(-1) }
                                TvRailButton(
                                    "Next color",
                                    selected = remote.selectedRow == TvRemoteBridge.TUNE_ROW && remote.selectedIndex == 1,
                                ) { state.cyclePalette(1) }
                                TvRailButton(
                                    if (state.paperTheme) "Paper canvas" else "Dark canvas",
                                    selected = remote.selectedRow == TvRemoteBridge.TUNE_ROW && remote.selectedIndex == 2,
                                ) {
                                    state.toggleTheme()
                                }
                                TvRailButton(
                                    if (state.showClock) "Clock on" else "Clock off",
                                    selected = remote.selectedRow == TvRemoteBridge.TUNE_ROW && remote.selectedIndex == 3,
                                ) {
                                    state.toggleClock()
                                }
                            }
                        }
                    }
                }

                Surface(
                    color = Deep,
                    shape = RoundedCornerShape(24.dp),
                    shadowElevation = 12.dp,
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 14.dp, vertical = 12.dp),
                        horizontalArrangement = Arrangement.spacedBy(10.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        TvRailButton(
                            label = "New",
                            hint = "another pattern",
                            selected = remote.selectedRow == TvRemoteBridge.PRIMARY_ROW && remote.selectedIndex == 0,
                        ) { state.newPattern() }
                        TvRailButton(
                            label = "Zen",
                            hint = "clock + canvas",
                            accent = true,
                            selected = remote.selectedRow == TvRemoteBridge.PRIMARY_ROW && remote.selectedIndex == 1,
                        ) {
                            remote.tuneOpen = false
                            remote.showChrome = false
                            state.enterZen()
                        }
                        TvRailButton(
                            label = "Tune",
                            hint = "color + canvas",
                            selected = remote.selectedRow == TvRemoteBridge.PRIMARY_ROW && remote.selectedIndex == 2,
                        ) { remote.tuneOpen = !remote.tuneOpen }
                    }
                }
            }
        }
    }
}

@Composable
private fun TvRailButton(
    label: String,
    hint: String? = null,
    accent: Boolean = false,
    selected: Boolean = false,
    onClick: () -> Unit,
) {
    var focused by remember { mutableStateOf(false) }
    val shape = RoundedCornerShape(16.dp)
    val borderColor = when {
        focused -> Cyan
        selected -> Cyan.copy(alpha = 0.68f)
        else -> Paper.copy(alpha = 0.16f)
    }
    Surface(
        onClick = onClick,
        shape = shape,
        color = when {
            focused -> Paper.copy(alpha = 0.14f)
            selected -> Cyan.copy(alpha = 0.12f)
            else -> Paper.copy(alpha = 0.045f)
        },
        modifier = Modifier
            .widthIn(min = if (hint == null) 138.dp else 156.dp)
            .onFocusChanged { focused = it.isFocused }
            .focusable()
            .border(if (focused) 3.dp else 1.dp, borderColor, shape)
            .clip(shape),
    ) {
        Column(
            modifier = Modifier.padding(horizontal = 20.dp, vertical = if (hint == null) 14.dp else 12.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                text = label,
                color = if (accent || selected) Cyan else Paper,
                fontSize = if (hint == null) 18.sp else 20.sp,
                fontWeight = if (focused || accent || selected) FontWeight.SemiBold else FontWeight.Normal,
            )
            if (hint != null) {
                Text(
                    text = hint,
                    color = Muted,
                    fontSize = 12.sp,
                    modifier = Modifier.padding(top = 2.dp),
                )
            }
        }
    }
}
