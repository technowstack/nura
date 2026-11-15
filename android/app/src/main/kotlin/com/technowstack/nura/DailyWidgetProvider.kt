package com.technowstack.nura

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import es.antonborri.home_widget.HomeWidgetScheduler
import java.time.LocalDate
import java.time.ZoneId

/**
 * Shows today's PNG rendered by the Flutter side, or a fallback text. Both theme variants are set
 * and the layout picks one through values-night, so a theme switch needs no update.
 */
abstract class DailyWidgetProvider(private val kind: DailyKind, private val labelRes: Int) :
    HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val today = LocalDate.now()
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, buildViews(context, appWidgetManager, id, widgetData, today))
        }
        // ACTION_DATE_CHANGED is not delivered to manifest receivers on API 26+, so redraw just
        // after the next local midnight through the plugin's scheduler (re-armed on every update).
        val nextMidnight = today.plusDays(1).atStartOfDay(ZoneId.systemDefault()).toInstant().toEpochMilli()
        HomeWidgetScheduler.schedule(context, javaClass.name, listOf(nextMidnight + MIDNIGHT_DELAY_MS))
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        appWidgetManager.updateAppWidget(
            appWidgetId,
            buildViews(context, appWidgetManager, appWidgetId, HomeWidgetPlugin.getData(context), LocalDate.now()),
        )
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_DATE_CHANGED, Intent.ACTION_TIME_CHANGED, Intent.ACTION_TIMEZONE_CHANGED -> {
                val manager = AppWidgetManager.getInstance(context)
                val ids = manager.getAppWidgetIds(ComponentName(context, javaClass))
                if (ids.isNotEmpty()) onUpdate(context, manager, ids)
            }
            else -> super.onReceive(context, intent)
        }
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        HomeWidgetScheduler.cancel(context, javaClass.name)
    }

    private fun buildViews(
        context: Context,
        manager: AppWidgetManager,
        id: Int,
        data: SharedPreferences,
        today: LocalDate,
    ): RemoteViews {
        val options = manager.getAppWidgetOptions(id)
        val config = context.resources.configuration
        // Launchers report the real portrait height as MAX_HEIGHT and the landscape one as MIN_HEIGHT.
        val heightDp = options.getInt(
            if (config.orientation == Configuration.ORIENTATION_LANDSCAPE) {
                AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT
            } else {
                AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT
            },
        )
        val keys = data.all.keys
        fun pick(dark: Boolean) = DailyWidgetSupport.select(
            keys,
            { runCatching { data.getString(it, null) }.getOrNull() },
            today,
            kind,
            dark,
            heightDp,
        )
        val light = pick(false)
        val dark = pick(true)
        val lightBitmap = (light as? DailyWidgetState.Show)?.let { decode(it.imagePath) }
        val darkBitmap = (dark as? DailyWidgetState.Show)?.let { decode(it.imagePath) }

        val views = RemoteViews(context.packageName, R.layout.daily_widget)
        val link: String?
        if (lightBitmap != null && darkBitmap != null) {
            views.setImageViewBitmap(R.id.daily_widget_image_light, lightBitmap)
            views.setImageViewBitmap(R.id.daily_widget_image_dark, darkBitmap)
            views.setContentDescription(R.id.daily_widget_images, context.getString(labelRes))
            views.setViewVisibility(R.id.daily_widget_images, View.VISIBLE)
            views.setViewVisibility(R.id.daily_widget_fallback, View.GONE)
            val night = config.uiMode and Configuration.UI_MODE_NIGHT_MASK == Configuration.UI_MODE_NIGHT_YES
            link = ((if (night) dark else light) as DailyWidgetState.Show).link
        } else {
            val text = if (light == DailyWidgetState.NoAyahAvailable) {
                R.string.daily_widget_no_ayah
            } else {
                R.string.daily_widget_stale
            }
            views.setTextViewText(R.id.daily_widget_fallback, context.getString(text))
            views.setViewVisibility(R.id.daily_widget_images, View.GONE)
            views.setViewVisibility(R.id.daily_widget_fallback, View.VISIBLE)
            link = null
        }
        // One tap area; without a link the app just opens (Flutter receives an empty link).
        views.setOnClickPendingIntent(
            R.id.daily_widget_root,
            HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, link?.let(Uri::parse)),
        )
        return views
    }

    /** Missing, corrupt or oversized files yield null (fallback text), never a crash. */
    private fun decode(path: String): Bitmap? = try {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) {
            null
        } else {
            var sample = 1
            while (maxOf(bounds.outWidth, bounds.outHeight) / sample > MAX_IMAGE_PX) sample *= 2
            BitmapFactory.decodeFile(path, BitmapFactory.Options().apply { inSampleSize = sample })
        }
    } catch (e: OutOfMemoryError) {
        null
    } catch (e: Exception) {
        null
    }

    private companion object {
        const val MIDNIGHT_DELAY_MS = 5_000L

        // Keeps both variants within the RemoteViews bitmap budget (4x3 at 3.5x is 1120 px wide).
        const val MAX_IMAGE_PX = 1280
    }
}
