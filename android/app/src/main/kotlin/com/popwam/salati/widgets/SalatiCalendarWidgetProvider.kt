package com.popwam.salati.widgets

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.widget.RemoteViews
import com.popwam.salati.R
import java.time.LocalDate
import java.time.chrono.HijrahChronology
import java.time.temporal.ChronoField

class SalatiCalendarWidgetProvider : AppWidgetProvider() {
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
        val views = RemoteViews(context.packageName, R.layout.widget_calendar_30)
        val gregorian = LocalDate.now()
        val hijri = HijrahChronology.INSTANCE.date(gregorian)
        val showHijri = (System.currentTimeMillis() / 20_000L) % 2L == 0L
        val gregorianLabel = "${gregorian.dayOfMonth} ${gregorianMonths[gregorian.monthValue - 1]} ${gregorian.year}م"
        val hijriLabel =
            "${hijri.get(ChronoField.DAY_OF_MONTH)} ${hijriMonths[hijri.get(ChronoField.MONTH_OF_YEAR) - 1]} ${hijri.get(ChronoField.YEAR)}هـ"

        views.setTextViewText(
            R.id.calendar_month_title,
            if (showHijri) "التاريخ الهجري" else "التاريخ الميلادي",
        )
        views.setTextViewText(R.id.calendar_today_big, if (showHijri) hijriLabel else gregorianLabel)
        views.setTextViewText(R.id.calendar_today_small, if (showHijri) gregorianLabel else hijriLabel)

        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        if (launchIntent != null) {
            views.setOnClickPendingIntent(
                R.id.salati_widget_root,
                PendingIntent.getActivity(
                    context,
                    appWidgetId,
                    launchIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                ),
            )
        }

        manager.updateAppWidget(appWidgetId, views)
    }

    companion object {
        private val hijriMonths = arrayOf(
            "محرم",
            "صفر",
            "ربيع الأول",
            "ربيع الآخر",
            "جمادى الأولى",
            "جمادى الآخرة",
            "رجب",
            "شعبان",
            "رمضان",
            "شوال",
            "ذو القعدة",
            "ذو الحجة",
        )

        private val gregorianMonths = arrayOf(
            "يناير",
            "فبراير",
            "مارس",
            "أبريل",
            "مايو",
            "يونيو",
            "يوليو",
            "أغسطس",
            "سبتمبر",
            "أكتوبر",
            "نوفمبر",
            "ديسمبر",
        )

        fun updateAll(context: Context): Boolean {
            val manager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, SalatiCalendarWidgetProvider::class.java)
            val ids = manager.getAppWidgetIds(component)
            if (ids.isEmpty()) return false
            val provider = SalatiCalendarWidgetProvider()

            for (id in ids) {
                provider.updateWidget(context, manager, id)
            }
            return true
        }
    }
}
