package com.popwam.salati.widgets

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import com.popwam.salati.R

class SalatiInteractiveQuranWidgetProvider : SalatiBaseTextWidgetProvider() {
    override val prefsKey = "interactive_quran"
    override val defaultTitle = "قراءة القرآن"
    override val defaultBody = "افتح التطبيق لتحديث القراءة"
    override val defaultReference = "آخر موضع"
    override val layoutId = R.layout.widget_interactive_quran

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)

        when (intent.action) {
            ACTION_QURAN_NEXT -> moveVerse(context, 1)
            ACTION_QURAN_PREVIOUS -> moveVerse(context, -1)
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (appWidgetId in appWidgetIds) {
            updateInteractiveWidget(context, appWidgetManager, appWidgetId)
        }
    }

    private fun moveVerse(context: Context, delta: Int) {
        val prefs = prefs(context)
        val currentAyah = prefs.getInt("${prefsKey}_ayah", 1).coerceAtLeast(1)
        val nextAyah = (currentAyah + delta).coerceAtLeast(1)
        val surah = prefs.getInt("${prefsKey}_surah", 1).coerceIn(1, 114)
        val surahName = prefs.getString("${prefsKey}_surah_name", "سورة $surah") ?: "سورة $surah"
        val reference = "$surahName، آية $nextAyah"
        val body = "موضع قراءة الشاشة: $reference"

        prefs.edit()
            .putInt("${prefsKey}_ayah", nextAyah)
            .putInt("${prefsKey}_index", nextAyah - 1)
            .putString("${prefsKey}_title", "قراءة القرآن")
            .putString("${prefsKey}_body", body)
            .putString("${prefsKey}_reference", reference)
            .apply()

        updateAll(context)
    }

    private fun updateInteractiveWidget(
        context: Context,
        manager: AppWidgetManager,
        appWidgetId: Int,
    ) {
        val prefs = prefs(context)
        val title = prefs.getString("${prefsKey}_title", defaultTitle) ?: defaultTitle
        val body = prefs.getString("${prefsKey}_body", defaultBody) ?: defaultBody
        val reference = prefs.getString("${prefsKey}_reference", defaultReference) ?: defaultReference

        val views = RemoteViews(context.packageName, layoutId)
        views.setTextViewText(R.id.salati_widget_title, title)
        views.setTextViewText(R.id.salati_widget_body, body)
        views.setTextViewText(R.id.salati_widget_reference, reference)

        views.setOnClickPendingIntent(
            R.id.salati_widget_button_previous,
            pending(context, appWidgetId + 1000, ACTION_QURAN_PREVIOUS),
        )
        views.setOnClickPendingIntent(
            R.id.salati_widget_button_next,
            pending(context, appWidgetId + 2000, ACTION_QURAN_NEXT),
        )

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

    private fun pending(context: Context, requestCode: Int, action: String): PendingIntent {
        val intent = Intent(context, SalatiInteractiveQuranWidgetProvider::class.java).apply {
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
        const val ACTION_QURAN_NEXT = "com.popwam.salati.ACTION_QURAN_NEXT"
        const val ACTION_QURAN_PREVIOUS = "com.popwam.salati.ACTION_QURAN_PREVIOUS"

        fun updateAll(context: Context): Boolean {
            val manager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, SalatiInteractiveQuranWidgetProvider::class.java)
            val ids = manager.getAppWidgetIds(component)
            if (ids.isEmpty()) return false
            val provider = SalatiInteractiveQuranWidgetProvider()

            for (id in ids) {
                provider.updateInteractiveWidget(context, manager, id)
            }
            return true
        }
    }
}
