package com.popwam.salati.widgets

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import com.popwam.salati.R

class SalatiQuickControlsWidgetProvider : AppWidgetProvider() {
    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)

        val prefs = context.getSharedPreferences(SalatiWidgetsBridge.PREFS_NAME, Context.MODE_PRIVATE)

        when (intent.action) {
            ACTION_TOGGLE_NOTIFICATIONS -> {
                val current = prefs.getBoolean("controls_notifications_loud", true)
                prefs.edit().putBoolean("controls_notifications_loud", !current).apply()
            }
            ACTION_TOGGLE_NEXT_ALERT -> {
                val current = prefs.getBoolean("controls_next_alert_enabled", true)
                prefs.edit().putBoolean("controls_next_alert_enabled", !current).apply()
            }
            ACTION_TOGGLE_TOUCH_LOCK -> {
                val current = prefs.getBoolean("controls_touch_lock_enabled", false)
                prefs.edit().putBoolean("controls_touch_lock_enabled", !current).apply()
            }
        }

        updateAll(context)
    }

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
        val notificationsLoud = prefs.getBoolean("controls_notifications_loud", true)
        val nextAlertEnabled = prefs.getBoolean("controls_next_alert_enabled", true)
        val touchLockEnabled = prefs.getBoolean("controls_touch_lock_enabled", false)
        val views = RemoteViews(context.packageName, R.layout.widget_quick_controls)

        views.setTextViewText(
            R.id.salati_widget_toggle_notifications,
            if (notificationsLoud) "الصوت" else "صامت",
        )
        views.setInt(
            R.id.salati_widget_toggle_notifications,
            "setBackgroundResource",
            if (notificationsLoud) R.drawable.widget_pill_on else R.drawable.widget_pill_off,
        )
        views.setTextViewText(
            R.id.salati_widget_toggle_next_alert,
            if (nextAlertEnabled) "تنبيه" else "إيقاف",
        )
        views.setInt(
            R.id.salati_widget_toggle_next_alert,
            "setBackgroundResource",
            if (nextAlertEnabled) R.drawable.widget_pill_on else R.drawable.widget_pill_off,
        )
        views.setTextViewText(
            R.id.salati_widget_toggle_touch_lock,
            if (touchLockEnabled) "قفل" else "فتح",
        )
        views.setInt(
            R.id.salati_widget_toggle_touch_lock,
            "setBackgroundResource",
            if (touchLockEnabled) R.drawable.widget_pill_on else R.drawable.widget_pill_off,
        )

        views.setOnClickPendingIntent(
            R.id.salati_widget_toggle_notifications,
            pending(context, appWidgetId + 10, ACTION_TOGGLE_NOTIFICATIONS),
        )
        views.setOnClickPendingIntent(
            R.id.salati_widget_toggle_next_alert,
            pending(context, appWidgetId + 20, ACTION_TOGGLE_NEXT_ALERT),
        )
        views.setOnClickPendingIntent(
            R.id.salati_widget_toggle_touch_lock,
            pending(context, appWidgetId + 30, ACTION_TOGGLE_TOUCH_LOCK),
        )

        manager.updateAppWidget(appWidgetId, views)
    }

    private fun pending(context: Context, requestCode: Int, action: String): PendingIntent {
        val intent = Intent(context, SalatiQuickControlsWidgetProvider::class.java).apply {
            this.action = action
        }

        return PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    companion object {
        const val ACTION_TOGGLE_NOTIFICATIONS = "com.popwam.salati.ACTION_TOGGLE_NOTIFICATIONS"
        const val ACTION_TOGGLE_NEXT_ALERT = "com.popwam.salati.ACTION_TOGGLE_NEXT_ALERT"
        const val ACTION_TOGGLE_TOUCH_LOCK = "com.popwam.salati.ACTION_TOGGLE_TOUCH_LOCK"

        fun updateAll(context: Context): Boolean {
            val manager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, SalatiQuickControlsWidgetProvider::class.java)
            val ids = manager.getAppWidgetIds(component)
            if (ids.isEmpty()) return false
            val provider = SalatiQuickControlsWidgetProvider()

            for (id in ids) {
                provider.updateWidget(context, manager, id)
            }
            return true
        }
    }
}
