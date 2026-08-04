package com.vitnext.vitnext

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Non-exported entry point for widget Cancel / Show-next / Boundary actions.
 * PendingIntents created by this app can still reach it; third-party apps cannot.
 */
class NextClassWidgetActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        try {
            NextClassWidgetProvider.handleWidgetAction(context, intent)
        } catch (_: Exception) {
            // Never crash the process from a widget action.
        }
    }
}
