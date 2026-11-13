package com.lukesteuber.mandaza

/** Align display changes to wall-clock boundaries, with no zero-delay loop. */
internal fun millisUntilNextClockTick(nowMillis: Long, showSeconds: Boolean): Long {
    val interval = if (showSeconds) 1_000L else 60_000L
    return interval - nowMillis % interval
}

/** Follow the device's 12- or 24-hour setting. The 12-hour form has no AM/PM mark, as before. */
internal fun clockPattern(is24Hour: Boolean, showSeconds: Boolean): String =
    (if (is24Hour) "H:mm" else "h:mm") + if (showSeconds) ":ss" else ""
