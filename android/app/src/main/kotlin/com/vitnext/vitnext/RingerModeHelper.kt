package com.vitnext.vitnext

import android.content.Context
import android.media.AudioManager

/**
 * Temporarily switches the device to vibrate-only during class,
 * then restores the previous ringer mode when class ends.
 *
 * Persists pending restore across process death so a killed service
 * does not leave the phone stuck on vibrate.
 */
object RingerModeHelper {
    private const val PREFS_NAME = ClassLiveMonitorService.PREFS_NAME
    private const val KEY_SAVED_RINGER = "flutter.class_focus_saved_ringer"
    private const val KEY_APPLIED = "flutter.class_focus_ringer_applied"

    private var savedRingerMode: Int? = null
    private var appliedByApp = false

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    private fun loadPersistedState(context: Context) {
        if (appliedByApp) return
        val p = prefs(context)
        appliedByApp = FlutterPrefs.getBool(p, KEY_APPLIED, false)
        if (appliedByApp && savedRingerMode == null && p.contains(KEY_SAVED_RINGER)) {
            savedRingerMode = p.getInt(KEY_SAVED_RINGER, AudioManager.RINGER_MODE_NORMAL)
        }
    }

    private fun persistState(context: Context) {
        prefs(context).edit()
            .putInt(KEY_SAVED_RINGER, savedRingerMode ?: AudioManager.RINGER_MODE_NORMAL)
            .putString(KEY_APPLIED, if (appliedByApp) "true" else "false")
            .apply()
    }

    private fun clearPersistedState(context: Context) {
        prefs(context).edit()
            .remove(KEY_SAVED_RINGER)
            .putString(KEY_APPLIED, "false")
            .apply()
    }

    fun applyVibrateMode(context: Context): Boolean {
        loadPersistedState(context)
        return try {
            val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            if (!appliedByApp) {
                savedRingerMode = audioManager.ringerMode
            }
            audioManager.ringerMode = AudioManager.RINGER_MODE_VIBRATE
            appliedByApp = true
            persistState(context)
            true
        } catch (_: Exception) {
            false
        }
    }

    fun restore(context: Context) {
        loadPersistedState(context)
        if (!appliedByApp) return
        try {
            val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            savedRingerMode?.let { audioManager.ringerMode = it }
        } catch (_: Exception) {
            // Ignore restore failures.
        }
        savedRingerMode = null
        appliedByApp = false
        clearPersistedState(context)
    }

    /** Called after reboot if vibrate was applied before the process died. */
    fun restoreIfNeeded(context: Context) {
        loadPersistedState(context)
        if (appliedByApp) {
            restore(context)
        }
    }

    fun isApplied(): Boolean = appliedByApp
}
