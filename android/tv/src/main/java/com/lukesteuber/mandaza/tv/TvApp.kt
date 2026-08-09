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
import androidx.compose.foundation.layout.fillMaxWidth
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
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onPreviewKeyEvent
import androidx.compose.ui.input.key.type
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

private val DockBg = Color(0xF010121A)
private val FocusRing = Color(0xFF48BFE3)
private val Muted = Color(0xFFB8C0CC)
private val Title = Color(0xFFF2F4F8)

@Composable
fun TvApp(
    state: TvState,
    remote: TvRemoteBridge,
) {
    val rootFocus = remember { FocusRequester() }
    val primaryButtonFocus = remember { FocusRequester() }

    // Always tick the clock; only *display* when showClock is on.
    var nowMs by remember { mutableLongStateOf(System.currentTimeMillis()) }
    LaunchedEffect(Unit) {
        while (true) {
            nowMs = System.currentTimeMillis()
            delay(1_000)
        }
    }

    LaunchedEffect(remote.showChrome) {
        if (remote.showChrome) {
            runCatching { primaryButtonFocus.requestFocus() }
            delay(18_000)
            remote.showChrome = false
        } else {
            // Keep a focus target so Samsung remotes keep delivering keys.
            runCatching { rootFocus.requestFocus() }
        }
    }
    LaunchedEffect(Unit) {
        delay(50)
        runCatching { primaryButtonFocus.requestFocus() }
    }

    val timeText = remember(nowMs) {
        // Explicit pattern — avoids odd SHORT formats / empty glyphs on some TV locales.
        SimpleDateFormat("h:mm a", Locale.getDefault()).format(Date(nowMs))
    }
    val dateText = remember(nowMs) {
        SimpleDateFormat("EEEE, MMM d", Locale.getDefault()).format(Date(nowMs))
    }
    val paletteName = remember(state.paletteId) {
        MandazaPalettes.byId(state.paletteId).name
    }

    BoxWithConstraints(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
            .focusRequester(rootFocus)
            .focusable()
            .onPreviewKeyEvent { event ->
                // Secondary path if Activity dispatch is swallowed by a parent.
                if (event.type != KeyEventType.KeyDown) return@onPreviewKeyEvent false
                when (event.key) {
                    Key.DirectionCenter, Key.Enter, Key.NumPadEnter -> {
                        state.newPattern()
                        true
                    }
                    Key.Back -> {
                        remote.showChrome = !remote.showChrome
                        true
                    }
                    else -> false
                }
            }
            .semantics { contentDescription = "MandazaTV ambient canvas" },
    ) {
        val canvasW = constraints.maxWidth.toFloat().coerceAtLeast(2f)
        val canvasH = constraints.maxHeight.toFloat().coerceAtLeast(2f)

        MandazaCanvas(
            seed = state.seed,
            paletteId = state.paletteId,
            config = state.config,
            canvasWidth = canvasW,
            canvasHeight = canvasH,
            paperTheme = state.paperTheme,
            modifier = Modifier.fillMaxSize(),
        )

        if (state.showClock) {
            Column(
                modifier = Modifier
                    .align(Alignment.TopCenter)
                    .padding(top = 56.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Text(
                    text = timeText,
                    color = Title.copy(alpha = 0.94f),
                    fontSize = 72.sp,
                    fontWeight = FontWeight.Light,
                    fontFamily = FontFamily.SansSerif,
                )
                if (state.showDate) {
                    Text(
                        text = dateText,
                        color = Muted,
                        fontSize = 24.sp,
                        modifier = Modifier.padding(top = 6.dp),
                    )
                }
            }
        }

        if (!remote.showChrome) {
            Text(
                text = "Back · show controls   ·   Select · new pattern",
                color = Muted.copy(alpha = 0.5f),
                fontSize = 18.sp,
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(bottom = 36.dp),
            )
        }

        if (remote.showChrome) {
            Column(
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .fillMaxWidth()
                    .background(DockBg)
                    .padding(horizontal = 48.dp, vertical = 28.dp),
            ) {
                Text(
                    text = "MandazaTV  ·  $paletteName",
                    color = Muted,
                    fontSize = 18.sp,
                    modifier = Modifier.padding(bottom = 16.dp),
                )
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(20.dp, Alignment.Start),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    TvDockButton(
                        label = "New pattern",
                        focusRequester = primaryButtonFocus,
                        onClick = { state.newPattern() },
                    )
                    TvDockButton(
                        label = "Next palette",
                        onClick = { state.cyclePalette(1) },
                    )
                    TvDockButton(
                        label = if (state.showClock) "Clock on" else "Clock off",
                        onClick = { state.toggleClock() },
                    )
                    TvDockButton(
                        label = if (state.paperTheme) "Paper" else "Void",
                        onClick = { state.toggleTheme() },
                    )
                }
                Text(
                    text = "Select · new pattern     ← → · palette when dock open     Back · hide / show dock",
                    color = Muted.copy(alpha = 0.8f),
                    fontSize = 16.sp,
                    modifier = Modifier.padding(top = 16.dp),
                )
            }
        }
    }
}

@Composable
private fun TvDockButton(
    label: String,
    focusRequester: FocusRequester? = null,
    onClick: () -> Unit,
) {
    var focused by remember { mutableStateOf(false) }
    val shape = RoundedCornerShape(14.dp)
    Surface(
        onClick = onClick,
        shape = shape,
        color = if (focused) Color.White.copy(alpha = 0.16f) else Color.White.copy(alpha = 0.06f),
        modifier = Modifier
            .widthIn(min = 160.dp)
            .then(if (focusRequester != null) Modifier.focusRequester(focusRequester) else Modifier)
            .onFocusChanged { focused = it.isFocused }
            .focusable()
            .border(
                width = if (focused) 3.dp else 1.dp,
                color = if (focused) FocusRing else Color.White.copy(alpha = 0.22f),
                shape = shape,
            )
            .clip(shape),
    ) {
        Text(
            text = label,
            color = Title,
            fontSize = 20.sp,
            fontWeight = if (focused) FontWeight.SemiBold else FontWeight.Normal,
            modifier = Modifier.padding(horizontal = 22.dp, vertical = 16.dp),
        )
    }
}
