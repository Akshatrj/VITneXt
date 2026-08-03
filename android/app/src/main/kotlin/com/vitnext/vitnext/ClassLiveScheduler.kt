package com.vitnext.vitnext

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import java.util.Calendar

/** Schedules exact alarms at class boundaries instead of polling. */
object ClassLiveScheduler {

    private const val ALARM_REQUEST_START_BASE = 10000
    private const val ALARM_REQUEST_END_BASE = 20000
    private const val MAX_SLOTS = 32

    fun schedule(
        context: Context,
        classes: List<ClassLiveMonitorService.LiveClassEntry>,
    ) {
        val alarmManager = context.getSystemService(AlarmManager::class.java)
        cancelAll(context, alarmManager)

        val now = nowMinutes()
        for ((index, cls) in classes.withIndex()) {
            if (cls.cancelled || index >= MAX_SLOTS) continue

            if (cls.startTotalMinutes > now) {
                scheduleAtMinute(
                    context, alarmManager,
                    cls.startTotalMinutes,
                    ALARM_REQUEST_START_BASE + index
                )
            }
            if (cls.endTotalMinutes > now) {
                scheduleAtMinute(
                    context, alarmManager,
                    cls.endTotalMinutes,
                    ALARM_REQUEST_END_BASE + index
                )
            }
        }
    }

    fun cancelAll(context: Context, alarmManager: AlarmManager? = null) {
        val manager = alarmManager ?: context.getSystemService(AlarmManager::class.java)
        for (requestCode in buildRequestCodes()) {
            manager.cancel(buildPendingIntent(context, requestCode))
        }
    }

    private fun buildRequestCodes(): List<Int> {
        val codes = mutableListOf<Int>()
        for (i in 0 until MAX_SLOTS) {
            codes.add(ALARM_REQUEST_START_BASE + i)
            codes.add(ALARM_REQUEST_END_BASE + i)
        }
        return codes
    }

    private fun scheduleAtMinute(
        context: Context,
        alarmManager: AlarmManager,
        totalMinutes: Int,
        requestCode: Int
    ) {
        val triggerAt = triggerMillisForToday(totalMinutes)
        if (triggerAt <= System.currentTimeMillis()) return

        val pending = buildPendingIntent(context, requestCode)
        alarmManager.setExactAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP,
            triggerAt,
            pending
        )
    }

    private fun buildPendingIntent(context: Context, requestCode: Int): PendingIntent {
        val intent = Intent(context, ClassLiveAlarmReceiver::class.java)
        return PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun triggerMillisForToday(totalMinutes: Int): Long {
        val cal = Calendar.getInstance()
        cal.set(Calendar.HOUR_OF_DAY, totalMinutes / 60)
        cal.set(Calendar.MINUTE, totalMinutes % 60)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)
        return cal.timeInMillis
    }

    private fun nowMinutes(): Int {
        val cal = Calendar.getInstance()
        return cal.get(Calendar.HOUR_OF_DAY) * 60 + cal.get(Calendar.MINUTE)
    }
}
