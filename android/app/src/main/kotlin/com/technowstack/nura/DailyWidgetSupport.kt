package com.technowstack.nura

import java.io.File
import java.time.LocalDate

enum class DailyKind(val key: String) { AYAH("ayah"), HADITH("hadith") }

sealed interface DailyWidgetState {
    /** [link] null = just open the app; [description] null = use the widget label. */
    data class Show(val imagePath: String, val link: String?, val description: String?) : DailyWidgetState

    /** The app has no daily ayah at all, so the Flutter side wrote no ayah entries. */
    data object NoAyahAvailable : DailyWidgetState

    /** Today's entry is missing or unusable (app not opened for more than 7 days). */
    data object Stale : DailyWidgetState
}

/** Which bitmaps fit into one RemoteViews update. */
enum class BitmapPlan { BOTH, CURRENT_ONLY, NONE }

/**
 * Pure selection logic for the daily widgets (no Android classes, unit-tested on the JVM).
 *
 * Reads the contract written by the Dart HomeWidgetService: key
 * `daily_<kind>_<yyyy-MM-dd>_<light|dark>_<4x2|4x3>` holding `{"image": "<png path>", "link": "nura://...", "description": "<TalkBack text, optional>"}`.
 */
object DailyWidgetSupport {
    /**
     * Widgets at least this tall (dp) use the 4x3 image (rendered at 320x240 dp; 4x2 is 320x152).
     * Launcher cells give about 110 dp for 2 rows and 180 dp for 3 rows (70n - 30).
     */
    const val TALL_MIN_HEIGHT_DP = 150

    fun sizeTag(heightDp: Int) = if (heightDp >= TALL_MIN_HEIGHT_DP) "4x3" else "4x2"

    /** Where the Flutter side reads the size a widget actually has, or null when unknown. */
    fun sizeEntry(kind: DailyKind, widthDp: Int, heightDp: Int): Pair<String, String>? =
        if (widthDp <= 0 || heightDp <= 0) {
            null
        } else {
            "widget_size_${kind.key}_${sizeTag(heightDp)}" to "${widthDp}x$heightDp"
        }

    fun select(
        keys: Collection<String>,
        read: (String) -> String?,
        date: LocalDate,
        kind: DailyKind,
        dark: Boolean,
        heightDp: Int,
        fileExists: (String) -> Boolean = { File(it).isFile },
    ): DailyWidgetState {
        val prefix = "daily_${kind.key}_"
        if (kind == DailyKind.AYAH && keys.none { it.startsWith(prefix) }) {
            return DailyWidgetState.NoAyahAvailable
        }
        // LocalDate.toString() is ISO yyyy-MM-dd, matching the Dart side.
        val key = "$prefix${date}_${if (dark) "dark" else "light"}_${sizeTag(heightDp)}"
        val raw = read(key)?.trim() ?: return DailyWidgetState.Stale
        if (!raw.startsWith("{") || !raw.endsWith("}")) return DailyWidgetState.Stale
        val image = jsonString(raw, "image")
        val link = jsonString(raw, "link")?.takeIf { it.isNotEmpty() }
        if (image.isNullOrEmpty() || (link != null && !link.startsWith("nura://")) || !fileExists(image)) {
            return DailyWidgetState.Stale
        }
        return DailyWidgetState.Show(image, link, jsonString(raw, "description")?.takeIf { it.isNotEmpty() })
    }

    /**
     * [budget] is the RemoteViews bitmap limit (6 x screen width x screen height bytes); only half
     * of it is used as a safety margin. Falls back to the current theme's bitmap, then to none.
     */
    fun bitmapPlan(lightBytes: Long, darkBytes: Long, night: Boolean, budget: Long): BitmapPlan {
        val limit = budget / 2
        return when {
            lightBytes + darkBytes <= limit -> BitmapPlan.BOTH
            (if (night) darkBytes else lightBytes) <= limit -> BitmapPlan.CURRENT_ONLY
            else -> BitmapPlan.NONE
        }
    }

    // shortcut: flat object of string fields only (what the Dart side writes); org.json is unavailable in JVM tests.
    private fun jsonString(json: String, field: String): String? {
        val match = Regex("\"$field\"\\s*:\\s*\"((?:[^\"\\\\]|\\\\.)*)\"").find(json) ?: return null
        return unescape(match.groupValues[1])
    }

    private fun unescape(s: String): String? {
        val out = StringBuilder(s.length)
        var i = 0
        while (i < s.length) {
            val c = s[i++]
            if (c != '\\') {
                out.append(c)
                continue
            }
            when (val e = s[i++]) {
                '"', '\\', '/' -> out.append(e)
                'b' -> out.append('\b')
                'f' -> out.append('\u000C')
                'n' -> out.append('\n')
                'r' -> out.append('\r')
                't' -> out.append('\t')
                'u' -> out.append(s.substring(i, minOf(i + 4, s.length)).toIntOrNull(16)?.toChar() ?: return null).also { i += 4 }
                else -> return null
            }
        }
        return out.toString()
    }
}
