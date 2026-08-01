package com.vitnextclass.vit_nextclass

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.provider.Settings
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val WIDGET_CHANNEL = "com.vitnextclass/widget"
    private val CLASS_FOCUS_CHANNEL = "com.vitnextclass/class_focus"

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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CLASS_FOCUS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "syncClassMonitor" -> {
                        val liveEnabled = call.argument<Boolean>("liveEnabled") ?: false
                        val autoSilent = call.argument<Boolean>("autoSilent") ?: false
                        val scheduleJson = call.argument<String>("scheduleJson") ?: "[]"
                        val displayJson = call.argument<String>("displayJson") ?: "[]"

                        val prefs = getSharedPreferences(
                            ClassLiveMonitorService.PREFS_NAME,
                            Context.MODE_PRIVATE
                        )
                        prefs.edit()
                            .putString(
                                ClassLiveMonitorService.KEY_LIVE_ENABLED,
                                if (liveEnabled) "true" else "false"
                            )
                            .putString(
                                ClassLiveMonitorService.KEY_AUTO_SILENT,
                                if (autoSilent) "true" else "false"
                            )
                            .putString(ClassLiveMonitorService.KEY_SCHEDULE_JSON, scheduleJson)
                            .apply()

                        if (liveEnabled || autoSilent) {
                            val intent = Intent(this, ClassLiveMonitorService::class.java).apply {
                                action = ClassLiveMonitorService.ACTION_SYNC
                                putExtra(ClassLiveMonitorService.EXTRA_DISPLAY_JSON, displayJson)
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
}
