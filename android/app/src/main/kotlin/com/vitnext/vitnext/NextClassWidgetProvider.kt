package com.vitnext.vitnext

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject

class NextClassWidgetProvider : AppWidgetProvider() {

    companion object {
        const val PREFS_NAME = "FlutterSharedPreferences"
        const val KEY_STATUS = "flutter.widget_status"
        const val KEY_COURSE_NAME = "flutter.widget_course_name"
        const val KEY_COURSE_CODE = "flutter.widget_course_code"
        const val KEY_FACULTY = "flutter.widget_faculty"
        const val KEY_TIME = "flutter.widget_time"
        const val KEY_ROOM = "flutter.widget_room"
        const val KEY_START_HOUR = "flutter.widget_start_hour"
        const val KEY_START_MINUTE = "flutter.widget_start_minute"
        const val KEY_END_HOUR = "flutter.widget_end_hour"
        const val KEY_END_MINUTE = "flutter.widget_end_minute"
        const val KEY_LINKED_COURSE_ID = "flutter.widget_linked_course_id"
        const val KEY_SCHEDULE_DATE = "flutter.widget_schedule_date"
        const val KEY_TARGET_MILLIS = "flutter.widget_target_millis"
        const val KEY_BOUNDARY_MILLIS = "flutter.widget_boundary_millis"
        const val KEY_QUEUE_JSON = "flutter.widget_queue_json"
        const val KEY_QUEUE_INDEX = "flutter.widget_queue_index"
        const val KEY_HOLIDAY_LABEL = "flutter.widget_holiday_label"
        const val KEY_HOLIDAY_TYPE = "flutter.widget_holiday_type"
        const val KEY_CANCELLED_KEYS = "flutter.widget_cancelled_keys"
        const val KEY_PENDING_CANCEL_TOGGLE = "flutter.pending_widget_cancel_toggle"
        const val KEY_PENDING_CANCEL_KEY = "flutter.pending_widget_cancel_key"
        const val KEY_DAY_COMPLETE = "flutter.widget_day_complete"
        const val KEY_NO_CLASSES = "flutter.widget_no_classes"

        const val ACTION_CANCEL_NEXT = "com.vitnext.CANCEL_NEXT_CLASS"
        const val ACTION_SHOW_NEXT = "com.vitnext.SHOW_NEXT_CLASS"
        const val ACTION_BOUNDARY = "com.vitnext.WIDGET_BOUNDARY"

        private const val BOUNDARY_REQUEST = 42011

        private val OPEN_FLAGS =
            Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            ACTION_SHOW_NEXT -> {
                try {
                    handleShowNext(context)
                } catch (_: Exception) {
                }
                return
            }
            ACTION_CANCEL_NEXT -> {
                try {
                    handleCancelToggle(context)
                } catch (_: Exception) {
                }
                return
            }
            ACTION_BOUNDARY -> {
                try {
                    refreshAllWidgets(context)
                    scheduleBoundaryAlarm(context)
                } catch (_: Exception) {
                }
                return
            }
        }
        super.onReceive(context, intent)
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            try {
                updateWidget(context, appWidgetManager, appWidgetId)
            } catch (_: Exception) {
                val fallback = RemoteViews(context.packageName, R.layout.next_class_widget_preview)
                try {
                    val openIntent = Intent(context, MainActivity::class.java).apply {
                        flags = OPEN_FLAGS
                    }
                    val pending = PendingIntent.getActivity(
                        context, 0, openIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    fallback.setOnClickPendingIntent(R.id.widget_root, pending)
                } catch (_: Exception) {
                }
                appWidgetManager.updateAppWidget(appWidgetId, fallback)
            }
        }
        scheduleBoundaryAlarm(context)
    }

    private fun handleShowNext(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        // Empty / holiday / day-complete states do not browse future days.
        if (isStaticDayState(prefs)) {
            refreshAllWidgets(context)
            return
        }

        val queue = readQueue(prefs)
        if (queue.isEmpty()) {
            refreshAllWidgets(context)
            return
        }

        val cancelled = readCancelledKeys(prefs)
        val currentIndex = readPrefInt(prefs, KEY_QUEUE_INDEX, 0)
        val nextIndex = findNextNonCancelledIndex(queue, cancelled, currentIndex + 1)
            ?: findNextNonCancelledIndex(queue, cancelled, 0)
            ?: (currentIndex % queue.size)

        prefs.edit().putInt(KEY_QUEUE_INDEX, nextIndex).apply()
        writeLegacyKeysFromQueueItem(prefs, queue[nextIndex])
        refreshAllWidgets(context)
    }

    private fun handleCancelToggle(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        if (isStaticDayState(prefs)) {
            refreshAllWidgets(context)
            return
        }

        val queue = readQueue(prefs)
        val index = readPrefInt(prefs, KEY_QUEUE_INDEX, 0)
        if (queue.isEmpty() || index !in queue.indices) {
            refreshAllWidgets(context)
            return
        }

        val item = queue[index]
        val courseId = item.optString("linkedCourseId", "")
        val scheduleDate = item.optString("scheduleDate", "")
        if (courseId.isBlank() || scheduleDate.isBlank()) {
            refreshAllWidgets(context)
            return
        }

        val key = "$scheduleDate|$courseId"
        val cancelled = readCancelledKeys(prefs).toMutableSet()
        if (cancelled.contains(key)) {
            cancelled.remove(key)
        } else {
            cancelled.add(key)
        }

        prefs.edit()
            .putString(KEY_CANCELLED_KEYS, JSONArray(cancelled.toList()).toString())
            .putString(KEY_PENDING_CANCEL_TOGGLE, "true")
            .putString(KEY_PENDING_CANCEL_KEY, key)
            .apply()

        writeLegacyKeysFromQueueItem(prefs, item)
        refreshAllWidgets(context)
    }

    private fun refreshAllWidgets(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(ComponentName(context, NextClassWidgetProvider::class.java))
        if (ids.isNotEmpty()) {
            onUpdate(context, manager, ids)
        }
    }

    private fun isStaticDayState(prefs: SharedPreferences): Boolean {
        val holidayType = prefs.getString(KEY_HOLIDAY_TYPE, null)?.trim().orEmpty()
        if (holidayType == "exam" || holidayType == "holiday" || holidayType == "break") {
            return true
        }
        if (readPrefBool(prefs, KEY_DAY_COMPLETE, false)) return true
        if (readPrefBool(prefs, KEY_NO_CLASSES, false)) return true
        val status = prefs.getString(KEY_STATUS, null)
        return status == "day_complete" ||
            status == "no_classes" ||
            status == "holiday" ||
            status == "exam" ||
            status == "break" ||
            status == "free"
    }

    private fun updateWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val views = RemoteViews(context.packageName, R.layout.next_class_widget)

        val holidayType = prefs.getString(KEY_HOLIDAY_TYPE, null)?.trim().orEmpty()
        val dayCompleteFlag = readPrefBool(prefs, KEY_DAY_COMPLETE, false)
        val noClassesFlag = readPrefBool(prefs, KEY_NO_CLASSES, false)
        val status = prefs.getString(KEY_STATUS, null).orEmpty()
        var queue = readQueue(prefs)
        val cancelled = readCancelledKeys(prefs)

        // Lightweight local recompute so class start/end boundaries work without Flutter.
        if (holidayType.isEmpty() &&
            status != "holiday" &&
            status != "exam" &&
            status != "break" &&
            !noClassesFlag
        ) {
            queue = recomputeTodayQueueStatuses(queue)
            if (queue.isNotEmpty()) {
                val boundary = queue
                    .filter {
                        val s = it.optString("status")
                        s == "current" || s == "next"
                    }
                    .mapNotNull { it.optLong("targetMillis").takeIf { ms -> ms > System.currentTimeMillis() } }
                    .minOrNull()
                val editor = prefs.edit().putString(KEY_QUEUE_JSON, JSONArray(queue).toString())
                if (boundary != null) {
                    editor.putLong(KEY_BOUNDARY_MILLIS, boundary)
                } else {
                    editor.remove(KEY_BOUNDARY_MILLIS)
                }
                editor.apply()
            }
        }

        val liveCurrent = queue.firstOrNull {
            !isItemCancelled(it, cancelled) && it.optString("status") == "current"
        }
        val liveNext = queue.firstOrNull {
            !isItemCancelled(it, cancelled) && it.optString("status") == "next"
        }
        val hasActiveToday = queue.any {
            !isItemCancelled(it, cancelled) &&
                it.optString("status") != "completed"
        }
        val computedDayComplete = !noClassesFlag &&
            holidayType.isEmpty() &&
            liveCurrent == null &&
            liveNext == null &&
            (dayCompleteFlag ||
                status == "day_complete" ||
                status == "free" ||
                (queue.isNotEmpty() && !hasActiveToday))

        when {
            holidayType == "exam" || status == "exam" -> {
                bindExamState(views, prefs)
                hideActions(views)
            }
            holidayType == "break" || status == "break" -> {
                bindBreakState(views, prefs)
                hideActions(views)
            }
            holidayType == "holiday" || status == "holiday" -> {
                bindHolidayState(views, prefs)
                hideActions(views)
            }
            noClassesFlag || status == "no_classes" -> {
                bindNoClassesState(views)
                hideActions(views)
            }
            computedDayComplete -> {
                bindDayCompleteState(views)
                hideActions(views)
                prefs.edit()
                    .putString(KEY_DAY_COMPLETE, "true")
                    .putString(KEY_STATUS, "day_complete")
                    .remove(KEY_BOUNDARY_MILLIS)
                    .apply()
            }
            liveCurrent != null || liveNext != null || queue.isNotEmpty() -> {
                val focus = liveCurrent ?: liveNext
                var index = if (focus != null) {
                    queue.indexOf(focus).takeIf { it >= 0 }
                        ?: readPrefInt(prefs, KEY_QUEUE_INDEX, 0)
                } else {
                    readPrefInt(prefs, KEY_QUEUE_INDEX, 0)
                }
                if (index !in queue.indices) index = 0
                if (isItemCancelled(queue[index], cancelled)) {
                    index = findNextNonCancelledIndex(queue, cancelled, index)
                        ?: findNextNonCancelledIndex(queue, cancelled, 0)
                        ?: index
                }
                prefs.edit().putInt(KEY_QUEUE_INDEX, index).apply()

                val item = liveCurrent ?: liveNext ?: queue[index]
                val isCancelled = isItemCancelled(item, cancelled)
                bindClassFromJson(views, item, isCancelled)
                // No multi-day Next browsing — Cancel/Restore only for today's focused class.
                bindActionButtons(context, views, item, isCancelled, hasMultiple = false)
                writeLegacyKeysFromQueueItem(prefs, item)
            }
            else -> {
                bindNoClassesState(views)
                hideActions(views)
            }
        }

        bindOpenApp(context, views)
        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    /**
     * Re-stamp today's queue statuses from wall clock so the widget can advance
     * at class boundaries without Flutter running.
     */
    private fun recomputeTodayQueueStatuses(queue: List<JSONObject>): List<JSONObject> {
        if (queue.isEmpty()) return queue
        val cal = java.util.Calendar.getInstance()
        val nowMinutes = cal.get(java.util.Calendar.HOUR_OF_DAY) * 60 +
            cal.get(java.util.Calendar.MINUTE)

        val updated = queue.map { JSONObject(it.toString()) }
        var nextFound = false
        for (item in updated) {
            if (item.optString("status") == "cancelled") continue
            val startHour = item.optInt("startHour", -1)
            val endHour = item.optInt("endHour", -1)
            if (startHour < 0 || endHour < 0) continue

            val start = startHour * 60 + item.optInt("startMinute", 0)
            val end = endHour * 60 + item.optInt("endMinute", 0)

            when {
                end <= nowMinutes -> item.put("status", "completed")
                start <= nowMinutes && nowMinutes < end -> {
                    item.put("status", "current")
                    nextFound = true
                    val endCal = java.util.Calendar.getInstance().apply {
                        set(java.util.Calendar.HOUR_OF_DAY, endHour)
                        set(java.util.Calendar.MINUTE, item.optInt("endMinute", 0))
                        set(java.util.Calendar.SECOND, 0)
                        set(java.util.Calendar.MILLISECOND, 0)
                    }
                    item.put("targetMillis", endCal.timeInMillis)
                }
                start > nowMinutes -> {
                    if (!nextFound) {
                        item.put("status", "next")
                        nextFound = true
                        val startCal = java.util.Calendar.getInstance().apply {
                            set(java.util.Calendar.HOUR_OF_DAY, startHour)
                            set(java.util.Calendar.MINUTE, item.optInt("startMinute", 0))
                            set(java.util.Calendar.SECOND, 0)
                            set(java.util.Calendar.MILLISECOND, 0)
                        }
                        item.put("targetMillis", startCal.timeInMillis)
                    } else {
                        item.put("status", "upcoming")
                    }
                }
            }
        }
        return updated
    }

    private fun bindExamState(views: RemoteViews, prefs: SharedPreferences) {
        val label = prefs.getString(KEY_HOLIDAY_LABEL, null)?.trim().orEmpty()
        views.setTextViewText(R.id.widget_status_badge, "EXAM")
        views.setTextViewText(R.id.widget_course_name, "Exam Day")
        views.setTextViewText(
            R.id.widget_course_code,
            if (label.isNotEmpty()) label else "Good Luck!"
        )
        views.setTextViewText(R.id.widget_countdown, "Good Luck!")
        views.setTextViewText(R.id.widget_time, "")
        views.setTextViewText(R.id.widget_room, "")
    }

    private fun bindBreakState(views: RemoteViews, prefs: SharedPreferences) {
        val label = prefs.getString(KEY_HOLIDAY_LABEL, null)?.trim().orEmpty()
        views.setTextViewText(R.id.widget_status_badge, "FREE")
        views.setTextViewText(R.id.widget_course_name, "No Classes Today")
        views.setTextViewText(
            R.id.widget_course_code,
            if (label.isNotEmpty()) label else "Enjoy your day!"
        )
        views.setTextViewText(R.id.widget_countdown, "")
        views.setTextViewText(R.id.widget_time, "")
        views.setTextViewText(R.id.widget_room, "")
    }

    private fun bindHolidayState(views: RemoteViews, prefs: SharedPreferences) {
        val label = prefs.getString(KEY_HOLIDAY_LABEL, null)?.trim().orEmpty()
        views.setTextViewText(R.id.widget_status_badge, "HOLIDAY")
        views.setTextViewText(R.id.widget_course_name, "Holiday Today")
        views.setTextViewText(
            R.id.widget_course_code,
            if (label.isNotEmpty()) label else "No Classes"
        )
        views.setTextViewText(R.id.widget_countdown, "No Classes")
        views.setTextViewText(R.id.widget_time, "")
        views.setTextViewText(R.id.widget_room, "")
    }

    private fun bindNoClassesState(views: RemoteViews) {
        views.setTextViewText(R.id.widget_status_badge, "FREE")
        views.setTextViewText(R.id.widget_course_name, "No Classes Today")
        views.setTextViewText(R.id.widget_course_code, "Enjoy your day!")
        views.setTextViewText(R.id.widget_countdown, "")
        views.setTextViewText(R.id.widget_time, "")
        views.setTextViewText(R.id.widget_room, "")
    }

    private fun bindDayCompleteState(views: RemoteViews) {
        views.setTextViewText(R.id.widget_status_badge, "FREE")
        views.setTextViewText(R.id.widget_course_name, "Today's Classes Completed")
        views.setTextViewText(R.id.widget_course_code, "See you tomorrow!")
        views.setTextViewText(R.id.widget_countdown, "")
        views.setTextViewText(R.id.widget_time, "")
        views.setTextViewText(R.id.widget_room, "")
    }

    private fun bindClassFromJson(views: RemoteViews, item: JSONObject, isCancelled: Boolean) {
        val status = item.optString("status", "upcoming")
        val courseName = item.optString("courseName", "")
        val courseCode = item.optString("courseCode", "")
        val faculty = item.optString("faculty", "")
        val time = item.optString("time", "")
        val room = item.optString("room", "")
        val targetMillis = item.optLong("targetMillis", -1L)

        when {
            isCancelled -> views.setTextViewText(R.id.widget_status_badge, "CANCELLED")
            status == "current" -> views.setTextViewText(R.id.widget_status_badge, "NOW")
            else -> views.setTextViewText(R.id.widget_status_badge, "NEXT")
        }

        views.setTextViewText(R.id.widget_course_name, courseName)
        views.setTextViewText(
            R.id.widget_course_code,
            listOf(courseCode, faculty).filter { it.isNotBlank() }.joinToString(" • ")
        )
        views.setTextViewText(R.id.widget_time, time)
        views.setTextViewText(R.id.widget_room, room)
        // Countdown only for the current class — never for next.
        views.setTextViewText(
            R.id.widget_countdown,
            when {
                isCancelled -> "Cancelled by Teacher"
                status == "current" -> calculateEndsIn(targetMillis)
                else -> ""
            }
        )
    }

    private fun bindClassFromPrefs(
        views: RemoteViews,
        prefs: SharedPreferences,
        status: String,
        courseName: String,
        targetMillis: Long,
        isCancelled: Boolean
    ) {
        val courseCode = prefs.getString(KEY_COURSE_CODE, null)
        val faculty = prefs.getString(KEY_FACULTY, null)
        val time = prefs.getString(KEY_TIME, null)
        val room = prefs.getString(KEY_ROOM, null)

        when {
            isCancelled -> views.setTextViewText(R.id.widget_status_badge, "CANCELLED")
            status == "current" -> views.setTextViewText(R.id.widget_status_badge, "NOW")
            else -> views.setTextViewText(R.id.widget_status_badge, "NEXT")
        }

        views.setTextViewText(R.id.widget_course_name, courseName)
        views.setTextViewText(
            R.id.widget_course_code,
            listOfNotNull(courseCode, faculty).filter { it.isNotBlank() }.joinToString(" • ")
        )
        views.setTextViewText(R.id.widget_time, time ?: "")
        views.setTextViewText(R.id.widget_room, room ?: "")
        views.setTextViewText(
            R.id.widget_countdown,
            when {
                isCancelled -> "Cancelled by Teacher"
                status == "current" -> calculateEndsIn(targetMillis)
                else -> ""
            }
        )
    }

    private fun bindActionButtons(
        context: Context,
        views: RemoteViews,
        item: JSONObject,
        isCancelled: Boolean,
        hasMultiple: Boolean
    ) {
        val courseId = item.optString("linkedCourseId", "")
        val canCancel = courseId.isNotBlank()

        if (hasMultiple) {
            views.setViewVisibility(R.id.widget_next_btn, View.VISIBLE)
            val nextIntent = Intent(context, NextClassWidgetProvider::class.java).apply {
                action = ACTION_SHOW_NEXT
            }
            val nextPending = PendingIntent.getBroadcast(
                context, 2, nextIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_next_btn, nextPending)
        } else {
            views.setViewVisibility(R.id.widget_next_btn, View.GONE)
        }

        if (canCancel) {
            views.setViewVisibility(R.id.widget_cancel_btn, View.VISIBLE)
            views.setTextViewText(R.id.widget_cancel_btn, if (isCancelled) "Restore" else "Cancel")
            val cancelIntent = Intent(context, NextClassWidgetProvider::class.java).apply {
                action = ACTION_CANCEL_NEXT
            }
            val cancelPending = PendingIntent.getBroadcast(
                context, 1, cancelIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_cancel_btn, cancelPending)
        } else {
            views.setViewVisibility(R.id.widget_cancel_btn, View.GONE)
        }

        views.setViewVisibility(
            R.id.widget_actions_row,
            if (hasMultiple || canCancel) View.VISIBLE else View.GONE
        )
    }

    private fun bindLegacyActionButtons(
        context: Context,
        views: RemoteViews,
        linkedCourseId: String?,
        isCancelled: Boolean
    ) {
        views.setViewVisibility(R.id.widget_next_btn, View.GONE)
        if (!linkedCourseId.isNullOrBlank()) {
            views.setViewVisibility(R.id.widget_actions_row, View.VISIBLE)
            views.setViewVisibility(R.id.widget_cancel_btn, View.VISIBLE)
            views.setTextViewText(R.id.widget_cancel_btn, if (isCancelled) "Restore" else "Cancel")
            val cancelIntent = Intent(context, NextClassWidgetProvider::class.java).apply {
                action = ACTION_CANCEL_NEXT
            }
            val cancelPending = PendingIntent.getBroadcast(
                context, 1, cancelIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_cancel_btn, cancelPending)
        } else {
            hideActions(views)
        }
    }

    private fun hideActions(views: RemoteViews) {
        views.setViewVisibility(R.id.widget_actions_row, View.GONE)
        views.setViewVisibility(R.id.widget_next_btn, View.GONE)
        views.setViewVisibility(R.id.widget_cancel_btn, View.GONE)
    }

    private fun bindOpenApp(context: Context, views: RemoteViews) {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = OPEN_FLAGS
        }
        val pendingIntent = PendingIntent.getActivity(
            context, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_status_badge, pendingIntent)
        views.setOnClickPendingIntent(R.id.widget_countdown, pendingIntent)
        views.setOnClickPendingIntent(R.id.widget_course_name, pendingIntent)
        views.setOnClickPendingIntent(R.id.widget_course_code, pendingIntent)
        views.setOnClickPendingIntent(R.id.widget_time, pendingIntent)
        views.setOnClickPendingIntent(R.id.widget_room, pendingIntent)
    }

    private fun writeLegacyKeysFromQueueItem(prefs: SharedPreferences, item: JSONObject) {
        val status = item.optString("status", "upcoming")
        val editor = prefs.edit()
            .putString(KEY_STATUS, status)
            .putString(KEY_COURSE_NAME, item.optString("courseName", ""))
            .putString(KEY_COURSE_CODE, item.optString("courseCode", ""))
            .putString(KEY_FACULTY, item.optString("faculty", ""))
            .putString(KEY_TIME, item.optString("time", ""))
            .putString(KEY_ROOM, item.optString("room", ""))
            .putLong(KEY_TARGET_MILLIS, item.optLong("targetMillis", -1L))

        val courseId = item.optString("linkedCourseId", "")
        val scheduleDate = item.optString("scheduleDate", "")
        if (courseId.isNotBlank()) {
            editor.putString(KEY_LINKED_COURSE_ID, courseId)
        } else {
            editor.remove(KEY_LINKED_COURSE_ID)
        }
        if (scheduleDate.isNotBlank()) {
            editor.putString(KEY_SCHEDULE_DATE, scheduleDate)
        } else {
            editor.remove(KEY_SCHEDULE_DATE)
        }

        if (item.has("startHour")) editor.putLong(KEY_START_HOUR, item.optLong("startHour"))
        if (item.has("startMinute")) editor.putLong(KEY_START_MINUTE, item.optLong("startMinute"))
        if (item.has("endHour")) editor.putLong(KEY_END_HOUR, item.optLong("endHour"))
        if (item.has("endMinute")) editor.putLong(KEY_END_MINUTE, item.optLong("endMinute"))

        val target = item.optLong("targetMillis", -1L)
        if (target > System.currentTimeMillis()) {
            editor.putLong(KEY_BOUNDARY_MILLIS, target)
        } else {
            editor.remove(KEY_BOUNDARY_MILLIS)
        }

        editor.apply()
    }

    /** Schedule a one-shot refresh at the next class start/end boundary. */
    private fun scheduleBoundaryAlarm(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val boundary = readPrefLong(prefs, KEY_BOUNDARY_MILLIS, -1L)
            .takeIf { it > 0 }
            ?: readPrefLong(prefs, KEY_TARGET_MILLIS, -1L)
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = PendingIntent.getBroadcast(
            context,
            BOUNDARY_REQUEST,
            Intent(context, NextClassWidgetProvider::class.java).apply { action = ACTION_BOUNDARY },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        if (boundary <= System.currentTimeMillis() + 2_000L) {
            try {
                am.cancel(pi)
            } catch (_: Exception) {
            }
            return
        }

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, boundary, pi)
            } else {
                am.set(AlarmManager.RTC_WAKEUP, boundary, pi)
            }
        } catch (_: Exception) {
            try {
                am.set(AlarmManager.RTC_WAKEUP, boundary, pi)
            } catch (_: Exception) {
            }
        }
    }

    private fun findNextNonCancelledIndex(
        queue: List<JSONObject>,
        cancelled: Set<String>,
        startIndex: Int
    ): Int? {
        if (queue.isEmpty()) return null
        val size = queue.size
        val start = ((startIndex % size) + size) % size
        for (offset in 0 until size) {
            val idx = (start + offset) % size
            if (!isItemCancelled(queue[idx], cancelled)) return idx
        }
        return null
    }

    private fun isItemCancelled(item: JSONObject, cancelled: Set<String>): Boolean {
        val courseId = item.optString("linkedCourseId", "")
        val scheduleDate = item.optString("scheduleDate", "")
        if (courseId.isBlank() || scheduleDate.isBlank()) {
            return item.optString("status", "") == "cancelled"
        }
        return cancelled.contains("$scheduleDate|$courseId") ||
            item.optString("status", "") == "cancelled"
    }

    private fun readQueue(prefs: SharedPreferences): List<JSONObject> {
        val raw = prefs.getString(KEY_QUEUE_JSON, null) ?: return emptyList()
        return try {
            val arr = JSONArray(raw)
            buildList {
                for (i in 0 until arr.length()) {
                    val obj = arr.optJSONObject(i) ?: continue
                    add(obj)
                }
            }
        } catch (_: Exception) {
            emptyList()
        }
    }

    private fun readCancelledKeys(prefs: SharedPreferences): Set<String> {
        val raw = prefs.getString(KEY_CANCELLED_KEYS, null) ?: return emptySet()
        return try {
            val arr = JSONArray(raw)
            buildSet {
                for (i in 0 until arr.length()) {
                    val key = arr.optString(i, "")
                    if (key.isNotBlank()) add(key)
                }
            }
        } catch (_: Exception) {
            emptySet()
        }
    }

    private fun readPrefInt(prefs: SharedPreferences, key: String, default: Int): Int {
        if (!prefs.contains(key)) return default
        return when (val value = prefs.all[key]) {
            is Int -> value
            is Long -> value.toInt()
            is String -> value.toIntOrNull() ?: default
            else -> default
        }
    }

    private fun readPrefLong(prefs: SharedPreferences, key: String, default: Long): Long {
        if (!prefs.contains(key)) return default
        return when (val value = prefs.all[key]) {
            is Long -> value
            is Int -> value.toLong()
            is String -> value.toLongOrNull() ?: default
            else -> default
        }
    }

    private fun readPrefBool(prefs: SharedPreferences, key: String, default: Boolean): Boolean {
        if (!prefs.contains(key)) return default
        return when (val value = prefs.all[key]) {
            is Boolean -> value
            is String -> value == "true"
            else -> default
        }
    }

    /** Remaining time for the current class only. */
    private fun calculateEndsIn(targetMillis: Long): String {
        if (targetMillis <= 0) return ""
        val diff = targetMillis - System.currentTimeMillis()
        if (diff <= 0) return "Ending now"
        val totalMinutes = (diff / (1000 * 60)).toInt()
        return "Ends in " + formatDuration(totalMinutes)
    }

    private fun formatDuration(totalMinutes: Int): String {
        val minutes = kotlin.math.abs(totalMinutes)
        if (minutes <= 0) return "0 min"
        val hours = minutes / 60
        val mins = minutes % 60
        return when {
            hours > 0 && mins > 0 -> "$hours hr $mins min"
            hours > 0 -> "$hours hr"
            else -> "$mins min"
        }
    }
}
