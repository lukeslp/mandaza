package com.lukesteuber.mandaza

internal fun shouldActivateAudio(
    appInForeground: Boolean,
    zenMode: Boolean,
    musicResponsive: Boolean,
): Boolean = appInForeground && zenMode && musicResponsive

internal fun shouldRequestMicrophone(
    appInForeground: Boolean,
    zenMode: Boolean,
    musicResponsive: Boolean,
    microphoneGranted: Boolean,
): Boolean = shouldActivateAudio(appInForeground, zenMode, musicResponsive) && !microphoneGranted
