package com.lukesteuber.mandaza

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.core.view.WindowCompat

class MainActivity : ComponentActivity() {
    private lateinit var state: MandazaAppState

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        WindowCompat.setDecorFitsSystemWindows(window, false)
        state = MandazaAppState(applicationContext)
        ReviewPromptTracker(applicationContext).recordSession()
        state.handleDeepLink(intent?.data)
        setContent { MandazaApp(state, this@MainActivity) }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        state.handleDeepLink(intent.data)
    }
}
