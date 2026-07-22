package com.lukesteuber.mandaza

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ReviewPromptPolicyTest {
    private val day = 24L * 60 * 60 * 1000

    @Test fun repeatUseAndExportsBecomeEligible() {
        val now = 2_000_000_000L
        val state = ReviewPromptState(
            firstUseAt = now - 8 * day,
            sessionCount = 3,
            successfulExportCount = 2,
            lastRequestAt = 0,
            lastRequestedVersion = null,
        )

        assertTrue(ReviewPromptPolicy.shouldRequest(state, now, "1.3"))
    }

    @Test fun firstWeekIsNeverEligible() {
        val now = 2_000_000_000L
        val state = ReviewPromptState(
            firstUseAt = now - 6 * day,
            sessionCount = 10,
            successfulExportCount = 10,
            lastRequestAt = 0,
            lastRequestedVersion = null,
        )

        assertFalse(ReviewPromptPolicy.shouldRequest(state, now, "1.3"))
    }

    @Test fun versionAndCooldownGuardsPreventRepeatedRequests() {
        val now = 2_000_000_000L
        val state = ReviewPromptState(
            firstUseAt = now - 400 * day,
            sessionCount = 10,
            successfulExportCount = 10,
            lastRequestAt = now - 30 * day,
            lastRequestedVersion = "1.2",
        )

        assertFalse(ReviewPromptPolicy.shouldRequest(state, now, "1.3"))
        assertFalse(ReviewPromptPolicy.shouldRequest(
            state.copy(lastRequestAt = now - 200 * day, lastRequestedVersion = "1.3"),
            now,
            "1.3",
        ))
    }
}
