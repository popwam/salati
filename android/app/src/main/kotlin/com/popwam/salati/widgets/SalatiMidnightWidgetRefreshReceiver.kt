package com.popwam.salati.widgets

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

class SalatiMidnightWidgetRefreshReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != ACTION_REFRESH) return

        promoteTomorrowPrayerTimes(context.applicationContext)
    }

    companion object {
        private const val ACTION_REFRESH = "com.popwam.salati.ACTION_MIDNIGHT_WIDGET_REFRESH"
        private const val REQUEST_CODE = 42024

        fun schedule(context: Context, triggerAtMillis: Long) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                REQUEST_CODE,
                Intent(context, SalatiMidnightWidgetRefreshReceiver::class.java).apply {
                    action = ACTION_REFRESH
                },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerAtMillis,
                    pendingIntent,
                )
            } else {
                alarmManager.setExact(
                    AlarmManager.RTC_WAKEUP,
                    triggerAtMillis,
                    pendingIntent,
                )
            }
        }

        fun promoteTomorrowPrayerTimes(context: Context) {
            val prefs = context.getSharedPreferences(SalatiWidgetsBridge.PREFS_NAME, Context.MODE_PRIVATE)
            val fajr = prefs.getString("tomorrow_prayer_fajr", "").orEmpty()
            if (fajr.isBlank() || fajr == "--:--") return

            prefs.edit()
                .putString("prayer_fajr", fajr)
                .putString("prayer_sunrise", prefs.getString("tomorrow_prayer_sunrise", "--:--"))
                .putString("prayer_dhuhr", prefs.getString("tomorrow_prayer_dhuhr", "--:--"))
                .putString("prayer_asr", prefs.getString("tomorrow_prayer_asr", "--:--"))
                .putString("prayer_maghrib", prefs.getString("tomorrow_prayer_maghrib", "--:--"))
                .putString("prayer_isha", prefs.getString("tomorrow_prayer_isha", "--:--"))
                .putString("prayer_active_key", prefs.getString("tomorrow_prayer_active_key", "fajr"))
                .putString("next_prayer_key", "fajr")
                .putString("next_prayer_name", "الفجر")
                .putString("next_prayer_remaining", "افتح التطبيق لتحديث الصلاة القادمة")
                .putInt("next_prayer_remaining_minutes", 999)
                .apply()

            SalatiTodayPrayerTimesWidgetProvider.updateAll(context)
            SalatiNextPrayerCountdownWidgetProvider.updateAll(context)
            SalatiPointsPrayerRatingWidgetProvider.updateAll(context)
            SalatiQuickControlsWidgetProvider.updateAll(context)
        }
    }
}
