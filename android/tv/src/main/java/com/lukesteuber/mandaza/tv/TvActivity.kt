package com.lukesteuber.mandaza.tv

import android.os.Bundle
import android.view.KeyEvent
import android.view.WindowManager
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.runtime.getValue
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

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (event.action == KeyEvent.ACTION_DOWN && handleRemoteKey(event.keyCode)) {
            return true
        }
        // Let Compose buttons still receive focus moves when chrome is open.
        return super.dispatchKeyEvent(event)
    }

    private fun handleRemoteKey(keyCode: Int): Boolean {
        return when (keyCode) {
            KeyEvent.KEYCODE_DPAD_CENTER,
            KeyEvent.KEYCODE_BUTTON_A,
            KeyEvent.KEYCODE_BUTTON_SELECT,
            KeyEvent.KEYCODE_ENTER,
            KeyEvent.KEYCODE_NUMPAD_ENTER,
            KeyEvent.KEYCODE_SPACE,
            KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE,
            KeyEvent.KEYCODE_MEDIA_PLAY,
            -> {
                state.newPattern()
                true
            }
            KeyEvent.KEYCODE_DPAD_LEFT -> {
                if (remote.showChrome) state.cyclePalette(-1)
                else remote.showChrome = true
                true
            }
            KeyEvent.KEYCODE_DPAD_RIGHT -> {
                if (remote.showChrome) state.cyclePalette(1)
                else remote.showChrome = true
                true
            }
            KeyEvent.KEYCODE_DPAD_UP,
            KeyEvent.KEYCODE_DPAD_DOWN,
            -> {
                if (!remote.showChrome) {
                    remote.showChrome = true
                    true
                } else {
                    false // allow focus travel in dock
                }
            }
            KeyEvent.KEYCODE_BACK,
            KeyEvent.KEYCODE_ESCAPE,
            KeyEvent.KEYCODE_BUTTON_B,
            -> {
                remote.showChrome = !remote.showChrome
                true
            }
            else -> false
        }
    }
}

/** Shared mutable chrome flag for Activity key path + Compose UI. */
class TvRemoteBridge {
    var showChrome by mutableStateOf(true)
}
