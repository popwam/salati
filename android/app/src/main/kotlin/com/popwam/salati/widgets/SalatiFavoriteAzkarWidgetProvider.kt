package com.popwam.salati.widgets

class SalatiFavoriteAzkarWidgetProvider : SalatiBaseTextWidgetProvider() {
    override val prefsKey = "favorite_azkar"
    override val defaultTitle = "الأذكار المفضلة"
    override val defaultBody = "لا توجد أذكار مفضلة بعد"
    override val defaultReference = "الأذكار"
    override val quoteBody = true
}
