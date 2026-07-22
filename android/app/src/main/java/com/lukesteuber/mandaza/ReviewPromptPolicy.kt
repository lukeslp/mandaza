package com.lukesteuber.mandaza

import android.content.Context
import androidx.core.content.edit

internal data class ReviewPromptState(
    val firstUseAt: Long,
    val sessionCount: Int,
    val successfulExportCount: Int,
    val lastRequestAt: Long,
    val lastRequestedVersion: String?,
)

internal object ReviewPromptPolicy {
    const val minimumSessions = 3
    const val minimumSuccessfulExports = 2
    const val minimumUseAgeMillis = 7L * 24 * 60 * 60 * 1000
    const val requestCooldownMillis = 120L * 24 * 60 * 60 * 1000

    fun shouldRequest(state: ReviewPromptState, now: Long, appVersion: String): Boolean {
        if (appVersion.isBlank() || state.firstUseAt <= 0) return false
        if (state.sessionCount < minimumSessions) return false
        if (state.successfulExportCount < minimumSuccessfulExports) return false
        if (now - state.firstUseAt < minimumUseAgeMillis) return false
        if (state.lastRequestedVersion == appVersion) return false
        if (state.lastRequestAt > 0 && now - state.lastRequestAt < requestCooldownMillis) return false
        return true
    }
}

internal class ReviewPromptTracker(context: Context) {
    private val preferences = context.getSharedPreferences("review_prompt", Context.MODE_PRIVATE)

    fun recordSession(now: Long = System.currentTimeMillis()) {
        val lastSession = preferences.getLong(KEY_LAST_SESSION, 0)
        if (lastSession > 0 && now - lastSession < SESSION_SEPARATION_MILLIS) return
        preferences.edit {
            if (!preferences.contains(KEY_FIRST_USE)) putLong(KEY_FIRST_USE, now)
            putInt(KEY_SESSIONS, preferences.getInt(KEY_SESSIONS, 0) + 1)
            putLong(KEY_LAST_SESSION, now)
        }
    }

    fun recordSuccessfulExport() {
        preferences.edit {
            putInt(KEY_EXPORTS, preferences.getInt(KEY_EXPORTS, 0) + 1)
        }
    }

    fun shouldRequest(now: Long = System.currentTimeMillis(), appVersion: String): Boolean =
        ReviewPromptPolicy.shouldRequest(state(), now, appVersion)

    fun markRequest(now: Long = System.currentTimeMillis(), appVersion: String) {
        preferences.edit {
            putLong(KEY_LAST_REQUEST, now)
            putString(KEY_LAST_VERSION, appVersion)
        }
    }

    private fun state() = ReviewPromptState(
        firstUseAt = preferences.getLong(KEY_FIRST_USE, 0),
        sessionCount = preferences.getInt(KEY_SESSIONS, 0),
        successfulExportCount = preferences.getInt(KEY_EXPORTS, 0),
        lastRequestAt = preferences.getLong(KEY_LAST_REQUEST, 0),
        lastRequestedVersion = preferences.getString(KEY_LAST_VERSION, null),
    )

    private companion object {
        const val SESSION_SEPARATION_MILLIS = 6L * 60 * 60 * 1000
        const val KEY_FIRST_USE = "first_use"
        const val KEY_SESSIONS = "sessions"
        const val KEY_EXPORTS = "exports"
        const val KEY_LAST_SESSION = "last_session"
        const val KEY_LAST_REQUEST = "last_request"
        const val KEY_LAST_VERSION = "last_version"
    }
}
