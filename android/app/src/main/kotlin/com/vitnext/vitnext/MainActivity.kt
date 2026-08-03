package com.vitnext.vitnext

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val WIDGET_CHANNEL = "com.vitnext/widget"
    private val RELIABILITY_CHANNEL = "com.vitnext/reliability"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "updateWidget" -> {
                        updateWidgets()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, RELIABILITY_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isIgnoringBatteryOptimizations" -> {
                        result.success(isIgnoringBatteryOptimizations())
                    }
                    "openBatteryOptimizationSettings" -> {
                        openBatteryOptimizationSettings()
                        result.success(null)
                    }
                    "requestIgnoreBatteryOptimizations" -> {
                        result.success(requestIgnoreBatteryOptimizations())
                    }
                    "scheduleWidgetHeal" -> {
                        WidgetHealReceiver.schedule(this)
                        result.success(null)
                    }
                    "forceWidgetRefresh" -> {
                        WidgetHealReceiver.refreshWidgets(this)
                        result.success(null)
                    }
                    "widgetHealth" -> {
                        result.success(widgetHealthMap())
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun updateWidgets() {
        val appWidgetManager = AppWidgetManager.getInstance(applicationContext)
        val widgetComponent = ComponentName(applicationContext, NextClassWidgetProvider::class.java)
        val widgetIds = appWidgetManager.getAppWidgetIds(widgetComponent)

        if (widgetIds.isNotEmpty()) {
            val provider = NextClassWidgetProvider()
            provider.onUpdate(applicationContext, appWidgetManager, widgetIds)
        }
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        return try {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            pm.isIgnoringBatteryOptimizations(packageName)
        } catch (_: Exception) {
            false
        }
    }

    private fun openBatteryOptimizationSettings() {
        try {
            // App-specific screen when available; falls back to general list.
            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                data = Uri.parse("package:$packageName")
            }
            startActivity(intent)
        } catch (_: Exception) {
            try {
                startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
            } catch (_: Exception) {
                startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = Uri.parse("package:$packageName")
                })
            }
        }
    }

    private fun requestIgnoreBatteryOptimizations(): Boolean {
        val already = isIgnoringBatteryOptimizations()
        if (already) return true
        openBatteryOptimizationSettings()
        return isIgnoringBatteryOptimizations()
    }

    private fun widgetHealthMap(): Map<String, Any?> {
        val manager = AppWidgetManager.getInstance(applicationContext)
        val component = ComponentName(applicationContext, NextClassWidgetProvider::class.java)
        val ids = manager.getAppWidgetIds(component)
        val prefs = getSharedPreferences(NextClassWidgetProvider.PREFS_NAME, Context.MODE_PRIVATE)
        return mapOf(
            "widgetCount" to ids.size,
            "hasStatus" to prefs.contains(NextClassWidgetProvider.KEY_STATUS),
            "hasQueue" to prefs.contains(NextClassWidgetProvider.KEY_QUEUE_JSON),
            "lastNativeHealMillis" to prefs.getLong("flutter.widget_last_native_heal_millis", 0L),
            "deviceModel" to Build.MODEL,
            "androidSdk" to Build.VERSION.SDK_INT,
            "manufacturer" to Build.MANUFACTURER,
        )
    }
}
