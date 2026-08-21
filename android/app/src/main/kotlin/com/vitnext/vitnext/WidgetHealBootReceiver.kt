package com.vitnext.vitnext

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Reschedules widget heal after device reboot. */
class WidgetHealBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != Intent.ACTION_BOOT_COMPLETED &&
            intent?.action != Intent.ACTION_LOCKED_BOOT_COMPLETED
        ) {
            return
        }
        try {
            WidgetHealReceiver.schedule(context)
            WidgetHealReceiver.refreshWidgets(context)
            DayRolloverScheduler.schedule(context)
        } catch (_: Exception) {
        }
    }
}
