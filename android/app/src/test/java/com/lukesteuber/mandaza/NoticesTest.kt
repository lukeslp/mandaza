package com.lukesteuber.mandaza

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

class NoticesTest {
    @Test fun summaryIsListedFirstThenLicensesByName() {
        assertEquals(
            listOf(NOTICES_SUMMARY_FILE, "Apache-2.0.txt", "kotlinx-coroutines-NOTICE.txt", "Mandaza-MIT.txt"),
            orderNoticeFiles(listOf("Mandaza-MIT.txt", "kotlinx-coroutines-NOTICE.txt", NOTICES_SUMMARY_FILE, "Apache-2.0.txt")),
        )
    }

    @Test fun noticeIsSplitIntoAHeadingAndParagraphs() {
        val blocks = noticeBlocks("Example.txt", "First line\nsame paragraph\n\n\r\nSecond paragraph\n")
        assertEquals(
            listOf(
                NoticeBlock("Example.txt", isHeading = true),
                NoticeBlock("First line\nsame paragraph", isHeading = false),
                NoticeBlock("Second paragraph", isHeading = false),
            ),
            blocks,
        )
    }

    /** Every flavor reads its notices from the shared assets; none may be flavor-only again. */
    @Test fun sharedAssetsCarryTheNoticesTheAppShows() {
        val directory = sequenceOf("src/main/assets/licenses", "app/src/main/assets/licenses")
            .map(::File).first { it.isDirectory }
        val names = directory.list().orEmpty().toList()
        for (required in listOf(
            NOTICES_SUMMARY_FILE, "Mandaza-MIT.txt", "Apache-2.0.txt", "Johannes-Baagoe-MIT.txt",
            "Dillon-Loops-MIT.txt", "Dillon-Controlled-Loops-MIT.txt", "GRC-Public-Domain.txt",
        )) assertTrue("$required is missing from shared assets", required in names)
        for (name in names) assertTrue("$name is empty", File(directory, name).readText().isNotBlank())
    }
}
