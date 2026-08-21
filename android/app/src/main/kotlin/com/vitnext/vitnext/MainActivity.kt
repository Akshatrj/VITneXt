package com.vitnext.vitnext

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val WIDGET_CHANNEL = "com.vitnext/widget"
    private val RELIABILITY_CHANNEL = "com.vitnext/reliability"
    private val CLASS_FOCUS_CHANNEL = "com.vitnext/class_focus"

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
                    "scheduleDayRollover" -> {
                        DayRolloverScheduler.schedule(this)
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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CLASS_FOCUS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "syncClassMonitor" -> {
                        val autoSilent = call.argument<Boolean>("autoSilent") ?: false
                        val scheduleJson = call.argument<String>("scheduleJson") ?: "[]"
                        val scheduleDate = call.argument<String>("scheduleDate") ?: ""

                        val prefs = getSharedPreferences(
                            ClassLiveMonitorService.PREFS_NAME,
                            Context.MODE_PRIVATE
                        )
                        prefs.edit()
                            .putString(
                                ClassLiveMonitorService.KEY_AUTO_SILENT,
                                if (autoSilent) "true" else "false"
                            )
                            .putString(ClassLiveMonitorService.KEY_SCHEDULE_JSON, scheduleJson)
                            .putString(ClassLiveMonitorService.KEY_SCHEDULE_DATE, scheduleDate)
                            .apply()

                        if (autoSilent) {
                            val intent = Intent(this, ClassLiveMonitorService::class.java).apply {
                                action = ClassLiveMonitorService.ACTION_SYNC
                            }
                            ContextCompat.startForegroundService(this, intent)
                        } else {
                            val stopIntent = Intent(this, ClassLiveMonitorService::class.java).apply {
                                action = ClassLiveMonitorService.ACTION_STOP
                            }
                            startService(stopIntent)
                        }
                        result.success(null)
                    }
                    "stopClassMonitor" -> {
                        val stopIntent = Intent(this, ClassLiveMonitorService::class.java).apply {
                            action = ClassLiveMonitorService.ACTION_STOP
                        }
                        startService(stopIntent)
                        result.success(null)
                    }
                    "canModifyRingerMode" -> {
                        result.success(canModifyRingerMode())
                    }
                    "openSoundSettings" -> {
                        startActivity(Intent(Settings.ACTION_SOUND_SETTINGS))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun canModifyRingerMode(): Boolean {
        return try {
            val audioManager = getSystemService(AUDIO_SERVICE) as AudioManager
            val current = audioManager.ringerMode
            audioManager.ringerMode = current
            true
        } catch (_: Exception) {
            false
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
