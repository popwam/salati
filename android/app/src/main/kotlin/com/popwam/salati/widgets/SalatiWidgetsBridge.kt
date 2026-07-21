package com.popwam.salati.widgets

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.random.Random

class SalatiWidgetsBridge(context: Context) : MethodChannel.MethodCallHandler {
    private val appContext = context.applicationContext
    private val prefs = appContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "updateTextWidget" -> updateTextWidget(call, result)
            "updateScreenReadingWidget" -> updateScreenReadingWidget(call, result)
            "hasNextPrayerWidget" -> result.success(hasProviderWidgets(SalatiNextPrayerCountdownWidgetProvider::class.java))
            "updateNextPrayerWidget" -> updateNextPrayerWidget(call, result)
            "createQuranWidget", "updateQuranWidget" -> updateQuranWidget(call, result)
            "deleteQuranWidget" -> deleteQuranWidget(call, result)
            "updateCalendar30Widget" -> updateCalendar30Widget(call, result)
            "updatePrayerStripWidget" -> updatePrayerStripWidget(call, result)
            "scheduleMidnightWidgetRefresh" -> scheduleMidnightWidgetRefresh(call, result)
            "updatePointsPrayerRatingWidget" -> updatePointsPrayerRatingWidget(call, result)
            "updateQuickControlsWidget" -> updateQuickControlsWidget(call, result)
            "saveFavoriteAyahs" -> saveFavorites(call, result, "ayahs", "favorite_ayahs") {
                updateRandomAyah()
            }
            "saveFavoriteAzkar" -> saveFavorites(call, result, "items", "favorite_azkar_items") {
                updateRandomZikr()
            }
            "updateRandomAyah" -> {
                result.success(updateRandomAyah())
            }
            "updateRandomZikr" -> {
                result.success(updateRandomZikr())
            }
            else -> result.notImplemented()
        }
    }

    private fun updateTextWidget(call: MethodCall, result: MethodChannel.Result) {
        val key = call.argument<String>("key").orEmpty().trim()
        if (key.isBlank()) {
            result.error("INVALID_KEY", "key is required", null)
            return
        }

        saveTextWidget(
            key = key,
            title = call.argument<String>("title").orEmpty(),
            body = call.argument<String>("body").orEmpty(),
            reference = call.argument<String>("reference").orEmpty(),
        )

        result.success(updateByKey(key))
    }

    private fun updateNextPrayerWidget(call: MethodCall, result: MethodChannel.Result) {
        val prayerName = call.argument<String>("prayerName").orEmpty().ifBlank { "الصلاة القادمة" }
        val remaining = call.argument<String>("remaining").orEmpty().ifBlank { "--" }
        val remainingMinutes = numberToInt(call.argument<Any>("remainingMinutes"), 999)
        val prayerKey = call.argument<String>("prayerKey").orEmpty()
        val prayerTimeMillis = numberToLong(call.argument<Any>("prayerTimeMillis"))

        prefs.edit()
            .putString("next_prayer_title", "الصلاة القادمة")
            .putString("next_prayer_name", prayerName)
            .putString("next_prayer_remaining", remaining)
            .putInt("next_prayer_remaining_minutes", remainingMinutes)
            .putString("next_prayer_key", prayerKey)
            .putLong("next_prayer_time_millis", prayerTimeMillis)
            .apply()

        result.success(updateByKey("next_prayer"))
    }

    private fun updateScreenReadingWidget(call: MethodCall, result: MethodChannel.Result) {
        val title = call.argument<String>("title").orEmpty().ifBlank { "قراءة الشاشة" }
        val body = call.argument<String>("body").orEmpty().ifBlank { "اختر موضع قراءة الشاشة من التطبيق." }
        val reference = call.argument<String>("reference").orEmpty().ifBlank { "صلاتي" }
        val surah = numberToInt(call.argument<Any>("surah"), 1).coerceIn(1, 114)
        val ayah = numberToInt(call.argument<Any>("ayah"), 1).coerceAtLeast(1)
        val surahName = call.argument<String>("surahName").orEmpty().ifBlank { "سورة $surah" }

        prefs.edit()
            .putString("interactive_quran_title", title)
            .putString("interactive_quran_body", body)
            .putString("interactive_quran_reference", reference)
            .putInt("interactive_quran_surah", surah)
            .putInt("interactive_quran_ayah", ayah)
            .putString("interactive_quran_surah_name", surahName)
            .putInt("interactive_quran_index", 0)
            .apply()

        result.success(updateByKey("interactive_quran"))
    }

    private fun updateQuranWidget(call: MethodCall, result: MethodChannel.Result) {
        val widgetId = call.argument<String>("widgetId").orEmpty()
        val title = call.argument<String>("title").orEmpty().ifBlank { "آية من القرآن" }
        val body = call.argument<String>("body").orEmpty()
        val reference = call.argument<String>("reference").orEmpty().ifBlank { "صلاتي" }
        val name = call.argument<String>("name").orEmpty()
        val expiresAt = numberToLong(call.argument<Any>("expiresAt"))

        prefs.edit()
            .putString("custom_ayah_widget_id", widgetId)
            .putString("custom_ayah_name", name)
            .putLong("custom_ayah_expires_at", expiresAt)
            .apply()

        saveTextWidget("custom_ayah", title, body, reference)
        result.success(updateByKey("custom_ayah"))
    }

    private fun deleteQuranWidget(call: MethodCall, result: MethodChannel.Result) {
        val widgetId = call.argument<String>("widgetId").orEmpty()
        val savedWidgetId = prefs.getString("custom_ayah_widget_id", "").orEmpty()

        if (widgetId.isBlank() || widgetId == savedWidgetId) {
            prefs.edit()
                .remove("custom_ayah_widget_id")
                .remove("custom_ayah_name")
                .remove("custom_ayah_expires_at")
                .remove("custom_ayah_title")
                .remove("custom_ayah_body")
                .remove("custom_ayah_reference")
                .apply()

            updateByKey("custom_ayah")
        }

        result.success(true)
    }

    private fun updateCalendar30Widget(call: MethodCall, result: MethodChannel.Result) {
        prefs.edit()
            .putString(
                "calendar_month_title",
                call.argument<String>("monthTitle").orEmpty().ifBlank { "التقويم" },
            )
            .putString("calendar_today_big", call.argument<String>("todayBig").orEmpty().ifBlank { "--" })
            .putString("calendar_today_small", call.argument<String>("todaySmall").orEmpty())
            .putInt("calendar_today_index", numberToInt(call.argument<Any>("todayIndex"), 1))
            .putString("calendar_30_days", call.argument<String>("daysJson").orEmpty().ifBlank { "[]" })
            .apply()

        result.success(SalatiCalendarWidgetProvider.updateAll(appContext))
    }

    private fun updatePrayerStripWidget(call: MethodCall, result: MethodChannel.Result) {
        prefs.edit()
            .putString("prayer_fajr", call.argument<String>("fajr").orEmpty().ifBlank { "--:--" })
            .putString("prayer_sunrise", call.argument<String>("sunrise").orEmpty().ifBlank { "--:--" })
            .putString("prayer_dhuhr", call.argument<String>("dhuhr").orEmpty().ifBlank { "--:--" })
            .putString("prayer_asr", call.argument<String>("asr").orEmpty().ifBlank { "--:--" })
            .putString("prayer_maghrib", call.argument<String>("maghrib").orEmpty().ifBlank { "--:--" })
            .putString("prayer_isha", call.argument<String>("isha").orEmpty().ifBlank { "--:--" })
            .putString("prayer_active_key", call.argument<String>("activePrayerKey").orEmpty())
            .putString("tomorrow_prayer_fajr", call.argument<String>("tomorrowFajr").orEmpty())
            .putString("tomorrow_prayer_sunrise", call.argument<String>("tomorrowSunrise").orEmpty())
            .putString("tomorrow_prayer_dhuhr", call.argument<String>("tomorrowDhuhr").orEmpty())
            .putString("tomorrow_prayer_asr", call.argument<String>("tomorrowAsr").orEmpty())
            .putString("tomorrow_prayer_maghrib", call.argument<String>("tomorrowMaghrib").orEmpty())
            .putString("tomorrow_prayer_isha", call.argument<String>("tomorrowIsha").orEmpty())
            .putString("tomorrow_prayer_active_key", call.argument<String>("tomorrowActivePrayerKey").orEmpty())
            .apply()

        val todayUpdated = SalatiTodayPrayerTimesWidgetProvider.updateAll(appContext)
        val nextUpdated = SalatiNextPrayerCountdownWidgetProvider.updateAll(appContext)
        result.success(todayUpdated || nextUpdated)
    }

    private fun scheduleMidnightWidgetRefresh(call: MethodCall, result: MethodChannel.Result) {
        val triggerAtMillis = numberToLong(call.argument<Any>("triggerAtMillis"))
        if (triggerAtMillis <= 0L) {
            result.success(false)
            return
        }

        SalatiMidnightWidgetRefreshReceiver.schedule(appContext, triggerAtMillis)
        result.success(true)
    }

    private fun updatePointsPrayerRatingWidget(call: MethodCall, result: MethodChannel.Result) {
        prefs.edit()
            .putString("points_rating_points", call.argument<String>("points").orEmpty().ifBlank { "0" })
            .putString("points_rating_label", call.argument<String>("prayerRating").orEmpty().ifBlank { "غير متاح" })
            .putInt("points_rating_completed", numberToInt(call.argument<Any>("completedPrayersToday"), 0))
            .apply()

        result.success(SalatiPointsPrayerRatingWidgetProvider.updateAll(appContext))
    }

    private fun updateQuickControlsWidget(call: MethodCall, result: MethodChannel.Result) {
        prefs.edit()
            .putBoolean(
                "controls_notifications_loud",
                call.argument<Boolean>("notificationsLoud") ?: prefs.getBoolean("controls_notifications_loud", true),
            )
            .putBoolean(
                "controls_next_alert_enabled",
                call.argument<Boolean>("nextAlertEnabled") ?: prefs.getBoolean("controls_next_alert_enabled", true),
            )
            .putBoolean(
                "controls_touch_lock_enabled",
                call.argument<Boolean>("touchLockEnabled") ?: prefs.getBoolean("controls_touch_lock_enabled", false),
            )
            .apply()

        result.success(SalatiQuickControlsWidgetProvider.updateAll(appContext))
    }

    private fun saveFavorites(
        call: MethodCall,
        result: MethodChannel.Result,
        argumentKey: String,
        prefsKey: String,
        afterSave: () -> Unit,
    ) {
        saveFavoriteList(prefsKey, readFavoriteArgument(call, argumentKey))
        afterSave()
        result.success(true)
    }

    private fun saveTextWidget(
        key: String,
        title: String,
        body: String,
        reference: String,
    ) {
        prefs.edit()
            .putString("${key}_title", title)
            .putString("${key}_body", body)
            .putString("${key}_reference", reference)
            .apply()
    }

    private fun saveFavoriteList(key: String, items: List<Triple<String, String, String>>) {
        val encoded = items
            .filter { it.second.isNotBlank() }
            .joinToString("||") { item ->
                listOf(item.first, item.second, item.third)
                    .joinToString("|") { value -> value.replace("|", " ").replace("||", " ") }
            }

        prefs.edit().putString(key, encoded).apply()
    }

    private fun readFavoriteArgument(call: MethodCall, key: String): List<Triple<String, String, String>> {
        val rawItems = call.argument<List<*>>(key) ?: emptyList<Any>()

        return rawItems.mapNotNull { raw ->
            val item = raw as? Map<*, *> ?: return@mapNotNull null
            val title = item["title"] as? String ?: ""
            val body = item["body"] as? String ?: ""
            val reference = item["reference"] as? String ?: ""
            Triple(title, body, reference)
        }
    }

    private fun readFavoriteList(key: String): List<Triple<String, String, String>> {
        val encoded = prefs.getString(key, "").orEmpty()
        if (encoded.isBlank()) return emptyList()

        return encoded.split("||").mapNotNull { row ->
            val parts = row.split("|")
            if (parts.size < 3) null else Triple(parts[0], parts[1], parts[2])
        }
    }

    private fun updateRandomAyah(): Boolean {
        val ayahs = readFavoriteList("favorite_ayahs")

        if (ayahs.isEmpty()) {
            saveTextWidget(
                key = "random_ayah",
                title = "آية اليوم",
                body = "أضف آيات إلى المفضلة ليظهر منها ويدجت عشوائي.",
                reference = "المفضلة",
            )
        } else {
            val selected = ayahs[Random.nextInt(ayahs.size)]
            saveTextWidget("random_ayah", selected.first, selected.second, selected.third)
        }

        return updateByKey("random_ayah")
    }

    private fun updateRandomZikr(): Boolean {
        val items = readFavoriteList("favorite_azkar_items")

        if (items.isEmpty()) {
            saveTextWidget(
                key = "favorite_azkar",
                title = "ذكر مفضل",
                body = "أضف أدعية أو أذكار إلى المفضلة ليظهر منها ويدجت عشوائي.",
                reference = "الأذكار",
            )
        } else {
            val selected = items[Random.nextInt(items.size)]
            saveTextWidget("favorite_azkar", selected.first, selected.second, selected.third)
        }

        return updateByKey("favorite_azkar")
    }

    private fun updateByKey(key: String): Boolean {
        return when (key) {
            "custom_ayah" -> updateBase(SalatiCustomAyahWidgetProvider::class.java)
            "random_ayah" -> updateBase(SalatiRandomAyahWidgetProvider::class.java)
            "favorite_azkar" -> updateBase(SalatiFavoriteAzkarWidgetProvider::class.java)
            "next_prayer" -> {
                SalatiNextPrayerCountdownWidgetProvider.updateAll(appContext)
            }
            "points_rating" -> {
                SalatiPointsPrayerRatingWidgetProvider.updateAll(appContext)
            }
            "interactive_quran" -> {
                SalatiInteractiveQuranWidgetProvider.updateAll(appContext)
            }
            "calendar" -> {
                SalatiCalendarWidgetProvider.updateAll(appContext)
            }
            "today_prayer_times" -> {
                SalatiTodayPrayerTimesWidgetProvider.updateAll(appContext)
            }
            "quick_controls" -> {
                SalatiQuickControlsWidgetProvider.updateAll(appContext)
            }
            else -> false
        }
    }

    private fun updateBase(providerClass: Class<out SalatiBaseTextWidgetProvider>): Boolean {
        return SalatiBaseTextWidgetProvider.updateProviderWidgets(appContext, providerClass)
    }

    private fun hasProviderWidgets(providerClass: Class<*>): Boolean {
        val manager = AppWidgetManager.getInstance(appContext)
        val component = ComponentName(appContext, providerClass)
        return manager.getAppWidgetIds(component).isNotEmpty()
    }

    private fun numberToInt(value: Any?, fallback: Int): Int {
        return when (value) {
            is Int -> value
            is Long -> value.toInt()
            is Double -> value.toInt()
            is Float -> value.toInt()
            is Number -> value.toInt()
            else -> fallback
        }
    }

    private fun numberToLong(value: Any?): Long {
        return when (value) {
            is Long -> value
            is Int -> value.toLong()
            is Double -> value.toLong()
            is Float -> value.toLong()
            is Number -> value.toLong()
            else -> 0L
        }
    }

    companion object {
        const val PREFS_NAME = "salati_widgets_data"
    }
}
