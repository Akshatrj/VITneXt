package com.vitnextclass.vit_nextclass

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import java.util.Calendar

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
        const val ACTION_CANCEL_NEXT = "com.vitnextclass.CANCEL_NEXT_CLASS"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_CANCEL_NEXT) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit().putBoolean("flutter.pending_widget_cancel", true).apply()

            val openIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            context.startActivity(openIntent)
            return
        }
        super.onReceive(context, intent)
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

    private fun updateWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val views = RemoteViews(context.packageName, R.layout.next_class_widget)

        val status = prefs.getString(KEY_STATUS, null)
        val courseName = prefs.getString(KEY_COURSE_NAME, null)
        val courseCode = prefs.getString(KEY_COURSE_CODE, null)
        val faculty = prefs.getString(KEY_FACULTY, null)
        val time = prefs.getString(KEY_TIME, null)
        val room = prefs.getString(KEY_ROOM, null)
        val startHour = prefs.getLong(KEY_START_HOUR, -1).toInt()
        val startMinute = prefs.getLong(KEY_START_MINUTE, -1).toInt()
        val endHour = prefs.getLong(KEY_END_HOUR, -1).toInt()
        val endMinute = prefs.getLong(KEY_END_MINUTE, -1).toInt()
        val linkedCourseId = prefs.getString(KEY_LINKED_COURSE_ID, null)

        if (courseName != null && status != null) {
            val countdown = calculateCountdown(status, startHour, startMinute, endHour, endMinute)

            when (status) {
                "current" -> {
                    views.setTextViewText(R.id.widget_status_badge, "NOW")
                    views.setInt(R.id.widget_status_badge, "setBackgroundResource", R.drawable.widget_badge_bg)
                }
                "next" -> {
                    views.setTextViewText(R.id.widget_status_badge, "NEXT")
                    views.setInt(R.id.widget_status_badge, "setBackgroundResource", R.drawable.widget_badge_next_bg)
                }
                else -> {
                    views.setTextViewText(R.id.widget_status_badge, "UPCOMING")
                    views.setInt(R.id.widget_status_badge, "setBackgroundResource", R.drawable.widget_badge_next_bg)
                }
            }

            views.setTextViewText(R.id.widget_course_name, courseName)
            views.setTextViewText(R.id.widget_course_code, "$courseCode • $faculty")
            views.setTextViewText(R.id.widget_time, time ?: "")
            views.setTextViewText(R.id.widget_room, room ?: "")
            views.setTextViewText(R.id.widget_countdown, countdown)

            if (status == "next" && linkedCourseId != null) {
                views.setViewVisibility(R.id.widget_cancel_btn, View.VISIBLE)
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
        } else {
            views.setTextViewText(R.id.widget_status_badge, "FREE")
            views.setTextViewText(R.id.widget_course_name, "No upcoming classes")
            views.setTextViewText(R.id.widget_course_code, "Open app to set up your timetable")
            views.setTextViewText(R.id.widget_time, "")
            views.setTextViewText(R.id.widget_room, "")
            views.setTextViewText(R.id.widget_countdown, "🎉")
            views.setViewVisibility(R.id.widget_cancel_btn, View.GONE)
        }

        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            context, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    private fun calculateCountdown(
        status: String,
        startHour: Int, startMinute: Int,
        endHour: Int, endMinute: Int
    ): String {
        if (startHour < 0 || endHour < 0) return ""

        val cal = Calendar.getInstance()
        val nowMinutes = cal.get(Calendar.HOUR_OF_DAY) * 60 + cal.get(Calendar.MINUTE)

        return when (status) {
            "current" -> {
                val remaining = (endHour * 60 + endMinute) - nowMinutes
                if (remaining > 0) "Ends in $remaining min" else "Ending now"
            }
            "next" -> {
                val until = (startHour * 60 + startMinute) - nowMinutes
                when {
                    until <= 0 -> "Starting now"
                    until < 60 -> "Starts in $until min"
                    else -> {
                        val hours = until / 60
                        val mins = until % 60
                        if (mins > 0) "In ${hours}h ${mins}m" else "In ${hours}h"
                    }
                }
            }
            else -> ""
        }
    }
}
