package com.lukesteuber.mandaza

import androidx.activity.ComponentActivity
import androidx.lifecycle.Lifecycle
import com.google.android.play.core.review.ReviewManagerFactory

internal object ReviewRequester {
    fun recordSuccessfulExport(activity: ComponentActivity) {
        val tracker = ReviewPromptTracker(activity.applicationContext)
        val appVersion = activity.packageManager
            .getPackageInfo(activity.packageName, 0)
            .versionName
            .orEmpty()
        tracker.recordSuccessfulExport()
        if (!tracker.shouldRequest(appVersion = appVersion)) return

        val manager = ReviewManagerFactory.create(activity)
        manager.requestReviewFlow().addOnCompleteListener { request ->
            if (!request.isSuccessful ||
                activity.isFinishing ||
                !activity.lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED)) {
                return@addOnCompleteListener
            }
            tracker.markRequest(appVersion = appVersion)
            manager.launchReviewFlow(activity, request.result)
        }
    }
}
