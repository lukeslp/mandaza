package com.lukesteuber.mandaza

import org.junit.Assert.assertFalse
import org.junit.Test

class UpdateCheckerTest {
    @Test fun amazonUpdatesAreStoreManaged() {
        assertFalse(UpdateChecker.enabled)
    }
}
