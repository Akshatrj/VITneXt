package com.vitnext.vitnext

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.UUID

/**
 * Reads/writes [overrides.json] in the Flutter app documents directory so widget
 * actions and the Flutter app share one cancellation source of truth.
 */
object ScheduleOverrideStorage {
    private const val OVERRIDES_FILE = "overrides.json"
    private const val OVERRIDES_BACKUP = "overrides.json.bak"

    private fun dataDir(context: Context): File =
        File(context.applicationInfo.dataDir, "app_flutter")

    private fun overridesFile(context: Context): File =
        File(dataDir(context), OVERRIDES_FILE)

    private fun overridesBackupFile(context: Context): File =
        File(dataDir(context), OVERRIDES_BACKUP)

    /**
     * Toggle cancel override for one course on one calendar day.
     * Returns whether the class is now cancelled, or null if the on-disk file
     * could not be read safely (no mutation performed).
     */
    fun toggleCancellation(context: Context, scheduleDate: String, courseId: String): Boolean? {
        val overrides = readOverridesOrNull(context) ?: return null

        val existingIndex = overrides.indexOfFirst { entry ->
            entry.optString("type") == "cancelled" &&
                entry.optString("linkedCourseId") == courseId &&
                sameCalendarDay(entry.optString("date"), scheduleDate)
        }

        if (existingIndex >= 0) {
            overrides.removeAt(existingIndex)
            writeOverrides(context, overrides)
            return false
        }

        val entry = JSONObject()
        entry.put("id", UUID.randomUUID().toString())
        entry.put("date", isoDateFor(scheduleDate))
        entry.put("type", "cancelled")
        entry.put("linkedCourseId", courseId)
        entry.put("reason", "Cancelled by Teacher")
        overrides.add(entry)
        writeOverrides(context, overrides)
        return true
    }

    /**
     * Keys formatted as `yyyy-MM-dd|courseId` for widget cancelled-set display.
     * Returns null when overrides cannot be read safely (caller must not treat as empty).
     */
    fun cancelledKeysForDate(context: Context, scheduleDate: String): Set<String>? {
        val overrides = readOverridesOrNull(context) ?: return null
        val keys = mutableSetOf<String>()
        for (entry in overrides) {
            if (entry.optString("type") != "cancelled") continue
            val courseId = entry.optString("linkedCourseId", "")
            if (courseId.isBlank()) continue
            val dateKey = calendarDayKey(entry.optString("date"))
            if (dateKey == scheduleDate) {
                keys.add("$scheduleDate|$courseId")
            }
        }
        return keys
    }

    /**
     * Returns the override list, or null if the on-disk file exists but cannot be parsed
     * (and no usable backup). Missing file → empty mutable list.
     */
    private fun readOverridesOrNull(context: Context): MutableList<JSONObject>? {
        val file = overridesFile(context)
        if (!file.exists()) {
            val backup = overridesBackupFile(context)
            if (backup.exists()) {
                parseOverridesFile(backup)?.let { return it }
            }
            return mutableListOf()
        }
        parseOverridesFile(file)?.let { return it }
        return parseOverridesFile(overridesBackupFile(context))
    }

    private fun parseOverridesFile(file: File): MutableList<JSONObject>? {
        if (!file.exists()) return null
        return try {
            val array = JSONArray(file.readText())
            val list = mutableListOf<JSONObject>()
            for (i in 0 until array.length()) {
                list.add(array.getJSONObject(i))
            }
            list
        } catch (_: Exception) {
            null
        }
    }

    private fun writeOverrides(context: Context, overrides: List<JSONObject>) {
        val dir = dataDir(context)
        dir.mkdirs()
        val file = overridesFile(context)
        val backup = overridesBackupFile(context)
        val array = JSONArray()
        for (entry in overrides) {
            array.put(entry)
        }
        val content = array.toString()

        // Preserve previous good file as .bak (matches Flutter LocalStorage).
        if (file.exists()) {
            try {
                file.copyTo(backup, overwrite = true)
            } catch (_: Exception) {
            }
        }

        // Atomic-ish replace: write temp then rename over the target.
        val tmp = File(dir, "$OVERRIDES_FILE.tmp")
        tmp.writeText(content)
        if (!tmp.renameTo(file)) {
            file.writeText(content)
            tmp.delete()
        }
    }

    private fun isoDateFor(scheduleDate: String): String {
        val parts = scheduleDate.split("-")
        if (parts.size != 3) return scheduleDate
        return "${parts[0]}-${parts[1]}-${parts[2]}T00:00:00.000"
    }

    private fun calendarDayKey(rawDate: String): String {
        if (rawDate.length >= 10 && rawDate[4] == '-' && rawDate[7] == '-') {
            return rawDate.substring(0, 10)
        }
        return rawDate
    }

    private fun sameCalendarDay(rawDate: String, scheduleDate: String): Boolean {
        return calendarDayKey(rawDate) == scheduleDate
    }
}
