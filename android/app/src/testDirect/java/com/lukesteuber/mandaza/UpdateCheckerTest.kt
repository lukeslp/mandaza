package com.lukesteuber.mandaza

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class UpdateCheckerTest {
    @Test fun directUpdatesAreEnabled() {
        assertTrue(UpdateChecker.enabled)
    }

    @Test fun newerSemanticVersionIsDetected() {
        assertTrue(UpdateChecker.isNewerVersion("1.4", "1.3-debug"))
        assertTrue(UpdateChecker.isNewerVersion("2.0.0", "1.99.99"))
    }

    @Test fun equalOrOlderVersionIsIgnored() {
        assertFalse(UpdateChecker.isNewerVersion("1.3-debug", "1.3-debug"))
        assertFalse(UpdateChecker.isNewerVersion("1.2.9", "1.3"))
    }
}
