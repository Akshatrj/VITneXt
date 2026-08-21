package com.vitnext.vitnext

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat

/**
 * Fires at local midnight (and on date/timezone changes) to refresh widget + class focus
 * without requiring the user to open the app.
 */
class DayRolloverReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action
        if (action != DayRolloverScheduler.ACTION &&
            action != Intent.ACTION_DATE_CHANGED
        ) {
            return
        }

        try {
            val prefs = context.getSharedPreferences(
                NextClassWidgetProvider.PREFS_NAME,
                Context.MODE_PRIVATE
            )
            prefs.edit()
                .putString(NextClassWidgetProvider.KEY_PENDING_SCHEDULE_SYNC, "true")
                .apply()

            val serviceIntent = Intent(context, BackgroundMaintenanceService::class.java)
            ContextCompat.startForegroundService(context, serviceIntent)

            DayRolloverScheduler.schedule(context)
        } catch (_: Exception) {
            // Never crash from a rollover tick.
        }
    }
}
