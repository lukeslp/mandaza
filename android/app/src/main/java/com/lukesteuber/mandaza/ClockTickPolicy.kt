package com.lukesteuber.mandaza

/** Align display changes to wall-clock boundaries, with no zero-delay loop. */
internal fun millisUntilNextClockTick(nowMillis: Long, showSeconds: Boolean): Long {
    val interval = if (showSeconds) 1_000L else 60_000L
    return interval - nowMillis % interval
}
