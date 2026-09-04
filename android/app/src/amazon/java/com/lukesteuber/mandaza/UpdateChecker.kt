package com.lukesteuber.mandaza

import android.content.Context

data class AvailableUpdate(val version: String, val downloadPage: String)

/** Amazon owns updates for this distribution; no direct catalog is queried. */
object UpdateChecker {
    const val enabled = false

    @Suppress("UNUSED_PARAMETER")
    suspend fun checkIfNeeded(context: Context): AvailableUpdate? = null
}
