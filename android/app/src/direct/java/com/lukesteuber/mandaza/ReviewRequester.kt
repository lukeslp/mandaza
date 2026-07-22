package com.lukesteuber.mandaza

import androidx.activity.ComponentActivity

/// Direct downloads have no Play Store review surface.
internal object ReviewRequester {
    fun recordSuccessfulExport(activity: ComponentActivity) = Unit
}
