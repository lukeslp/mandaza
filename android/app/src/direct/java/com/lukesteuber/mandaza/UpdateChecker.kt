package com.lukesteuber.mandaza

import android.content.Context
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import java.net.HttpURLConnection
import java.net.URL

data class AvailableUpdate(val version: String, val downloadPage: String)

object UpdateChecker {
    const val enabled = true
    private const val catalogUrl = "https://dr.eamer.dev/downloads/catalog.json"
    const val downloadPage = "https://dr.eamer.dev/downloads/apps/mandaza/"
    private const val preferencesName = "mandaza_update_check"
    private const val lastCheckKey = "last_check_ms"
    private const val checkIntervalMs = 24 * 60 * 60 * 1000L

    suspend fun checkIfNeeded(context: Context): AvailableUpdate? {
        val preferences = context.getSharedPreferences(preferencesName, Context.MODE_PRIVATE)
        val now = System.currentTimeMillis()
        if (now - preferences.getLong(lastCheckKey, 0) < checkIntervalMs) return null

        return withContext(Dispatchers.IO) {
            runCatching {
                val connection = URL(catalogUrl).openConnection() as HttpURLConnection
                connection.connectTimeout = 5_000
                connection.readTimeout = 5_000
                connection.setRequestProperty("Accept", "application/json")
                try {
                    val catalog = connection.inputStream.bufferedReader().use { it.readText() }
                    preferences.edit().putLong(lastCheckKey, now).apply()
                    findUpdate(catalog, installedVersion(context))
                } finally {
                    connection.disconnect()
                }
            }.getOrNull()
        }
    }

    internal fun findUpdate(catalog: String, installedVersion: String): AvailableUpdate? {
        val apps = JSONArray(catalog)
        val app = (0 until apps.length())
            .map { apps.getJSONObject(it) }
            .firstOrNull { it.optString("slug") == "mandaza" }
            ?: return null
        val distributions = app.getJSONArray("distributions")
        val android = (0 until distributions.length())
            .map { distributions.getJSONObject(it) }
            .firstOrNull { it.optString("platform") == "Android" }
            ?: return null
        val availableVersion = android.optString("version")
        return if (isNewerVersion(availableVersion, installedVersion)) {
            AvailableUpdate(availableVersion, downloadPage)
        } else null
    }

    internal fun isNewerVersion(available: String, installed: String): Boolean {
        fun parts(value: String) = value.substringBefore('-').split('.')
            .map { it.toIntOrNull() ?: 0 }
        val left = parts(available)
        val right = parts(installed)
        repeat(maxOf(left.size, right.size)) { index ->
            val comparison = left.getOrElse(index) { 0 }.compareTo(right.getOrElse(index) { 0 })
            if (comparison != 0) return comparison > 0
        }
        return false
    }

    private fun installedVersion(context: Context): String =
        context.packageManager.getPackageInfo(context.packageName, 0).versionName ?: "0"
}
