package com.vitnext.vitnext

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/**
 * Short-lived foreground service that runs Flutter headless maintenance
 * (widget refresh, notifications, class-focus sync) at day rollover.
 */
class BackgroundMaintenanceService : Service() {

    companion object {
        private const val CHANNEL_ID = "background_maintenance"
        private const val NOTIFICATION_ID = 10043
        private const val DART_ENTRYPOINT = "backgroundMaintenance"
        private const val TIMEOUT_MS = 60_000L
    }

    private var flutterEngine: FlutterEngine? = null
    private val handler = Handler(Looper.getMainLooper())
    private var finished = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForeground(NOTIFICATION_ID, buildNotification())
        startHeadlessMaintenance()
        handler.postDelayed({ finishIfNeeded("timeout") }, TIMEOUT_MS)
        return START_NOT_STICKY
    }

    private fun startHeadlessMaintenance() {
        try {
            val loader = FlutterInjector.instance().flutterLoader()
            loader.startInitialization(applicationContext)
            loader.ensureInitializationComplete(applicationContext, null)

            val engine = FlutterEngine(applicationContext)
            flutterEngine = engine

            MethodChannel(engine.dartExecutor.binaryMessenger, "com.vitnext/background")
                .setMethodCallHandler { call, result ->
                    if (call.method == "maintenanceComplete") {
                        finishIfNeeded("dart_complete")
                        result.success(null)
                    } else {
                        result.notImplemented()
                    }
                }

            val entrypoint = DartExecutor.DartEntrypoint(
                loader.findAppBundlePath(),
                DART_ENTRYPOINT
            )
            engine.dartExecutor.executeDartEntrypoint(entrypoint)
        } catch (_: Exception) {
            finishIfNeeded("engine_error")
        }
    }

    private fun finishIfNeeded(reason: String) {
        if (finished) return
        finished = true
        handler.removeCallbacksAndMessages(null)
        try {
            flutterEngine?.destroy()
        } catch (_: Exception) {
        }
        flutterEngine = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Schedule refresh",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Updates widget and class silent mode for the new day"
                setShowBadge(false)
            }
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        val openIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pending = PendingIntent.getActivity(
            this, 0, openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("VITneXt")
            .setContentText("Updating today's schedule…")
            .setOngoing(true)
            .setSilent(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(pending)
            .build()
    }
}
