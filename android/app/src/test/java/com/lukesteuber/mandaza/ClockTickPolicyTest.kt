package com.lukesteuber.mandaza

import org.junit.Assert.assertEquals
import org.junit.Test

class ClockTickPolicyTest {
    @Test fun minuteClockRefreshesAtTheNextMinuteBoundary() {
        assertEquals(1L, millisUntilNextClockTick(119_999L, false))
    }

    @Test fun exactMinuteWaitsForTheFollowingMinuteWithoutSpinning() {
        assertEquals(60_000L, millisUntilNextClockTick(120_000L, false))
    }

    @Test fun secondsClockRefreshesAtTheNextSecondBoundary() {
        assertEquals(655L, millisUntilNextClockTick(12_345L, true))
    }

    @Test fun exactSecondWaitsForTheFollowingSecondWithoutSpinning() {
        assertEquals(1_000L, millisUntilNextClockTick(120_000L, true))
    }
}
