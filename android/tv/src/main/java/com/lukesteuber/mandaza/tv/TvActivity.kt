package com.lukesteuber.mandaza.tv

import android.os.Bundle
import android.view.KeyEvent
import android.view.WindowManager
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat

class TvActivity : ComponentActivity() {
    private lateinit var state: TvState
    private var chromeVisible: () -> Boolean = { true }
    private var setChromeVisible: (Boolean) -> Unit = {}
    private var regenerate: () -> Unit = {}
    private var cyclePalette: (Int) -> Unit = {}

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
            TvApp(
                state = state,
                onChromeBinding = { visible, setVisible, regen, palette ->
                    chromeVisible = visible
                    setChromeVisible = setVisible
                    regenerate = regen
                    cyclePalette = palette
                },
            )
        }
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        when (keyCode) {
            KeyEvent.KEYCODE_DPAD_CENTER,
            KeyEvent.KEYCODE_ENTER,
            KeyEvent.KEYCODE_NUMPAD_ENTER,
            KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE,
            KeyEvent.KEYCODE_MEDIA_PLAY,
            -> {
                regenerate()
                return true
            }
            KeyEvent.KEYCODE_DPAD_LEFT -> {
                if (chromeVisible()) cyclePalette(-1)
                else setChromeVisible(true)
                return true
            }
            KeyEvent.KEYCODE_DPAD_RIGHT -> {
                if (chromeVisible()) cyclePalette(1)
                else setChromeVisible(true)
                return true
            }
            KeyEvent.KEYCODE_DPAD_UP,
            KeyEvent.KEYCODE_DPAD_DOWN,
            -> {
                if (!chromeVisible()) {
                    setChromeVisible(true)
                    return true
                }
            }
            KeyEvent.KEYCODE_BACK,
            KeyEvent.KEYCODE_ESCAPE,
            -> {
                // Toggle chrome instead of finishing when ambient — living-room recovery.
                setChromeVisible(!chromeVisible())
                return true
            }
        }
        return super.onKeyDown(keyCode, event)
    }
}
