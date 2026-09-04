package com.lukesteuber.mandaza

import androidx.activity.ComponentActivity

/** The Amazon build does not link Google Play's review API. */
internal object ReviewRequester {
    @Suppress("UNUSED_PARAMETER")
    fun recordSuccessfulExport(activity: ComponentActivity) = Unit
}
