package com.popwam.salati.widgets

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.widget.RemoteViews
import androidx.core.content.ContextCompat
import com.popwam.salati.R
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class SalatiNextPrayerCountdownWidgetProvider : AppWidgetProvider() {
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
        val views = RemoteViews(context.packageName, R.layout.widget_next_prayer_countdown)
        var prayerName = prefs.getString("next_prayer_name", "الصلاة القادمة").orEmpty()
        var remaining = prefs.getString("next_prayer_remaining", "--").orEmpty()
        var remainingMinutes = prefs.getInt("next_prayer_remaining_minutes", 999)
        val prayerTimeMillis = prefs.getLong("next_prayer_time_millis", 0L)
        if (prayerName.isBlank() || remaining.isBlank() || remaining == "--") {
            val activeKey = prefs.getString("next_prayer_key", "").orEmpty()
            prayerName = prayerNameForKey(activeKey).ifBlank { "الصلاة القادمة" }
            remaining = "افتح التطبيق لتحديث الصلاة القادمة"
            remainingMinutes = 999
        }
        val urgencyColor = urgencyColor(context, remainingMinutes)
        val status = when {
            remainingMinutes < 10 -> "اقتربت جدًا"
            remainingMinutes <= 30 -> "اقترب الوقت"
            prayerTimeMillis > 0L -> "الوقت ${formatClock(prayerTimeMillis)}"
            else -> "متبقي"
        }

        views.setTextViewText(R.id.next_prayer_title, "الصلاة القادمة")
        views.setTextViewText(R.id.next_prayer_name, prayerName)
        views.setTextViewText(R.id.next_prayer_remaining, remaining)
        views.setTextViewText(R.id.next_prayer_status, status)
        views.setInt(R.id.next_prayer_remaining, "setTextColor", urgencyColor)
        views.setInt(R.id.next_prayer_status, "setTextColor", urgencyColor)
        views.setInt(R.id.next_prayer_signal, "setBackgroundColor", urgencyColor)

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

    private fun urgencyColor(context: Context, remainingMinutes: Int): Int {
        val colorRes = when {
            remainingMinutes < 10 -> R.color.widget_danger
            remainingMinutes <= 30 -> R.color.widget_warning
            else -> R.color.widget_ok
        }
        return ContextCompat.getColor(context, colorRes)
    }

    private fun prayerNameForKey(key: String): String {
        return when (key.lowercase()) {
            "fajr" -> "الفجر"
            "sunrise" -> "الشروق"
            "dhuhr" -> "الظهر"
            "asr" -> "العصر"
            "maghrib" -> "المغرب"
            "isha" -> "العشاء"
            else -> ""
        }
    }

    private fun formatClock(value: Long): String {
        return SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date(value))
    }

    companion object {
        fun updateAll(context: Context): Boolean {
            val manager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, SalatiNextPrayerCountdownWidgetProvider::class.java)
            val ids = manager.getAppWidgetIds(component)
            if (ids.isEmpty()) return false
            val provider = SalatiNextPrayerCountdownWidgetProvider()

            for (id in ids) {
                provider.updateWidget(context, manager, id)
            }
            return true
        }
    }
}
