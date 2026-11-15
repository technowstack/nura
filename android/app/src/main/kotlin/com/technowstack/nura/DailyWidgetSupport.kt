package com.technowstack.nura

import java.io.File
import java.time.LocalDate

enum class DailyKind(val key: String) { AYAH("ayah"), HADITH("hadith") }

sealed interface DailyWidgetState {
    data class Show(val imagePath: String, val link: String) : DailyWidgetState

    /** The app has no daily ayah at all, so the Flutter side wrote no ayah entries. */
    data object NoAyahAvailable : DailyWidgetState

    /** Today's entry is missing or unusable (app not opened for more than 7 days). */
    data object Stale : DailyWidgetState
}

/**
 * Pure selection logic for the daily widgets (no Android classes, unit-tested on the JVM).
 *
 * Reads the contract written by the Dart HomeWidgetService: key
 * `daily_<kind>_<yyyy-MM-dd>_<light|dark>_<4x2|4x3>` holding `{"image": "<png path>", "link": "nura://..."}`.
 */
object DailyWidgetSupport {
    /** Widgets at least this tall (dp) use the 4x3 image (rendered at 320x240 dp; 4x2 is 320x152). */
    const val TALL_MIN_HEIGHT_DP = 200

    fun sizeTag(heightDp: Int) = if (heightDp >= TALL_MIN_HEIGHT_DP) "4x3" else "4x2"

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
        val link = jsonString(raw, "link")
        if (image.isNullOrEmpty() || link == null || !link.startsWith("nura://") || !fileExists(image)) {
            return DailyWidgetState.Stale
        }
        return DailyWidgetState.Show(image, link)
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
