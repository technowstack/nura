package com.technowstack.nura

import java.time.LocalDate
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class DailyWidgetSupportTest {
    private val today = LocalDate.of(2026, 11, 15)
    private val existing = mutableSetOf<String>()

    private fun entry(image: String, link: String) =
        """{"image":"$image","link":"$link"}""".also { existing += image }

    private fun select(
        store: Map<String, String>,
        kind: DailyKind,
        date: LocalDate = today,
        dark: Boolean = false,
        heightDp: Int = 110,
    ) = DailyWidgetSupport.select(store.keys, store::get, date, kind, dark, heightDp) { it in existing }

    @Test
    fun todayEntryPresentShowsImageAndLink() {
        val store = mapOf(
            "daily_hadith_2026-11-15_light_4x2" to entry("/data/w/h.png", "nura://hadith/bukhari/1"),
        )
        assertEquals(
            DailyWidgetState.Show("/data/w/h.png", "nura://hadith/bukhari/1", null),
            select(store, DailyKind.HADITH),
        )
    }

    @Test
    fun todayMissingButOtherDatesPresentIsStale() {
        val store = mapOf(
            "daily_hadith_2026-11-14_light_4x2" to entry("/a.png", "nura://hadith/bukhari/1"),
            "daily_ayah_2026-11-16_light_4x2" to entry("/b.png", "nura://ayah/94/6"),
        )
        assertEquals(DailyWidgetState.Stale, select(store, DailyKind.HADITH))
        assertEquals(DailyWidgetState.Stale, select(store, DailyKind.AYAH))
    }

    @Test
    fun picksThemeAndSizeVariant() {
        val store = mapOf(
            "daily_ayah_2026-11-15_light_4x2" to entry("/l2.png", "nura://ayah/1/1"),
            "daily_ayah_2026-11-15_light_4x3" to entry("/l3.png", "nura://ayah/1/1"),
            "daily_ayah_2026-11-15_dark_4x2" to entry("/d2.png", "nura://ayah/1/1"),
            "daily_ayah_2026-11-15_dark_4x3" to entry("/d3.png", "nura://ayah/1/1"),
        )
        fun path(dark: Boolean, h: Int) =
            (select(store, DailyKind.AYAH, dark = dark, heightDp = h) as DailyWidgetState.Show).imagePath
        assertEquals("/l2.png", path(false, 110))
        assertEquals("/l3.png", path(false, 180))
        assertEquals("/d2.png", path(true, 110))
        assertEquals("/d3.png", path(true, 180))
        assertEquals("/l2.png", path(false, 110))
        assertEquals("/l3.png", path(false, 180))
        assertEquals("/l2.png", path(false, 149))
        assertEquals("/l3.png", path(false, 150))
        assertEquals("/l3.png", path(false, 151))
        assertEquals("/l2.png", path(false, 0))
    }

    @Test
    fun noAyahEntriesAtAllIsNoAyahForAyahButStaleForHadith() {
        val store = mapOf(
            "daily_hadith_2026-11-14_light_4x2" to entry("/a.png", "nura://hadith/bukhari/1"),
            "daily_widget_updated" to "2026-11-14T06:00:00",
            "daily_widget_index" to "[]",
        )
        assertEquals(DailyWidgetState.NoAyahAvailable, select(store, DailyKind.AYAH))
        assertEquals(DailyWidgetState.Stale, select(store, DailyKind.HADITH))
        assertEquals(DailyWidgetState.NoAyahAvailable, select(emptyMap(), DailyKind.AYAH))
        assertEquals(DailyWidgetState.Stale, select(emptyMap(), DailyKind.HADITH))
    }

    @Test
    fun malformedOrUnusableEntriesAreStale() {
        existing += "/ok.png"
        val key = "daily_hadith_2026-11-15_light_4x2"
        listOf(
            "not json",
            """{"image":"/ok.png","link":"nura://hadith/bukhari/1"""",
            """{"image":"","link":"nura://hadith/bukhari/1"}""",
            """{"link":"nura://hadith/bukhari/1"}""",
            """{"image":"/missing.png","link":"nura://hadith/bukhari/1"}""",
            """{"image":"/ok.png","link":"https://evil.example"}""",
            "",
        ).forEach { raw ->
            assertEquals(raw, DailyWidgetState.Stale, select(mapOf(key to raw), DailyKind.HADITH))
        }
    }

    @Test
    fun unescapesJsonStrings() {
        existing += "/w/a\"b.png"
        val store = mapOf(
            "daily_hadith_2026-11-15_light_4x2" to
                """{ "link" : "nura:\/\/hadith\/abu-daud\/2" , "image" : "\/w\/a\"b.png" }""",
        )
        assertEquals(
            DailyWidgetState.Show("/w/a\"b.png", "nura://hadith/abu-daud/2", null),
            select(store, DailyKind.HADITH),
        )
    }

    @Test
    fun rollsOverAtLocalMidnight() {
        val store = mapOf(
            "daily_hadith_2026-12-31_light_4x2" to entry("/old.png", "nura://hadith/muslim/1"),
            "daily_hadith_2027-01-01_light_4x2" to entry("/new.png", "nura://hadith/muslim/2"),
        )
        assertEquals(
            "/old.png",
            (select(store, DailyKind.HADITH, LocalDate.of(2026, 12, 31)) as DailyWidgetState.Show).imagePath,
        )
        assertEquals(
            "/new.png",
            (select(store, DailyKind.HADITH, LocalDate.of(2027, 1, 1)) as DailyWidgetState.Show).imagePath,
        )
    }

    @Test
    fun emptyOrMissingLinkShowsImageWithoutLink() {
        existing += "/ok.png"
        val key = "daily_hadith_2026-11-15_light_4x2"
        listOf("""{"image":"/ok.png","link":""}""", """{"image":"/ok.png"}""").forEach { raw ->
            assertEquals(raw, DailyWidgetState.Show("/ok.png", null, null), select(mapOf(key to raw), DailyKind.HADITH))
        }
    }

    @Test
    fun readsOptionalDescription() {
        existing += "/ok.png"
        val key = "daily_hadith_2026-11-15_light_4x2"
        fun desc(raw: String) = (select(mapOf(key to raw), DailyKind.HADITH) as DailyWidgetState.Show).description
        assertEquals("HR. Bukhari No. 1", desc("""{"image":"/ok.png","link":"nura://hadith/bukhari/1","description":"HR. Bukhari No. 1"}"""))
        assertEquals(null, desc("""{"image":"/ok.png","link":"nura://hadith/bukhari/1"}"""))
        assertEquals(null, desc("""{"image":"/ok.png","link":"nura://hadith/bukhari/1","description":""}"""))
    }

    @Test
    fun bitmapPlanFitsWithinHalfTheBudget() {
        val budget = 1000L
        assertEquals(BitmapPlan.BOTH, DailyWidgetSupport.bitmapPlan(200, 300, night = false, budget = budget))
        assertEquals(BitmapPlan.BOTH, DailyWidgetSupport.bitmapPlan(250, 250, night = true, budget = budget))
        assertEquals(BitmapPlan.CURRENT_ONLY, DailyWidgetSupport.bitmapPlan(250, 251, night = false, budget = budget))
        assertEquals(BitmapPlan.CURRENT_ONLY, DailyWidgetSupport.bitmapPlan(500, 900, night = false, budget = budget))
        assertEquals(BitmapPlan.CURRENT_ONLY, DailyWidgetSupport.bitmapPlan(900, 500, night = true, budget = budget))
        assertEquals(BitmapPlan.NONE, DailyWidgetSupport.bitmapPlan(501, 100, night = false, budget = budget))
        assertEquals(BitmapPlan.NONE, DailyWidgetSupport.bitmapPlan(900, 900, night = true, budget = budget))
    }
    @Test
    fun sizeEntryNamesTheVariantByHeight() {
        assertEquals("widget_size_ayah_4x2" to "388x130", DailyWidgetSupport.sizeEntry(DailyKind.AYAH, 388, 130))
        assertEquals("widget_size_hadith_4x3" to "388x214", DailyWidgetSupport.sizeEntry(DailyKind.HADITH, 388, 214))
        assertNull(DailyWidgetSupport.sizeEntry(DailyKind.AYAH, 0, 130))
    }

}
