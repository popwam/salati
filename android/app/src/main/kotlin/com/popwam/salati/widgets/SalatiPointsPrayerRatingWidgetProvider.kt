package com.popwam.salati.widgets

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.widget.RemoteViews
import androidx.core.content.ContextCompat
import com.popwam.salati.R

class SalatiPointsPrayerRatingWidgetProvider : AppWidgetProvider() {
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
        val views = RemoteViews(context.packageName, R.layout.widget_points_prayer_rating)
        val points = prefs.getString("points_rating_points", "0").orEmpty()
        val numericPoints = points.trim().removePrefix("+").toDoubleOrNull() ?: 0.0
        val accent = when {
            numericPoints < 0 -> R.color.widget_danger
            numericPoints >= 30 -> R.color.widget_ok
            else -> R.color.widget_warning
        }

        views.setTextViewText(R.id.points_widget_score, points.ifBlank { "0" })
        views.setInt(R.id.points_widget_score, "setTextColor", ContextCompat.getColor(context, accent))

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

    companion object {
        fun updateAll(context: Context): Boolean {
            val manager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, SalatiPointsPrayerRatingWidgetProvider::class.java)
            val ids = manager.getAppWidgetIds(component)
            if (ids.isEmpty()) return false
            val provider = SalatiPointsPrayerRatingWidgetProvider()

            for (id in ids) {
                provider.updateWidget(context, manager, id)
            }
            return true
        }
    }
}
