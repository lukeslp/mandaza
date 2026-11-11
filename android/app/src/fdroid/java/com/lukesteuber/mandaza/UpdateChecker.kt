package com.lukesteuber.mandaza

import android.content.Context

data class AvailableUpdate(val version: String, val downloadPage: String)

/** F-Droid manages updates; this variant never queries the direct catalog. */
object UpdateChecker {
    const val enabled = false

    @Suppress("UNUSED_PARAMETER")
    suspend fun checkIfNeeded(context: Context): AvailableUpdate? = null
}
