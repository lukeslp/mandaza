package com.lukesteuber.mandaza.tv

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.focusable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.lukesteuber.mandaza.core.MandazaPalettes
import kotlinx.coroutines.delay
import java.text.DateFormat
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

private val DockBg = Color(0xE610121A)
private val FocusRing = Color(0xFF48BFE3)
private val Muted = Color(0xFFB8C0CC)
private val Title = Color(0xFFF2F4F8)

@Composable
fun TvApp(
    state: TvState,
    onChromeBinding: (
        chromeVisible: () -> Boolean,
        setChromeVisible: (Boolean) -> Unit,
        regenerate: () -> Unit,
        cyclePalette: (Int) -> Unit,
    ) -> Unit,
) {
    var showChrome by remember { mutableStateOf(true) }
    var canvasW by remember { mutableFloatStateOf(1f) }
    var canvasH by remember { mutableFloatStateOf(1f) }
    var now by remember { mutableStateOf(System.currentTimeMillis()) }
    val primaryFocus = remember { FocusRequester() }

    LaunchedEffect(Unit) {
        onChromeBinding(
            { showChrome },
            { showChrome = it },
            { state.newPattern() },
            { state.cyclePalette(it) },
        )
    }
    LaunchedEffect(showChrome) {
        if (showChrome) {
            runCatching { primaryFocus.requestFocus() }
            // Auto-hide dock for ambient living-room mode (matches MandazaTV spirit).
            delay(18_000)
            showChrome = false
        }
    }
    LaunchedEffect(state.showClock) {
        while (state.showClock) {
            now = System.currentTimeMillis()
            delay(1_000)
        }
    }

    val timeText = remember(now, state.showClock) {
        DateFormat.getTimeInstance(DateFormat.SHORT, Locale.getDefault()).format(Date(now))
    }
    val dateText = remember(now, state.showDate) {
        SimpleDateFormat("EEEE, MMM d", Locale.getDefault()).format(Date(now))
    }
    val paletteName = remember(state.paletteId) {
        MandazaPalettes.byId(state.paletteId).name
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
            .onSizeChanged {
                canvasW = it.width.toFloat()
                canvasH = it.height.toFloat()
            }
            .semantics { contentDescription = "MandazaTV" },
    ) {
        MandazaCanvas(
            seed = state.seed,
            paletteId = state.paletteId,
            config = state.config,
            canvasWidth = canvasW,
            canvasHeight = canvasH,
            paperTheme = state.paperTheme,
            modifier = Modifier
                .fillMaxSize()
                .semantics {
                    contentDescription =
                        "Mandaza canvas. Press Select or Play for a new pattern. Press Back for controls."
                },
        )

        if (state.showClock) {
            Column(
                modifier = Modifier
                    .align(Alignment.TopCenter)
                    .padding(top = 48.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Text(
                    text = timeText,
                    color = Title.copy(alpha = 0.92f),
                    fontSize = 64.sp,
                    fontWeight = FontWeight.Light,
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

        if (!showChrome) {
            Text(
                text = stringResource(R.string.hint_ambient),
                color = Muted.copy(alpha = 0.55f),
                fontSize = 16.sp,
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(bottom = 28.dp),
            )
        }

        if (showChrome) {
            Column(
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .fillMaxWidth()
                    .background(DockBg)
                    .padding(horizontal = 40.dp, vertical = 20.dp),
            ) {
                Text(
                    text = "MandazaTV · $paletteName",
                    color = Muted,
                    fontSize = 16.sp,
                    modifier = Modifier.padding(bottom = 12.dp),
                )
                Row(
                    horizontalArrangement = Arrangement.spacedBy(16.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    TvDockButton(
                        label = stringResource(R.string.dock_new),
                        focusRequester = primaryFocus,
                        onClick = { state.newPattern() },
                    )
                    TvDockButton(
                        label = stringResource(R.string.dock_palette),
                        onClick = { state.cyclePalette(1) },
                    )
                    TvDockButton(
                        label = stringResource(R.string.dock_clock),
                        onClick = { state.toggleClock() },
                    )
                    TvDockButton(
                        label = stringResource(R.string.dock_theme),
                        onClick = { state.toggleTheme() },
                    )
                }
                Text(
                    text = "Select / Play · new pattern   ·   ← → palette   ·   Back · hide controls",
                    color = Muted.copy(alpha = 0.75f),
                    fontSize = 14.sp,
                    modifier = Modifier.padding(top = 14.dp),
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
    val shape = RoundedCornerShape(12.dp)
    TextButton(
        onClick = onClick,
        modifier = Modifier
            .then(if (focusRequester != null) Modifier.focusRequester(focusRequester) else Modifier)
            .onFocusChanged { focused = it.isFocused }
            .focusable()
            .border(
                width = if (focused) 3.dp else 1.dp,
                color = if (focused) FocusRing else Color.White.copy(alpha = 0.25f),
                shape = shape,
            )
            .background(
                if (focused) Color.White.copy(alpha = 0.12f) else Color.Transparent,
                shape,
            )
            .padding(horizontal = 8.dp),
    ) {
        Text(
            text = label,
            color = Title,
            fontSize = 18.sp,
            fontWeight = if (focused) FontWeight.SemiBold else FontWeight.Normal,
        )
    }
}
