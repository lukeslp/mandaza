package com.lukesteuber.mandaza

import org.junit.Assert.assertFalse
import org.junit.Test

class UpdateCheckerTest {
    @Test fun updatesAreManagedByFdroid() {
        assertFalse(UpdateChecker.enabled)
    }
}
