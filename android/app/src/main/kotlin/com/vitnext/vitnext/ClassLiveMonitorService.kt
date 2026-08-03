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
 * Foreground service for live class status and optional vibrate-only mode.
 * Uses [ClassLiveScheduler] alarms at class boundaries instead of polling.
 */
class ClassLiveMonitorService : Service() {

    companion object {
        const val ACTION_SYNC = "com.vitnext.CLASS_LIVE_SYNC"
        const val ACTION_STOP = "com.vitnext.CLASS_LIVE_STOP"
        const val ACTION_BOUNDARY = "com.vitnext.CLASS_LIVE_BOUNDARY"

        const val EXTRA_DISPLAY_JSON = "display_json"

        const val PREFS_NAME = "FlutterSharedPreferences"
        const val KEY_LIVE_ENABLED = "flutter.live_class_status_enabled"
        const val KEY_AUTO_SILENT = "flutter.auto_silent_during_class"
        const val KEY_SCHEDULE_JSON = "flutter.live_schedule_json"

        const val PRE_CLASS_WINDOW_MINUTES = 15

        private const val CHANNEL_ID = "live_class_status"
        private const val NOTIFICATION_ID = 10042

        private var displayCache: Map<String, DisplayEntry> = emptyMap()

        fun updateDisplayCache(json: String) {
            displayCache = parseDisplayJson(json)
        }

        fun clearDisplayCache() {
            displayCache = emptyMap()
        }

        private fun parseDisplayJson(json: String): Map<String, DisplayEntry> {
            val map = mutableMapOf<String, DisplayEntry>()
            try {
                val array = JSONArray(json)
                for (i in 0 until array.length()) {
                    val obj = array.getJSONObject(i)
                    val startHour = obj.optInt("startHour", 0)
                    val startMinute = obj.optInt("startMinute", 0)
                    val endHour = obj.optInt("endHour", 0)
                    val endMinute = obj.optInt("endMinute", 0)
                    val key = slotKey(startHour, startMinute, endHour, endMinute)
                    map[key] = DisplayEntry(
                        code = obj.optString("code", ""),
                        name = obj.optString("name", ""),
                        room = obj.optString("room", "")
                    )
                }
            } catch (_: Exception) {
                // Empty cache on parse error.
            }
            return map
        }

        private fun slotKey(
            startHour: Int,
            startMinute: Int,
            endHour: Int,
            endMinute: Int
        ): String = "$startHour:$startMinute-$endHour:$endMinute"
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
                clearDisplayCache()
                RingerModeHelper.restore(this)
                endForegroundAndStop()
                return START_NOT_STICKY
            }
            ACTION_SYNC -> {
                val displayJson = intent.getStringExtra(EXTRA_DISPLAY_JSON)
                if (displayJson != null) {
                    updateDisplayCache(displayJson)
                }
            }
            ACTION_BOUNDARY -> {
                // Re-evaluate at alarm boundary.
            }
        }

        if (!isForeground) {
            startOrUpdateForeground(
                buildStatusNotification(
                    title = "VITneXt",
                    body = "Monitoring your class schedule",
                    ongoing = true
                )
            )
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
                "Live Class Status",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows your current class on supported devices"
                setShowBadge(false)
            }
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    private fun readPrefs(): SharedPrefsSnapshot {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val liveEnabled = FlutterPrefs.getBool(prefs, KEY_LIVE_ENABLED, false)
        val autoSilent = FlutterPrefs.getBool(prefs, KEY_AUTO_SILENT, false)
        val scheduleJson = prefs.getString(KEY_SCHEDULE_JSON, "[]") ?: "[]"
        return SharedPrefsSnapshot(liveEnabled, autoSilent, scheduleJson)
    }

    private fun evaluateAndUpdate() {
        val snapshot = readPrefs()

        if (!snapshot.liveEnabled && !snapshot.autoSilent) {
            ClassLiveScheduler.cancelAll(this)
            clearDisplayCache()
            RingerModeHelper.restore(this)
            endForegroundAndStop()
            return
        }

        val classes = parseSchedule(snapshot.scheduleJson)
        ClassLiveScheduler.schedule(
            this,
            classes,
            snapshot.liveEnabled,
            PRE_CLASS_WINDOW_MINUTES
        )

        val active = findCurrentClass(classes)
        val next = findNextClass(classes)
        val inPreClassWindow = isInPreClassWindow(next)

        if (snapshot.autoSilent) {
            if (active != null && !active.cancelled) {
                RingerModeHelper.applyVibrateMode(this)
            } else {
                RingerModeHelper.restore(this)
            }
        } else {
            RingerModeHelper.restore(this)
        }

        val needsForeground = shouldRunForeground(
            snapshot.liveEnabled,
            snapshot.autoSilent,
            active,
            next,
            inPreClassWindow
        )

        if (!needsForeground) {
            endForegroundAndStop()
            return
        }

        val notification = buildNotificationForState(
            snapshot.liveEnabled,
            snapshot.autoSilent,
            active,
            next,
            inPreClassWindow
        )
        startOrUpdateForeground(notification)
    }

    private fun shouldRunForeground(
        liveEnabled: Boolean,
        autoSilent: Boolean,
        active: LiveClassEntry?,
        next: LiveClassEntry?,
        inPreClassWindow: Boolean
    ): Boolean {
        val inClass = active != null && !active.cancelled
        if (inClass) return true
        if (liveEnabled && inPreClassWindow && next != null && !next.cancelled) return true
        if (autoSilent && !liveEnabled) return false
        return false
    }

    private fun buildNotificationForState(
        liveEnabled: Boolean,
        autoSilent: Boolean,
        active: LiveClassEntry?,
        next: LiveClassEntry?,
        inPreClassWindow: Boolean
    ): Notification {
        if (!liveEnabled) {
            return buildStatusNotification(
                title = "Class focus active",
                body = "Silent + vibrate during class",
                ongoing = true,
                showWhen = false
            )
        }

        return when {
            active != null && !active.cancelled -> {
                val display = displayFor(active)
                buildStatusNotification(
                    title = if (display.code.isNotEmpty()) "In class · ${display.code}" else "In class",
                    body = buildClassBody(display, active, isActive = true),
                    ongoing = true,
                    showWhen = true
                )
            }
            inPreClassWindow && next != null && !next.cancelled -> {
                val display = displayFor(next)
                buildStatusNotification(
                    title = if (display.code.isNotEmpty()) "Next · ${display.code}" else "Upcoming class",
                    body = buildClassBody(display, next, isActive = false),
                    ongoing = true,
                    showWhen = true
                )
            }
            else -> buildStatusNotification(
                title = "Class focus active",
                body = if (autoSilent) "Monitoring schedule · silent during class" else "Monitoring schedule",
                ongoing = true,
                showWhen = false
            )
        }
    }

    private fun buildClassBody(
        display: DisplayEntry,
        cls: LiveClassEntry,
        isActive: Boolean
    ): String {
        val parts = mutableListOf<String>()
        if (display.name.isNotEmpty()) parts.add(display.name)
        if (display.room.isNotEmpty()) parts.add(display.room)
        val timePart = if (isActive) "until ${formatEnd(cls)}" else "at ${formatStart(cls)}"
        parts.add(timePart)
        return if (parts.isNotEmpty()) parts.joinToString(" · ") else timePart
    }

    private fun displayFor(cls: LiveClassEntry): DisplayEntry {
        val key = slotKey(cls.startHour, cls.startMinute, cls.endHour, cls.endMinute)
        return displayCache[key] ?: DisplayEntry()
    }

    private fun isInPreClassWindow(next: LiveClassEntry?): Boolean {
        if (next == null || next.cancelled) return false
        val now = nowMinutes()
        val minutesUntilStart = next.startTotalMinutes - now
        return minutesUntilStart in 1..PRE_CLASS_WINDOW_MINUTES
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
        showWhen: Boolean = false
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
            .setShowWhen(showWhen)
            .setCategory(NotificationCompat.CATEGORY_STATUS)
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

    private fun findNextClass(classes: List<LiveClassEntry>): LiveClassEntry? {
        val now = nowMinutes()
        return classes
            .filter { !it.cancelled && it.startTotalMinutes > now }
            .minByOrNull { it.startTotalMinutes }
    }

    private fun formatStart(cls: LiveClassEntry): String =
        formatTime(cls.startHour, cls.startMinute)

    private fun formatEnd(cls: LiveClassEntry): String =
        formatTime(cls.endHour, cls.endMinute)

    private fun formatTime(hour: Int, minute: Int): String {
        val period = if (hour >= 12) "PM" else "AM"
        val h = when {
            hour > 12 -> hour - 12
            hour == 0 -> 12
            else -> hour
        }
        return "$h:${minute.toString().padStart(2, '0')} $period"
    }

    data class SharedPrefsSnapshot(
        val liveEnabled: Boolean,
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

    data class DisplayEntry(
        val code: String = "",
        val name: String = "",
        val room: String = ""
    )
}
