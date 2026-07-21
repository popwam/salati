package com.popwam.salati

import com.popwam.salati.widgets.SalatiWidgetsBridge
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val homeWidgetChannelName = "salati/home_widget"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            homeWidgetChannelName,
        ).setMethodCallHandler(SalatiWidgetsBridge(applicationContext))
    }
}
