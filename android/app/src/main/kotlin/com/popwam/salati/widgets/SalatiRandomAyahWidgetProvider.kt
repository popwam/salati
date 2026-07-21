package com.popwam.salati.widgets

import com.popwam.salati.R

class SalatiRandomAyahWidgetProvider : SalatiBaseTextWidgetProvider() {
    override val prefsKey = "random_ayah"
    override val defaultTitle = "آية اليوم"
    override val defaultBody = "افتح التطبيق لتحديث آية اليوم"
    override val defaultReference = "القرآن الكريم"
    override val layoutId = R.layout.widget_random_ayah_modern
    override val quoteBody = true
}
