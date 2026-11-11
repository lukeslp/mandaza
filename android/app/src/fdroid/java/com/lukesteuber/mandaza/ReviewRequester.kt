package com.lukesteuber.mandaza

import androidx.activity.ComponentActivity

/** The F-Droid build does not link or invoke Google Play's review service. */
internal object ReviewRequester {
    @Suppress("UNUSED_PARAMETER")
    fun recordSuccessfulExport(activity: ComponentActivity) = Unit
}
