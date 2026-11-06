package com.lukesteuber.mandaza

import android.Manifest
import android.content.pm.PackageManager
import android.graphics.BitmapFactory
import android.graphics.Bitmap
import android.provider.MediaStore
import android.provider.Settings
import androidx.activity.compose.setContent
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.graphics.asAndroidBitmap
import androidx.compose.ui.test.assertHasClickAction
import androidx.compose.ui.test.assertHeightIsAtLeast
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsSelected
import androidx.compose.ui.test.assertIsFocused
import androidx.compose.ui.test.assertIsOn
import androidx.compose.ui.test.captureToImage
import android.view.KeyEvent
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.junit4.accessibility.enableAccessibilityChecks
import androidx.compose.ui.test.ExperimentalTestApi
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.hasScrollAction
import androidx.compose.ui.test.hasAnyDescendant
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.test.swipeUp
import androidx.compose.ui.test.hasScrollToIndexAction
import androidx.compose.ui.test.performScrollToIndex
import androidx.compose.ui.unit.dp
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import java.util.concurrent.atomic.AtomicReference

/** Run only on a disposable fixture: -e allowSyntheticDataReset true. */
@RunWith(AndroidJUnit4::class)
@OptIn(ExperimentalTestApi::class)
class FdroidAcceptanceTest {
    @get:Rule val compose = createAndroidComposeRule<MainActivity>()
    private val context get() = InstrumentationRegistry.getInstrumentation().targetContext

    @Before fun syntheticFixture() {
        assumeTrue(InstrumentationRegistry.getArguments().getString("allowSyntheticDataReset") == "true")
        check(context.packageName.endsWith(".debug")) { "Never reset a release installation" }
        // A previous native keyboard test can leave the window in keyboard
        // mode. Each touch fixture starts as a fresh touchscreen interaction.
        InstrumentationRegistry.getInstrumentation().setInTouchMode(true)
        // The artwork intentionally animates continuously; advance it explicitly.
        compose.mainClock.autoAdvance = false
        if (android.os.Build.VERSION.SDK_INT >= 34) compose.enableAccessibilityChecks()
        context.getSharedPreferences("mandaza", 0).edit().clear().commit()
        recreateFixture()
        settle()
        compose.waitForIdle()
    }

    private fun recreateFixture() {
        compose.activityRule.scenario.recreate()
        // Keep this test window awake during physical-device runs. The flag
        // ends with the activity; the phone's display settings stay unchanged.
        compose.activityRule.scenario.onActivity {
            it.window.addFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
    }
    private fun settle() {
        // Let measured sheet anchors settle before advancing their transition.
        repeat(3) { compose.mainClock.advanceTimeBy(500); compose.waitForIdle() }
    }
    private fun click(text: String) { compose.onNodeWithText(text).performClick(); settle() }
    private fun capture(name: String) {
        val image = checkNotNull(InstrumentationRegistry.getInstrumentation().uiAutomation.takeScreenshot())
        val directory = checkNotNull(context.getExternalFilesDir("fdroid-evidence"))
        java.io.File(directory, "$name.png").outputStream().use {
            check(image.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, it))
        }
        image.recycle()
    }
    private fun scrollToText(text: String) {
        repeat(12) {
            if (runCatching { compose.onNodeWithText(text).assertIsDisplayed() }.isSuccess) return
            compose.onNode(hasScrollAction() and hasAnyDescendant(hasText(text)))
                .performTouchInput { swipeUp(durationMillis = 2000) }
            settle()
        }
        compose.onNodeWithText(text).assertIsDisplayed()
    }

    @Test fun generatedPatternAndFavoriteSurviveRecreation() {
        compose.onNodeWithContentDescription("Mandaza canvas").assertHasClickAction().performClick()
        settle()
        val generated = MandazaAppState(context)
        val firstSeed = generated.history.first().seed
        val secondSeed = generated.seed
        assertNotEquals(firstSeed, secondSeed)
        click("Favorite")
        compose.onNodeWithText("Saved", substring = false).assertIsDisplayed()
        capture("01-live-canvas")
        recreateFixture()
        settle()
        compose.waitForIdle()
        compose.onNodeWithText("Saved", substring = false).assertIsDisplayed()
        val restored = MandazaAppState(context)
        assertEquals(secondSeed, restored.seed)
        assertTrue(restored.isFavorite())
        click("History")
        compose.onNodeWithText("Previous").assertIsDisplayed()
        compose.onNodeWithText(firstSeed.take(13)).performClick()
        settle()
        assertEquals(firstSeed, MandazaAppState(context).seed)
    }

    @Test fun zenHasReachableExitAndMicrophoneStartsOff() {
        assertFalse(MandazaAppState(context).musicResponsive)
        assertNotEquals(PackageManager.PERMISSION_GRANTED, context.checkSelfPermission(Manifest.permission.RECORD_AUDIO))
        click("Zen")
        capture("02-zen-clock")
        compose.onNodeWithContentDescription("Exit Zen")
            .assertIsDisplayed().assertHeightIsAtLeast(48.dp).performClick()
        settle()
        compose.onNodeWithText("Tune").assertIsDisplayed()
        assertFalse(MandazaAppState(context).musicResponsive)
        assertNotEquals(PackageManager.PERMISSION_GRANTED, context.checkSelfPermission(Manifest.permission.RECORD_AUDIO))
    }

    @Test fun selectedPaletteIsExposedWithoutRelyingOnColor() {
        click("Tune")
        compose.onNodeWithText("Aurora").assertIsSelected()
        capture("03-tune")
        click("Sunset")
        compose.onNodeWithText("Sunset").assertIsSelected()
        capture("04-selected-palette")
        // Palette selection persists immediately, including when a sheet is open.
        recreateFixture()
        settle()
        compose.waitForIdle()
        click("Tune")
        compose.onNodeWithText("Sunset").assertIsSelected()
    }

    @Test fun systemReducedMotionUpdatesLiveAndKeepsDeliberateGeneration() {
        val key = Settings.Global.ANIMATOR_DURATION_SCALE
        val original = Settings.Global.getString(context.contentResolver, key)
        val observed = AtomicReference<Boolean?>(null)
        fun scale(value: String?) {
            val command = if (value == null) "settings delete global $key"
            else "settings put global $key ${value.toFloat()}"
            val fd = InstrumentationRegistry.getInstrumentation().uiAutomation.executeShellCommand(command)
            android.os.ParcelFileDescriptor.AutoCloseInputStream(fd).use { it.readBytes() }
        }
        fun canvas(): Bitmap = compose.onNodeWithContentDescription("Mandaza canvas")
            .captureToImage().asAndroidBitmap().copy(Bitmap.Config.ARGB_8888, false)
        try {
            scale("0")
            compose.activityRule.scenario.onActivity { activity ->
                activity.setContent {
                    val reduced = rememberReducedMotion()
                    val fixtureState = remember { MandazaAppState(context) }
                    SideEffect { observed.set(reduced) }
                    MandazaApp(fixtureState, activity)
                }
            }
            compose.waitUntil(10_000) {
                compose.mainClock.advanceTimeByFrame()
                observed.get() == true
            }
            settle()
            // Wait for asynchronous geometry, rather than comparing two blank canvases.
            compose.waitUntil(10_000) {
                compose.mainClock.advanceTimeByFrame()
                val image = canvas()
                val ground = image.getPixel(0, 0)
                var ink = 0
                for (y in 0 until image.height step 8) {
                    for (x in 0 until image.width step 8) if (image.getPixel(x, y) != ground) ink++
                }
                image.recycle()
                ink > 50
            }
            val still = canvas()
            compose.mainClock.advanceTimeBy(30_000)
            compose.waitForIdle()
            val later = canvas()
            assertTrue("Reduced-motion artwork must remain still", still.sameAs(later))
            later.recycle()
            compose.onNodeWithContentDescription("Mandaza canvas").performClick()
            settle()
            compose.waitUntil(10_000) {
                compose.mainClock.advanceTimeByFrame()
                val generated = canvas()
                val changed = !still.sameAs(generated)
                generated.recycle()
                changed
            }
            still.recycle()

            scale("1")
            compose.waitUntil(10_000) {
                compose.mainClock.advanceTimeByFrame()
                observed.get() == false
            }
            settle()
            val moving = canvas()
            compose.mainClock.advanceTimeBy(5_000)
            compose.waitForIdle()
            val animated = canvas()
            assertFalse("Restoring animations must restore artwork motion", moving.sameAs(animated))
            moving.recycle()
            animated.recycle()
        } finally {
            scale(original)
        }
    }

    @Test fun paperZenExitRemainsReachableAtLargeText() {
        val key = Settings.System.FONT_SCALE
        val original = Settings.System.getString(context.contentResolver, key)
        fun scale(value: String?) {
            val command = if (value == null) "settings delete system $key"
            else "settings put system $key ${value.toFloat()}"
            val fd = InstrumentationRegistry.getInstrumentation().uiAutomation.executeShellCommand(command)
            android.os.ParcelFileDescriptor.AutoCloseInputStream(fd).use { it.readBytes() }
        }
        try {
            scale("2")
            compose.waitUntil(10_000) {
                compose.mainClock.advanceTimeByFrame()
                context.resources.configuration.fontScale >= 1.99f
            }
            for (form in listOf("digital", "stacked", "editorial")) {
                compose.activityRule.scenario.onActivity {
                    MandazaAppState(context).apply {
                        paperTheme = true
                        zenMode = true
                        showClock = true
                        showDate = true
                        clockForm = form
                        persist()
                    }
                }
                recreateFixture()
                settle()
                capture("paper-large-$form")
                compose.onNodeWithContentDescription("Exit Zen")
                    .assertIsDisplayed().assertHeightIsAtLeast(48.dp).performClick()
                settle()
                compose.onNodeWithText("Tune").assertIsDisplayed()
            }
        } finally {
            scale(original)
        }
    }

    @Test fun keyboardCanGenerateNavigateAndOpenSettings() {
        fun key(code: Int) { InstrumentationRegistry.getInstrumentation().sendKeyDownUpSync(code); settle() }
        fun tab() = key(KeyEvent.KEYCODE_TAB)
        var canvasFocused = false
        for (attempt in 0 until 8) {
            tab()
            if (runCatching { compose.onNodeWithContentDescription("Mandaza canvas").assertIsFocused() }.isSuccess) {
                canvasFocused = true
                break
            }
        }
        assertTrue("Canvas must be reachable with Tab", canvasFocused)
        val before = MandazaAppState(context).seed
        key(KeyEvent.KEYCODE_ENTER)
        assertNotEquals(before, MandazaAppState(context).seed)
        val palette = com.lukesteuber.mandaza.core.MandazaPalettes.byId(MandazaAppState(context).paletteId).name
        for (label in listOf("History", "Favorite", "Zen", "Tune")) {
            tab()
            compose.onNodeWithText(label).assertIsFocused()
        }
        key(KeyEvent.KEYCODE_ENTER)
        compose.onNodeWithText(palette).assertIsSelected()
        capture("05-keyboard-settings")
    }

    @Test fun exportProducesPngInMediaStore() {
        val started = System.currentTimeMillis() / 1000
        click("Save")
        var imageId: Long? = null
        compose.waitUntil(20_000) {
            context.contentResolver.query(
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                arrayOf(MediaStore.Images.Media._ID),
                "${MediaStore.Images.Media.DISPLAY_NAME} LIKE ? AND ${MediaStore.Images.Media.DATE_ADDED} >= ?",
                arrayOf("Mandaza-%.png", started.toString()), null,
            )?.use { cursor -> if (cursor.moveToFirst()) imageId = cursor.getLong(0) }
            imageId != null
        }
        val uri = android.content.ContentUris.withAppendedId(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, imageId!!)
        val bitmap = context.contentResolver.openInputStream(uri).use { BitmapFactory.decodeStream(it) }
        checkNotNull(bitmap)
        assertEquals(1440, bitmap.width)
        assertEquals(2560, bitmap.height)
        bitmap.recycle()
    }

    @Test fun oldestHistoryEntryRemainsReachable() {
        repeat(9) {
            compose.onNodeWithContentDescription("Mandaza canvas").performClick()
            settle()
        }
        val oldest = MandazaAppState(context).history.last().seed
        click("History")
        // A deliberate drag avoids tapping merely to stop an active fling.
        compose.onNode(hasScrollToIndexAction()).performTouchInput { swipeUp(durationMillis = 2000) }
        settle()
        compose.onNode(hasScrollToIndexAction()).performScrollToIndex(MandazaAppState(context).history.size)
        settle()
        capture("history-after-scroll")
        compose.onNodeWithText(oldest.take(13)).assertIsDisplayed().performClick()
        settle()
        assertEquals(oldest, MandazaAppState(context).seed)
    }

    @Test fun optionalMicrophoneDenialLeavesAppUsable() {
        val automation = InstrumentationRegistry.getInstrumentation().uiAutomation
        // Repeat the fresh-install denial case rather than Android's later
        // automatic-denial path. This is only allowed by the fixture opt-in.
        val reset = automation.executeShellCommand(
            "pm clear-permission-flags ${context.packageName} android.permission.RECORD_AUDIO user-set user-fixed",
        )
        android.os.ParcelFileDescriptor.AutoCloseInputStream(reset).use { it.readBytes() }
        click("Tune")
        scrollToText("Zen mode")
        compose.onNodeWithContentDescription("Zen mode").performClick()
        settle()
        compose.onNodeWithContentDescription("Zen mode").assertIsOn()
        scrollToText("Music responsivity")
        compose.onNodeWithContentDescription("Music responsivity").performClick()
        settle()
        automation.serviceInfo = automation.serviceInfo.apply {
            flags = flags or android.accessibilityservice.AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS
        }
        var deny: android.view.accessibility.AccessibilityNodeInfo? = null
        fun findDeny(node: android.view.accessibility.AccessibilityNodeInfo?): android.view.accessibility.AccessibilityNodeInfo? {
            if (node == null) return null
            if (node.viewIdResourceName?.endsWith(":id/permission_deny_button") == true) return node
            repeat(node.childCount) { index -> findDeny(node.getChild(index))?.let { return it } }
            return null
        }
        compose.waitUntil(10_000) { deny = findDeny(automation.rootInActiveWindow); deny != null }
        assertTrue(deny!!.performAction(android.view.accessibility.AccessibilityNodeInfo.ACTION_CLICK))
        settle()
        compose.onNodeWithText("Microphone unavailable").assertIsDisplayed()
        click("OK")
        assertNotEquals(PackageManager.PERMISSION_GRANTED, context.checkSelfPermission(Manifest.permission.RECORD_AUDIO))
    }
}
