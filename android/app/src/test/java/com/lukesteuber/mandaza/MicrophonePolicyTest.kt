package com.lukesteuber.mandaza

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class MicrophonePolicyTest {
    @Test fun freshInstallDoesNotRequestMicrophoneWhenEnteringZen() {
        assertFalse(
            shouldRequestMicrophone(
                appInForeground = true,
                zenMode = true,
                musicResponsive = DEFAULT_MUSIC_RESPONSIVE,
                microphoneGranted = false,
            )
        )
    }

    @Test fun explicitMusicResponsivityRequestsMicrophoneOnlyInForegroundZen() {
        assertTrue(shouldRequestMicrophone(true, true, true, false))
        assertFalse(shouldRequestMicrophone(true, false, true, false))
        assertFalse(shouldRequestMicrophone(false, true, true, false))
        assertFalse(shouldRequestMicrophone(true, true, true, true))
    }
}
