package com.popwam.salati.widgets

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.widget.RemoteViews
import androidx.core.content.ContextCompat
import com.popwam.salati.R

class SalatiTodayPrayerTimesWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

    private fun updateWidget(
        context: Context,
        manager: AppWidgetManager,
        appWidgetId: Int,
    ) {
        val prefs = context.getSharedPreferences(SalatiWidgetsBridge.PREFS_NAME, Context.MODE_PRIVATE)
        val views = RemoteViews(context.packageName, R.layout.widget_today_prayer_times_strip)
        val activeKey = prefs.getString("prayer_active_key", "").orEmpty()

        bindPrayer(views, context, R.id.prayer_fajr, "fajr", "الفجر", prefs.getString("prayer_fajr", "--:--"), activeKey)
        bindPrayer(views, context, R.id.prayer_sunrise, "sunrise", "الشروق", prefs.getString("prayer_sunrise", "--:--"), activeKey)
        bindPrayer(views, context, R.id.prayer_dhuhr, "dhuhr", "الظهر", prefs.getString("prayer_dhuhr", "--:--"), activeKey)
        bindPrayer(views, context, R.id.prayer_asr, "asr", "العصر", prefs.getString("prayer_asr", "--:--"), activeKey)
        bindPrayer(views, context, R.id.prayer_maghrib, "maghrib", "المغرب", prefs.getString("prayer_maghrib", "--:--"), activeKey)
        bindPrayer(views, context, R.id.prayer_isha, "isha", "العشاء", prefs.getString("prayer_isha", "--:--"), activeKey)

        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        if (launchIntent != null) {
            val pendingIntent = PendingIntent.getActivity(
                context,
                appWidgetId,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            views.setOnClickPendingIntent(R.id.salati_widget_root, pendingIntent)
        }

        manager.updateAppWidget(appWidgetId, views)
    }

    private fun bindPrayer(
        views: RemoteViews,
        context: Context,
        viewId: Int,
        key: String,
        label: String,
        time: String?,
        activeKey: String,
    ) {
        val isActive = key == activeKey
        views.setTextViewText(viewId, "$label\n${format12Hour(time)}")
        views.setInt(
            viewId,
            "setBackgroundResource",
            if (isActive) R.drawable.widget_prayer_active_pill else R.drawable.widget_prayer_idle_pill,
        )
        views.setInt(
            viewId,
            "setTextColor",
            ContextCompat.getColor(context, if (isActive) R.color.widget_ok else R.color.widget_text),
        )
    }

    private fun format12Hour(value: String?): String {
        val parts = value?.trim()?.split(":") ?: return "--:--"
        if (parts.size < 2) return value.ifBlank { "--:--" }

        val hour = parts[0].toIntOrNull() ?: return value
        val minute = parts[1].take(2).toIntOrNull() ?: return value
        val suffix = if (hour < 12) "ص" else "م"
        val hour12 = when (val normalized = hour % 12) {
            0 -> 12
            else -> normalized
        }
        return "$hour12:${minute.toString().padStart(2, '0')} $suffix"
    }

    companion object {
        fun updateAll(context: Context): Boolean {
            val manager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, SalatiTodayPrayerTimesWidgetProvider::class.java)
            val ids = manager.getAppWidgetIds(component)
            if (ids.isEmpty()) return false
            val provider = SalatiTodayPrayerTimesWidgetProvider()

            for (id in ids) {
                provider.updateWidget(context, manager, id)
            }
            return true
        }
    }
}
