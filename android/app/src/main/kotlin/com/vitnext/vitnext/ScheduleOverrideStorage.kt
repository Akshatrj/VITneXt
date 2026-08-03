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

    private fun dataDir(context: Context): File =
        File(context.applicationInfo.dataDir, "app_flutter")

    private fun overridesFile(context: Context): File =
        File(dataDir(context), OVERRIDES_FILE)

    /** Toggle cancel override for one course on one calendar day. Returns true if now cancelled. */
    fun toggleCancellation(context: Context, scheduleDate: String, courseId: String): Boolean {
        val overrides = readOverrides(context)
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

    /** Keys formatted as `yyyy-MM-dd|courseId` for widget cancelled-set display. */
    fun cancelledKeysForDate(context: Context, scheduleDate: String): Set<String> {
        val keys = mutableSetOf<String>()
        for (entry in readOverrides(context)) {
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

    private fun readOverrides(context: Context): MutableList<JSONObject> {
        val file = overridesFile(context)
        if (!file.exists()) return mutableListOf()
        return try {
            val array = JSONArray(file.readText())
            val list = mutableListOf<JSONObject>()
            for (i in 0 until array.length()) {
                list.add(array.getJSONObject(i))
            }
            list
        } catch (_: Exception) {
            mutableListOf()
        }
    }

    private fun writeOverrides(context: Context, overrides: List<JSONObject>) {
        val file = overridesFile(context)
        dataDir(context).mkdirs()
        val array = JSONArray()
        for (entry in overrides) {
            array.put(entry)
        }
        file.writeText(array.toString())
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
