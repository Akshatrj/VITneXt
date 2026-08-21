package com.vitnext.vitnext

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat

/** Restarts live class monitoring after device reboot if the user enabled it. */
class ClassLiveBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != Intent.ACTION_BOOT_COMPLETED &&
            intent?.action != Intent.ACTION_LOCKED_BOOT_COMPLETED
        ) {
            return
        }

        val prefs = context.getSharedPreferences(
            ClassLiveMonitorService.PREFS_NAME,
            Context.MODE_PRIVATE
        )
        val autoSilent = FlutterPrefs.getBool(prefs, ClassLiveMonitorService.KEY_AUTO_SILENT, false)
        RingerModeHelper.restoreIfNeeded(context)
        if (!autoSilent) return

        DayRolloverScheduler.schedule(context)

        val serviceIntent = Intent(context, ClassLiveMonitorService::class.java).apply {
            action = ClassLiveMonitorService.ACTION_SYNC
        }
        ContextCompat.startForegroundService(context, serviceIntent)
    }
}
