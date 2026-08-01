package com.vitnextclass.vit_nextclass

import android.content.SharedPreferences

/** Reads bool prefs written by Flutter shared_preferences (string "true"/"false") or native putBoolean. */
object FlutterPrefs {
    fun getBool(prefs: SharedPreferences, key: String, default: Boolean = false): Boolean {
        if (!prefs.contains(key)) return default
        return when (val value = prefs.all[key]) {
            is Boolean -> value
            is String -> value == "true"
            else -> default
        }
    }
}
