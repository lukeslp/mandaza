package com.lukesteuber.mandaza

import org.junit.Assert.assertFalse
import org.junit.Test

class UpdateCheckerTest {
    @Test fun directUpdatesAreDisabled() {
        assertFalse(UpdateChecker.enabled)
    }
}
