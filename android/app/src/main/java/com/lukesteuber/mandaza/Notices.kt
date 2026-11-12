package com.lukesteuber.mandaza

import android.content.Context
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalViewConfiguration
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

internal const val NOTICES_ASSET_DIRECTORY = "licenses"
internal const val NOTICES_SUMMARY_FILE = "THIRD_PARTY_NOTICES.md"

internal data class NoticeBlock(val text: String, val isHeading: Boolean)

/** The summary comes first, then every license text by file name. */
internal fun orderNoticeFiles(names: List<String>): List<String> =
    names.filter { it == NOTICES_SUMMARY_FILE } + names.filter { it != NOTICES_SUMMARY_FILE }.sortedBy { it.lowercase() }

private val listItemStart = Regex("""^(-|\*|\([0-9a-zA-Z]+\)|[0-9]+\.)\s.*""")

/**
 * Split a notice into paragraphs so a long license scrolls as a lazy list, not one huge text node.
 * The files are hard-wrapped for an 80-column page; rejoin those lines so they wrap to the screen.
 * List items keep their own lines. Markdown section marks become headings. No words are dropped.
 */
internal fun noticeBlocks(fileName: String, content: String): List<NoticeBlock> =
    listOf(NoticeBlock(fileName, isHeading = true)) + content.replace("\r\n", "\n")
        .split(Regex("\n[ \t]*\n"))
        .filter { it.isNotBlank() }
        .map { paragraph ->
            val lines = paragraph.lines().map { it.trim() }.filter { it.isNotEmpty() }
            if (lines.size == 1 && lines[0].startsWith("#")) {
                NoticeBlock(lines[0].trimStart('#').trim(), isHeading = true)
            } else {
                val text = StringBuilder()
                lines.forEachIndexed { index, line ->
                    if (index > 0) text.append(if (listItemStart.matches(line)) '\n' else ' ')
                    text.append(line)
                }
                NoticeBlock(text.toString(), isHeading = false)
            }
        }

private fun loadNotices(context: Context): List<NoticeBlock> {
    val assets = context.assets
    val names = assets.list(NOTICES_ASSET_DIRECTORY)?.toList().orEmpty()
    return orderNoticeFiles(names).flatMap { name ->
        val text = assets.open("$NOTICES_ASSET_DIRECTORY/$name").bufferedReader().use { it.readText() }
        noticeBlocks(name, text)
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun NoticesSheet(onDismiss: () -> Unit) {
    val context = LocalContext.current
    val blocks by produceState<List<NoticeBlock>?>(initialValue = null) {
        value = withContext(Dispatchers.IO) { runCatching { loadNotices(context) }.getOrDefault(emptyList()) }
    }
    val version = runCatching {
        context.packageManager.getPackageInfo(context.packageName, 0).versionName
    }.getOrNull().orEmpty()
    val muted = Color(0xFF9AA5B4)
    ModalBottomSheet(
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        contentWindowInsets = { WindowInsets.safeDrawing },
        onDismissRequest = onDismiss,
        containerColor = Color(0xFF0D1018),
        contentColor = Color(0xFFF5F0E8),
        dragHandle = { MandazaDragHandle() },
    ) {
        Spacer(Modifier.height(LocalViewConfiguration.current.minimumTouchTargetSize.height / 2))
        LazyColumn(
            Modifier.fillMaxWidth(),
            contentPadding = PaddingValues(horizontal = 20.dp, vertical = 10.dp),
        ) {
            item {
                Text(
                    "Open-source notices",
                    style = MaterialTheme.typography.headlineSmall,
                    modifier = Modifier.semantics { heading() },
                )
            }
            if (version.isNotBlank()) item {
                Text("Mandaza $version", color = muted, style = MaterialTheme.typography.bodySmall,
                    modifier = Modifier.padding(top = 4.dp))
            }
            when (val loaded = blocks) {
                null -> Unit
                else -> if (loaded.isEmpty()) item {
                    Text("The notices could not be read.", color = muted, modifier = Modifier.padding(top = 16.dp))
                } else items(loaded) { block ->
                    if (block.isHeading) Text(
                        block.text,
                        color = Color(0xFF48BFE3),
                        style = MaterialTheme.typography.titleSmall,
                        modifier = Modifier.padding(top = 24.dp).semantics { heading() },
                    ) else Text(
                        block.text,
                        style = MaterialTheme.typography.bodySmall,
                        modifier = Modifier.padding(top = 10.dp),
                    )
                }
            }
            item { Spacer(Modifier.height(36.dp)) }
        }
    }
}
