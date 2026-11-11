package com.lukesteuber.mandaza

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Bedtime
import androidx.compose.material.icons.filled.BedtimeOff
import androidx.compose.material.icons.filled.Download
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FavoriteBorder
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalViewConfiguration
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import androidx.core.net.toUri
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import kotlinx.coroutines.launch
import java.text.DateFormat
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

private val Void = Color(0xFF05060A)
private val Deep = Color(0xFF0D1018)
private val Paper = Color(0xFFF5F0E8)
private val Muted = Color(0xFF9AA5B4)
private val Cyan = Color(0xFF48BFE3)

private enum class Sheet { History, Favorites, Settings }

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MandazaApp(state: MandazaAppState, activity: ComponentActivity) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    val scope = rememberCoroutineScope()
    val snackbar = remember { SnackbarHostState() }
    val tilt = remember { TiltMonitor(context) }
    val audio = remember { AudioLevelMonitor() }
    var sheet by remember { mutableStateOf<Sheet?>(null) }
    var canvasWidth by remember { mutableFloatStateOf(1f) }
    var canvasHeight by remember { mutableFloatStateOf(1f) }
    var saving by remember { mutableStateOf(false) }
    var saveRequested by remember { mutableStateOf(false) }
    var showPermissionExplanation by remember { mutableStateOf(false) }
    var showStoragePermissionExplanation by remember { mutableStateOf(false) }
    var availableUpdate by remember { mutableStateOf<AvailableUpdate?>(null) }
    var appInForeground by remember {
        mutableStateOf(lifecycleOwner.lifecycle.currentState.isAtLeast(Lifecycle.State.STARTED))
    }
    val micGranted = ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
    var storageGranted by remember {
        mutableStateOf(
            Build.VERSION.SDK_INT >= 29 ||
                ContextCompat.checkSelfPermission(context, Manifest.permission.WRITE_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED,
        )
    }
    val micPermission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted && state.zenMode && state.musicResponsive) audio.start()
        else if (!granted) showPermissionExplanation = true
    }
    val storagePermission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        storageGranted = granted
        if (!granted) {
            saveRequested = false
            showStoragePermissionExplanation = true
        }
    }

    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            when (event) {
                Lifecycle.Event.ON_START -> appInForeground = true
                Lifecycle.Event.ON_STOP -> appInForeground = false
                else -> Unit
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }
    DisposableEffect(state.parallaxEnabled, appInForeground) {
        if (state.parallaxEnabled && appInForeground) tilt.start() else tilt.stop()
        onDispose { tilt.stop() }
    }
    LaunchedEffect(state.zenMode, state.musicResponsive, micGranted, appInForeground) {
        if (shouldActivateAudio(appInForeground, state.zenMode, state.musicResponsive)) {
            if (shouldRequestMicrophone(appInForeground, state.zenMode, state.musicResponsive, micGranted)) {
                micPermission.launch(Manifest.permission.RECORD_AUDIO)
            } else {
                audio.start()
            }
        } else audio.stop()
    }
    DisposableEffect(Unit) { onDispose { audio.stop() } }
    LaunchedEffect(Unit) { availableUpdate = UpdateChecker.checkIfNeeded(context) }
    LaunchedEffect(saveRequested, storageGranted) {
        if (!saveRequested || !storageGranted || saving) return@LaunchedEffect
        saving = true
        try {
            runCatching {
                MandazaExporter.save(
                    context,
                    state.seed,
                    state.paletteId,
                    state.config,
                    paperTheme = state.paperTheme,
                )
            }
                .onSuccess {
                    snackbar.showSnackbar("Saved $it to Pictures/Mandaza")
                    ReviewRequester.recordSuccessfulExport(activity)
                }
                .onFailure { snackbar.showSnackbar("Couldn’t save: ${it.message}") }
        } finally {
            saving = false
            saveRequested = false
        }
    }

    MaterialTheme(colorScheme = darkColorScheme(
        primary = Cyan, background = Void, surface = Deep, onSurface = Paper,
        onBackground = Paper, onSurfaceVariant = Muted,
    )) {
        Scaffold(
            containerColor = Void,
            contentWindowInsets = WindowInsets.safeDrawing,
            snackbarHost = { SnackbarHost(snackbar) },
            bottomBar = {
                if (!state.zenMode) MandazaFooter(
                    state = state,
                    onHistory = { sheet = Sheet.History },
                    onSettings = { sheet = Sheet.Settings },
                    onSave = {
                        if (!saving && !saveRequested) {
                            saveRequested = true
                            if (!storageGranted) {
                                storagePermission.launch(Manifest.permission.WRITE_EXTERNAL_STORAGE)
                            }
                        }
                    },
                    onFavorite = {
                        val added = state.toggleFavorite()
                        scope.launch { snackbar.showSnackbar(if (added) "Saved to Favorites" else "Removed from Favorites") }
                    },
                    onZen = { state.zenMode = true; state.persist() },
                )
            },
        ) { padding ->
            Box(
                Modifier
                    .fillMaxSize()
                    .padding(padding)
                    .onSizeChanged { canvasWidth = it.width.toFloat(); canvasHeight = it.height.toFloat() }
                    .semantics { contentDescription = "Mandaza canvas" }
                    .clickable(role = Role.Button, onClickLabel = "Generate a new Mandaza") { state.newPattern() },
            ) {
                MandazaCanvas(
                    seed = state.seed,
                    paletteId = state.paletteId,
                    config = state.config,
                    canvasWidth = canvasWidth,
                    canvasHeight = canvasHeight,
                    tilt = if (state.parallaxEnabled) tilt.offset else androidx.compose.ui.geometry.Offset.Zero,
                    parallaxAmount = state.parallaxAmount,
                    audioLevel = if (state.zenMode) audio.level else 0f,
                    reactivity = state.reactivity,
                    paperTheme = state.paperTheme,
                    modifier = Modifier.fillMaxSize(),
                )
                if (state.zenMode) {
                    ZenOverlay(state, onExit = { state.zenMode = false; state.persist() })
                }
            }
        }

        when (sheet) {
            Sheet.History -> SnapshotSheet("Previous", state.history, onDismiss = { sheet = null }) {
                state.load(it); sheet = null
            }
            Sheet.Favorites -> SnapshotSheet("Favorites", state.favorites, onDismiss = { sheet = null }) {
                state.load(it); sheet = null
            }
            Sheet.Settings -> ModalBottomSheet(
                sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
                contentWindowInsets = { WindowInsets.safeDrawing },
                onDismissRequest = { state.persist(); sheet = null },
                containerColor = Deep,
                contentColor = Paper,
                dragHandle = { MandazaDragHandle() },
            ) {
                Spacer(Modifier.height(LocalViewConfiguration.current.minimumTouchTargetSize.height / 2))
                MandazaSettings(state, onFavorites = { sheet = Sheet.Favorites })
            }
            null -> Unit
        }
        if (showPermissionExplanation) AlertDialog(
            onDismissRequest = { showPermissionExplanation = false },
            title = { Text("Microphone unavailable") },
            text = { Text("Music responsivity only reads the live sound level. Audio is never recorded, stored, or sent anywhere. You can enable access later in Android Settings.") },
            confirmButton = { TextButton(onClick = { showPermissionExplanation = false }) { Text("OK") } },
        )
        if (showStoragePermissionExplanation) AlertDialog(
            onDismissRequest = { showStoragePermissionExplanation = false },
            title = { Text("Photos access unavailable") },
            text = { Text("Android 9 and earlier need storage permission to save Mandaza images. You can enable it later in Android Settings.") },
            confirmButton = { TextButton(onClick = { showStoragePermissionExplanation = false }) { Text("OK") } },
        )
        availableUpdate?.let { update ->
            AlertDialog(
                onDismissRequest = { availableUpdate = null },
                title = { Text("A new Mandaza is available") },
                text = { Text("Version ${update.version} is ready to download.") },
                confirmButton = {
                    TextButton(onClick = {
                        context.startActivity(Intent(Intent.ACTION_VIEW, update.downloadPage.toUri()))
                        availableUpdate = null
                    }) { Text("Download") }
                },
                dismissButton = {
                    TextButton(onClick = { availableUpdate = null }) { Text("Later") }
                },
            )
        }
    }
}

@Composable
private fun MandazaFooter(
    state: MandazaAppState,
    onHistory: () -> Unit,
    onSettings: () -> Unit,
    onSave: () -> Unit,
    onFavorite: () -> Unit,
    onZen: () -> Unit,
) {
    NavigationBar(containerColor = Void.copy(alpha = 0.96f), contentColor = Paper) {
        NavigationBarItem(selected = false, enabled = state.history.isNotEmpty(), onClick = onHistory,
            icon = { Icon(Icons.Default.History, null) }, label = { Text("History", fontSize = 10.sp) })
        NavigationBarItem(selected = state.isFavorite(), onClick = onFavorite,
            icon = { Icon(if (state.isFavorite()) Icons.Default.Favorite else Icons.Default.FavoriteBorder, null) },
            label = { Text(if (state.isFavorite()) "Saved" else "Favorite", fontSize = 10.sp) })
        NavigationBarItem(selected = false, onClick = onZen,
            icon = { Icon(Icons.Default.Bedtime, null, tint = Cyan) }, label = { Text("Zen", fontSize = 10.sp) })
        NavigationBarItem(selected = false, onClick = onSettings,
            icon = { Icon(Icons.Default.Tune, null) }, label = { Text("Tune", fontSize = 10.sp) })
        NavigationBarItem(selected = false, onClick = onSave,
            icon = { Icon(Icons.Default.Download, null) }, label = { Text("Save", fontSize = 10.sp) })
    }
}

@Composable
private fun ZenOverlay(state: MandazaAppState, onExit: () -> Unit) {
    Box(Modifier.fillMaxSize().statusBarsPadding()) {
        if (state.showClock) {
            val now by currentTime(state.showSeconds)
            val time = SimpleDateFormat(if (state.showSeconds) "h:mm:ss" else "h:mm", Locale.getDefault()).format(Date(now))
            val date = DateFormat.getDateInstance(DateFormat.MEDIUM).format(Date(now))
            val text = when (state.clockForm) {
                "stacked" -> time.replace(":", "\n")
                "editorial" -> "$time${if (state.showDate) "  ·  $date" else ""}"
                else -> buildString { append(time); if (state.showDate) append("\n$date") }
            }
            Surface(
                modifier = Modifier.align(Alignment.Center),
                color = Color.Black.copy(alpha = 0.38f),
                shape = MaterialTheme.shapes.large,
            ) { Text(text, color = Paper, fontSize = if (state.clockForm == "stacked") 58.sp else 48.sp,
                lineHeight = 54.sp, modifier = Modifier.padding(horizontal = 28.dp, vertical = 18.dp)) }
        }
        IconButton(onClick = onExit, modifier = Modifier.align(Alignment.TopEnd).padding(12.dp).size(52.dp)) {
            Icon(Icons.Default.BedtimeOff, contentDescription = "Exit Zen", tint = Paper)
        }
    }
}

@Composable
private fun currentTime(showSeconds: Boolean): androidx.compose.runtime.State<Long> =
    androidx.compose.runtime.produceState(System.currentTimeMillis(), showSeconds) {
        while (true) {
            value = System.currentTimeMillis()
            kotlinx.coroutines.delay(if (showSeconds) 1000 else 15_000)
        }
    }

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SnapshotSheet(
    title: String,
    items: List<com.lukesteuber.mandaza.core.MandazaSnapshot>,
    onDismiss: () -> Unit,
    onSelect: (com.lukesteuber.mandaza.core.MandazaSnapshot) -> Unit,
) {
    ModalBottomSheet(sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        contentWindowInsets = { WindowInsets.safeDrawing },
        onDismissRequest = onDismiss, containerColor = Deep, contentColor = Paper,
        dragHandle = { MandazaDragHandle() }) {
        // Clipped scrolling children retain half a minimum touch target above
        // their viewport. Keep that overhang clear of the sheet handle.
        Spacer(Modifier.height(LocalViewConfiguration.current.minimumTouchTargetSize.height / 2))
        LazyColumn(Modifier.fillMaxWidth(),
            contentPadding = PaddingValues(horizontal = 20.dp, vertical = 10.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)) {
            item { Text(title, style = MaterialTheme.typography.headlineSmall) }
            if (items.isEmpty()) item { Text("Nothing here yet.", color = Muted) }
            items(items, key = { it.seed }) { snapshot ->
                val palette = com.lukesteuber.mandaza.core.MandazaPalettes.byId(snapshot.paletteId)
                Row(
                    Modifier.fillMaxWidth()
                        .clickable(role = Role.Button) { onSelect(snapshot) }
                        .semantics { contentDescription = "Load ${palette.name} pattern ${snapshot.seed.take(13)}" }
                        .padding(vertical = 12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Box(Modifier.size(42.dp).background(Color(palette.colors.last().toInt()), MaterialTheme.shapes.medium))
                    Column(Modifier.padding(start = 12.dp)) {
                        Text(palette.name)
                        Text(snapshot.seed.take(13), color = Muted, fontSize = 12.sp)
                    }
                }
            }
        }
    }
}

@Composable
private fun MandazaDragHandle() {
    // A little above 48dp also avoids fractional-density bounds rounding
    // below the minimum accessible touch size.
    Box(Modifier.size(52.dp).semantics { contentDescription = "Sheet handle" },
        contentAlignment = Alignment.Center) {
        Box(Modifier.size(width = 32.dp, height = 4.dp)
            .background(Muted, RoundedCornerShape(2.dp)))
    }
}
