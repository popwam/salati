package com.popwam.salati.widgets

import com.popwam.salati.R

class SalatiCustomAyahWidgetProvider : SalatiBaseTextWidgetProvider() {
    override val prefsKey = "custom_ayah"
    override val defaultTitle = "آية مفضلة"
    override val defaultBody = "اختر آية من التطبيق لتظهر هنا."
    override val defaultReference = "صلاتي"
    override val layoutId = R.layout.widget_random_ayah_modern
    override val quoteBody = true
}
