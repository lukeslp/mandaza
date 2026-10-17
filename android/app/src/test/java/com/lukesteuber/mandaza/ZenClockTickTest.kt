package com.lukesteuber.mandaza

import org.junit.Assert.assertEquals
import org.junit.Test

class ZenClockTickTest {
    private val minuteStart = 1_790_000_040_000L - Math.floorMod(1_790_000_040_000L, 60_000L)

    @Test fun minuteClockWakesJustAfterTheNextMinute() {
        val now = minuteStart + 42_500L
        val wake = now + millisUntilNextClockTick(now, showSeconds = false)
        assertEquals(minuteStart + 60_020L, wake)
    }

    @Test fun minuteClockOnABoundaryWaitsForTheFollowingMinute() {
        assertEquals(60_020L, millisUntilNextClockTick(minuteStart, showSeconds = false))
    }

    @Test fun secondsClockWakesJustAfterTheNextSecond() {
        val now = minuteStart + 42_500L
        val wake = now + millisUntilNextClockTick(now, showSeconds = true)
        assertEquals(minuteStart + 43_020L, wake)
    }
}
