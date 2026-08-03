package com.vitnext.vitnext

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.SystemClock

/**
 * Periodic self-heal for home-screen widgets.
 * Re-renders from SharedPreferences without requiring Flutter to be alive.
 */
class WidgetHealReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        try {
            refreshWidgets(context)
            schedule(context)
        } catch (_: Exception) {
            // Never crash the process from a heal tick.
        }
    }

    companion object {
        const val ACTION = "com.vitnext.WIDGET_HEAL"
        private const val REQUEST_CODE = 42001
        private const val INTERVAL_MS = 30 * 60 * 1000L // 30 minutes

        fun schedule(context: Context) {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val pi = pendingIntent(context)
            val triggerAt = SystemClock.elapsedRealtime() + INTERVAL_MS
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    am.setAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, pi)
                } else {
                    am.set(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, pi)
                }
            } catch (_: Exception) {
                am.set(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, pi)
            }
        }

        fun refreshWidgets(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, NextClassWidgetProvider::class.java)
            val ids = manager.getAppWidgetIds(component)
            if (ids.isEmpty()) return
            val provider = NextClassWidgetProvider()
            provider.onUpdate(context, manager, ids)

            val prefs = context.getSharedPreferences(
                NextClassWidgetProvider.PREFS_NAME,
                Context.MODE_PRIVATE
            )
            prefs.edit()
                .putLong("flutter.widget_last_native_heal_millis", System.currentTimeMillis())
                .apply()
        }

        private fun pendingIntent(context: Context): PendingIntent {
            val intent = Intent(context, WidgetHealReceiver::class.java).apply {
                action = ACTION
            }
            return PendingIntent.getBroadcast(
                context,
                REQUEST_CODE,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }
    }
}
