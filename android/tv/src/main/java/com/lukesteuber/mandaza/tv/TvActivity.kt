package com.lukesteuber.mandaza.tv

import android.annotation.SuppressLint
import android.os.Bundle
import android.view.KeyEvent
import android.view.WindowManager
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat

/**
 * Host for MandazaTV. Remote keys are handled both here ([dispatchKeyEvent]) and
 * in Compose — Samsung / Fire remotes often never reach [onKeyDown] once Compose
 * owns focus.
 */
class TvActivity : ComponentActivity() {
    private lateinit var state: TvState
    val remote = TvRemoteBridge()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        WindowCompat.setDecorFitsSystemWindows(window, false)
        WindowInsetsControllerCompat(window, window.decorView).apply {
            hide(WindowInsetsCompat.Type.systemBars())
            systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        }
        state = TvState(applicationContext)
        setContent {
            TvApp(state = state, remote = remote)
        }
    }

    @SuppressLint("RestrictedApi")
    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (event.action == KeyEvent.ACTION_DOWN && handleRemoteKey(event.keyCode)) {
            return true
        }
        // Pass through keys the TV interaction model does not own.
        return super.dispatchKeyEvent(event)
    }

    // Fire/Android TV remotes deliver a hardware Back key. This TV-only
    // activity handles it directly; touch back gestures are outside its input contract.
    @SuppressLint("GestureBackNavigation")
    private fun handleRemoteKey(keyCode: Int): Boolean {
        return when (keyCode) {
            KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE,
            KeyEvent.KEYCODE_MEDIA_PLAY,
            -> {
                state.newPattern()
                true
            }
            KeyEvent.KEYCODE_DPAD_CENTER,
            KeyEvent.KEYCODE_BUTTON_A,
            KeyEvent.KEYCODE_BUTTON_SELECT,
            KeyEvent.KEYCODE_ENTER,
            KeyEvent.KEYCODE_NUMPAD_ENTER,
            KeyEvent.KEYCODE_SPACE,
            -> {
                if (!remote.showChrome) {
                    state.newPattern()
                    true
                } else {
                    activateSelection()
                    true
                }
            }
            KeyEvent.KEYCODE_DPAD_LEFT -> {
                if (!remote.showChrome) {
                    remote.showChrome = true
                    remote.selectedRow = TvRemoteBridge.PRIMARY_ROW
                    remote.selectedIndex = 0
                } else {
                    remote.moveHorizontal(-1)
                }
                true
            }
            KeyEvent.KEYCODE_DPAD_RIGHT -> {
                if (!remote.showChrome) {
                    remote.showChrome = true
                    remote.selectedRow = TvRemoteBridge.PRIMARY_ROW
                    remote.selectedIndex = 0
                } else {
                    remote.moveHorizontal(1)
                }
                true
            }
            KeyEvent.KEYCODE_DPAD_UP,
            KeyEvent.KEYCODE_DPAD_DOWN,
            -> {
                if (!remote.showChrome) {
                    remote.showChrome = true
                    remote.selectedRow = TvRemoteBridge.PRIMARY_ROW
                    remote.selectedIndex = 0
                    true
                } else {
                    if (remote.tuneOpen) {
                        remote.selectedRow = if (keyCode == KeyEvent.KEYCODE_DPAD_UP) {
                            TvRemoteBridge.TUNE_ROW
                        } else {
                            TvRemoteBridge.PRIMARY_ROW
                        }
                        remote.selectedIndex = 0
                    }
                    true
                }
            }
            KeyEvent.KEYCODE_BACK,
            KeyEvent.KEYCODE_ESCAPE,
            KeyEvent.KEYCODE_BUTTON_B,
            -> {
                when {
                    state.zenMode -> {
                        state.exitZen()
                        remote.showChrome = true
                    }
                    remote.tuneOpen -> {
                        remote.tuneOpen = false
                        remote.selectedRow = TvRemoteBridge.PRIMARY_ROW
                        remote.selectedIndex = 2
                    }
                    else -> {
                        remote.showChrome = !remote.showChrome
                        if (remote.showChrome) {
                            remote.selectedRow = TvRemoteBridge.PRIMARY_ROW
                            remote.selectedIndex = 0
                        }
                    }
                }
                true
            }
            else -> false
        }
    }

    private fun activateSelection() {
        if (remote.selectedRow == TvRemoteBridge.TUNE_ROW && remote.tuneOpen) {
            when (remote.selectedIndex) {
                0 -> state.cyclePalette(-1)
                1 -> state.cyclePalette(1)
                2 -> state.toggleTheme()
                3 -> state.toggleClock()
            }
            return
        }
        when (remote.selectedIndex.coerceIn(0, 2)) {
            0 -> state.newPattern()
            1 -> {
                remote.tuneOpen = false
                remote.showChrome = false
                state.enterZen()
            }
            2 -> {
                remote.tuneOpen = !remote.tuneOpen
                remote.selectedRow = TvRemoteBridge.PRIMARY_ROW
                remote.selectedIndex = 2
            }
        }
    }
}

/** Shared mutable chrome flag for Activity key path + Compose UI. */
class TvRemoteBridge {
    companion object {
        const val PRIMARY_ROW = 0
        const val TUNE_ROW = 1
    }

    var showChrome by mutableStateOf(true)
    var tuneOpen by mutableStateOf(false)
    var selectedRow by mutableIntStateOf(PRIMARY_ROW)
    var selectedIndex by mutableIntStateOf(0)

    fun moveHorizontal(delta: Int) {
        val count = if (selectedRow == TUNE_ROW && tuneOpen) 4 else 3
        selectedIndex = (selectedIndex + delta).mod(count)
    }
}
