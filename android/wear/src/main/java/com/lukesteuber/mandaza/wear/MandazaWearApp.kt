package com.lukesteuber.mandaza.wear

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.focusable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.input.rotary.onRotaryScrollEvent
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.wear.compose.material3.MaterialTheme
import androidx.wear.compose.material3.Text
import com.lukesteuber.mandaza.core.GeneratedMandaza
import com.lukesteuber.mandaza.core.MandazaEngine
import com.lukesteuber.mandaza.core.MandazaPalettes
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext
import kotlin.random.Random

@Composable
fun MandazaWearApp() {
    var seed by remember { mutableLongStateOf(Random.nextLong()) }
    var paletteIndex by remember { mutableIntStateOf(0) }
    var size by remember { mutableStateOf(androidx.compose.ui.unit.IntSize.Zero) }
    var art by remember { mutableStateOf<GeneratedMandaza?>(null) }
    var progress by remember { mutableStateOf(0f) }
    var showHint by remember { mutableStateOf(true) }
    val focus = remember { FocusRequester() }
    val palette = MandazaPalettes.all[paletteIndex]

    LaunchedEffect(seed, size) {
        if (size.width == 0) return@LaunchedEffect
        progress = 0f
        art = withContext(Dispatchers.Default) {
            MandazaEngine().generate(size.width.toDouble(), size.height.toDouble(), seed.toString())
        }
        repeat(90) { frame ->
            progress = (frame + 1) / 90f
            delay(16)
        }
    }
    LaunchedEffect(Unit) {
        focus.requestFocus()
        delay(3500)
        showHint = false
    }

    MaterialTheme {
        Box(
            Modifier
                .fillMaxSize()
                .background(Color(0xFF070A10))
                .onSizeChanged { size = it }
                .focusRequester(focus)
                .focusable()
                .onRotaryScrollEvent {
                    paletteIndex = (paletteIndex + if (it.verticalScrollPixels > 0) 1 else -1)
                        .floorMod(MandazaPalettes.all.size)
                    showHint = true
                    true
                }
                .pointerInput(Unit) {
                    detectTapGestures(
                        onTap = { seed = Random.nextLong(); showHint = false },
                        onLongPress = { showHint = !showHint },
                    )
                },
        ) {
            Canvas(Modifier.fillMaxSize()) {
                val currentArt = art ?: return@Canvas
                currentArt.loops.forEachIndexed { index, loop ->
                    if (index >= currentArt.loops.size * progress) return@forEachIndexed
                    val path = Path()
                    loop.curves.forEachIndexed { curveIndex, curve ->
                        if (curveIndex == 0) path.moveTo(curve.start.x.toFloat(), curve.start.y.toFloat())
                        path.cubicTo(
                            curve.control1.x.toFloat(), curve.control1.y.toFloat(),
                            curve.control2.x.toFloat(), curve.control2.y.toFloat(),
                            curve.end.x.toFloat(), curve.end.y.toFloat(),
                        )
                    }
                    drawPath(
                        path,
                        color = Color(palette.colorAt(loop.colorIndex.toDouble() / loop.colorTotal.coerceAtLeast(1)).toInt()),
                        style = Stroke(width = 2.2f, cap = StrokeCap.Round),
                    )
                }
            }
            AnimatedVisibility(showHint, Modifier.align(Alignment.Center)) {
                Column(
                    Modifier.background(Color(0xB3070A10)).padding(horizontal = 14.dp, vertical = 9.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(2.dp),
                ) {
                    Text(palette.name, fontSize = 14.sp, color = Color.White)
                    Text("Crown · palette\nTap · new", fontSize = 10.sp, color = Color(0xFFB7C2D0), textAlign = TextAlign.Center)
                }
            }
        }
    }
}

private fun Int.floorMod(divisor: Int): Int = ((this % divisor) + divisor) % divisor
