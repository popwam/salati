package com.popwam.salati.widgets

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import com.popwam.salati.R

abstract class SalatiBaseTextWidgetProvider : AppWidgetProvider() {
    abstract val prefsKey: String
    abstract val defaultTitle: String
    abstract val defaultBody: String
    abstract val defaultReference: String

    open val layoutId: Int = R.layout.widget_text_card
    open val quoteBody: Boolean = false

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (appWidgetId in appWidgetIds) {
            updateTextWidget(context, appWidgetManager, appWidgetId)
        }
    }

    protected fun prefs(context: Context) =
        context.getSharedPreferences(SalatiWidgetsBridge.PREFS_NAME, Context.MODE_PRIVATE)

    protected fun updateTextWidget(
        context: Context,
        manager: AppWidgetManager,
        appWidgetId: Int,
    ) {
        val prefs = prefs(context)

        val title = prefs.getString("${prefsKey}_title", defaultTitle) ?: defaultTitle
        val body = prefs.getString("${prefsKey}_body", defaultBody) ?: defaultBody
        val reference = prefs.getString("${prefsKey}_reference", defaultReference) ?: defaultReference
        val displayBody = if (quoteBody && body.isNotBlank()) "\"$body\"" else body

        val views = RemoteViews(context.packageName, layoutId)
        views.setTextViewText(R.id.salati_widget_title, title)
        views.setTextViewText(R.id.salati_widget_body, displayBody)
        views.setTextViewText(R.id.salati_widget_reference, reference)

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
        fun updateProviderWidgets(
            context: Context,
            providerClass: Class<out AppWidgetProvider>,
        ): Boolean {
            val manager = AppWidgetManager.getInstance(context)
            val componentName = android.content.ComponentName(context, providerClass)
            val widgetIds = manager.getAppWidgetIds(componentName)
            if (widgetIds.isEmpty()) return false

            val provider = providerClass.getDeclaredConstructor().newInstance()
            if (provider is SalatiBaseTextWidgetProvider) {
                for (widgetId in widgetIds) {
                    provider.updateTextWidget(context, manager, widgetId)
                }
                return true
            }
            return false
        }
    }
}
