package com.vitnext.vitnext

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import org.json.JSONArray
import java.util.Calendar

/**
 * Foreground service for silent + vibrate during class.
 * Uses [ClassLiveScheduler] alarms at class boundaries instead of polling.
 */
class ClassLiveMonitorService : Service() {

    companion object {
        const val ACTION_SYNC = "com.vitnext.CLASS_LIVE_SYNC"
        const val ACTION_STOP = "com.vitnext.CLASS_LIVE_STOP"
        const val ACTION_BOUNDARY = "com.vitnext.CLASS_LIVE_BOUNDARY"

        const val PREFS_NAME = "FlutterSharedPreferences"
        const val KEY_AUTO_SILENT = "flutter.auto_silent_during_class"
        const val KEY_SCHEDULE_JSON = "flutter.live_schedule_json"

        private const val CHANNEL_ID = "class_focus"
        private const val NOTIFICATION_ID = 10042
    }

    private var isForeground = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                ClassLiveScheduler.cancelAll(this)
                RingerModeHelper.restore(this)
                endForegroundAndStop()
                return START_NOT_STICKY
            }
            ACTION_BOUNDARY -> {
                // Re-evaluate at alarm boundary.
            }
        }

        evaluateAndUpdate()
        return START_STICKY
    }

    override fun onDestroy() {
        RingerModeHelper.restore(this)
        super.onDestroy()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Class Focus",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Silent + vibrate during class"
                setShowBadge(false)
            }
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    private fun readPrefs(): SharedPrefsSnapshot {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val autoSilent = FlutterPrefs.getBool(prefs, KEY_AUTO_SILENT, false)
        val scheduleJson = prefs.getString(KEY_SCHEDULE_JSON, "[]") ?: "[]"
        return SharedPrefsSnapshot(autoSilent, scheduleJson)
    }

    private fun evaluateAndUpdate() {
        val snapshot = readPrefs()

        if (!snapshot.autoSilent) {
            ClassLiveScheduler.cancelAll(this)
            RingerModeHelper.restore(this)
            endForegroundAndStop()
            return
        }

        val classes = parseSchedule(snapshot.scheduleJson)
        ClassLiveScheduler.schedule(this, classes)

        val active = findCurrentClass(classes)
        if (active != null && !active.cancelled) {
            RingerModeHelper.applyVibrateMode(this)
            startOrUpdateForeground(
                buildStatusNotification(
                    title = "Silent during class",
                    body = "Vibrate-only mode is active",
                    ongoing = true
                )
            )
        } else {
            RingerModeHelper.restore(this)
            endForegroundAndStop()
        }
    }

    private fun startOrUpdateForeground(notification: Notification) {
        if (!isForeground) {
            startForeground(NOTIFICATION_ID, notification)
            isForeground = true
        } else {
            getSystemService(NotificationManager::class.java).notify(NOTIFICATION_ID, notification)
        }
    }

    private fun endForegroundAndStop() {
        if (isForeground) {
            stopForeground(STOP_FOREGROUND_REMOVE)
            isForeground = false
        }
        stopSelf()
    }

    private fun buildStatusNotification(
        title: String,
        body: String,
        ongoing: Boolean,
    ): Notification {
        val openIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pending = PendingIntent.getActivity(
            this, 0, openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setOngoing(ongoing)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setShowWhen(false)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(pending)
            .build()
    }

    private fun parseSchedule(json: String): List<LiveClassEntry> {
        val result = mutableListOf<LiveClassEntry>()
        try {
            val array = JSONArray(json)
            for (i in 0 until array.length()) {
                val obj = array.getJSONObject(i)
                result.add(
                    LiveClassEntry(
                        startHour = obj.optInt("startHour", 0),
                        startMinute = obj.optInt("startMinute", 0),
                        endHour = obj.optInt("endHour", 0),
                        endMinute = obj.optInt("endMinute", 0),
                        cancelled = obj.optBoolean("cancelled", false)
                    )
                )
            }
        } catch (_: Exception) {
            // Empty schedule on parse error.
        }
        return result
    }

    private fun nowMinutes(): Int {
        val cal = Calendar.getInstance()
        return cal.get(Calendar.HOUR_OF_DAY) * 60 + cal.get(Calendar.MINUTE)
    }

    private fun findCurrentClass(classes: List<LiveClassEntry>): LiveClassEntry? {
        val now = nowMinutes()
        return classes.firstOrNull { cls ->
            !cls.cancelled &&
                now >= cls.startTotalMinutes &&
                now < cls.endTotalMinutes
        }
    }

    data class SharedPrefsSnapshot(
        val autoSilent: Boolean,
        val scheduleJson: String
    )

    data class LiveClassEntry(
        val startHour: Int,
        val startMinute: Int,
        val endHour: Int,
        val endMinute: Int,
        val cancelled: Boolean
    ) {
        val startTotalMinutes: Int = startHour * 60 + startMinute
        val endTotalMinutes: Int = endHour * 60 + endMinute
    }
}
