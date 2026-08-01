package com.vitnextclass.vit_nextclass

import android.content.Context
import android.media.AudioManager

/**
 * Temporarily switches the device to vibrate-only (silent ringtone, vibration on)
 * during class, then restores the previous ringer mode.
 */
object RingerModeHelper {
    private var savedRingerMode: Int? = null
    private var appliedByApp = false

    fun applyVibrateMode(context: Context): Boolean {
        return try {
            val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            if (!appliedByApp) {
                savedRingerMode = audioManager.ringerMode
            }
            audioManager.ringerMode = AudioManager.RINGER_MODE_VIBRATE
            appliedByApp = true
            true
        } catch (_: Exception) {
            false
        }
    }

    fun restore(context: Context) {
        if (!appliedByApp) return
        try {
            val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            savedRingerMode?.let { audioManager.ringerMode = it }
        } catch (_: Exception) {
            // Ignore restore failures
        }
        savedRingerMode = null
        appliedByApp = false
    }

    fun isApplied(): Boolean = appliedByApp
}
