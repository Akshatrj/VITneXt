package com.vitnextclass.vit_nextclass

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat

/** Fires at class start/end/pre-class boundaries scheduled by [ClassLiveScheduler]. */
class ClassLiveAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val serviceIntent = Intent(context, ClassLiveMonitorService::class.java).apply {
            action = ClassLiveMonitorService.ACTION_BOUNDARY
        }
        ContextCompat.startForegroundService(context, serviceIntent)
    }
}
