package dev.notify_pilot

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import org.json.JSONObject

class ScheduleManager(private val context: Context) {

    companion object {
        private const val PREFS_NAME = "notify_pilot_schedules"
        private const val KEY_SCHEDULE_IDS = "schedule_ids"
    }

    private val alarmManager: AlarmManager
        get() = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

    private val prefs: SharedPreferences
        get() = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    /**
     * Schedule a notification at an exact timestamp (milliseconds since epoch).
     */
    fun scheduleAt(
        id: Int,
        triggerAtMillis: Long,
        title: String?,
        body: String?,
        channelId: String?,
        groupKey: String?,
        deepLink: String?,
        payload: String?,
        actions: String? = null // JSON string of actions array
    ) {
        val metadata = buildMetadata(id, title, body, channelId, groupKey, deepLink, payload, actions, null)
        storeSchedule(id, metadata, triggerAtMillis)

        val pendingIntent = buildAlarmPendingIntent(id, metadata)
        setExactAlarm(triggerAtMillis, pendingIntent)
    }

    /**
     * Schedule a notification after a delay in milliseconds.
     */
    fun scheduleAfter(
        id: Int,
        delayMillis: Long,
        title: String?,
        body: String?,
        channelId: String?,
        groupKey: String?,
        deepLink: String?,
        payload: String?,
        actions: String? = null
    ) {
        val triggerAtMillis = System.currentTimeMillis() + delayMillis
        scheduleAt(id, triggerAtMillis, title, body, channelId, groupKey, deepLink, payload, actions)
    }

    /**
     * Schedule a cron-based notification.
     * The cron expression is stored so AlarmReceiver can send an event to Dart for re-scheduling.
     */
    fun scheduleCron(
        id: Int,
        triggerAtMillis: Long,
        cronExpression: String,
        title: String?,
        body: String?,
        channelId: String?,
        groupKey: String?,
        deepLink: String?,
        payload: String?,
        actions: String? = null
    ) {
        val metadata = buildMetadata(id, title, body, channelId, groupKey, deepLink, payload, actions, cronExpression)
        storeSchedule(id, metadata, triggerAtMillis)

        val pendingIntent = buildAlarmPendingIntent(id, metadata)
        setExactAlarm(triggerAtMillis, pendingIntent)
    }

    /**
     * Cancel a scheduled notification.
     */
    fun cancel(id: Int) {
        val intent = Intent(context, AlarmReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            context, id, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        alarmManager.cancel(pendingIntent)
        pendingIntent.cancel()
        removeSchedule(id)
    }

    /**
     * Returns all stored scheduled notification metadata as a list of maps.
     */
    fun getScheduled(): List<Map<String, Any?>> {
        val ids = getStoredScheduleIds()
        val results = mutableListOf<Map<String, Any?>>()

        for (id in ids) {
            val json = prefs.getString("schedule_$id", null) ?: continue
            try {
                val obj = JSONObject(json)
                val map = mutableMapOf<String, Any?>()
                map["id"] = obj.optInt("id")
                map["title"] = obj.optString("title", null)
                map["body"] = obj.optString("body", null)
                map["channelId"] = obj.optString("channelId", null)
                map["groupKey"] = obj.optString("groupKey", null)
                map["deepLink"] = obj.optString("deepLink", null)
                map["payload"] = obj.optString("payload", null)
                map["triggerAtMillis"] = obj.optLong("triggerAtMillis")
                map["cronExpression"] = obj.optString("cronExpression", null)
                results.add(map)
            } catch (_: Exception) {
                // Skip malformed entries
            }
        }
        return results
    }

    /**
     * Re-registers all stored schedules (called from BootReceiver).
     */
    fun rescheduleAll() {
        val ids = getStoredScheduleIds()
        val now = System.currentTimeMillis()

        for (id in ids) {
            val json = prefs.getString("schedule_$id", null) ?: continue
            try {
                val obj = JSONObject(json)
                val triggerAt = obj.getLong("triggerAtMillis")

                // Only reschedule future alarms
                if (triggerAt > now) {
                    val pendingIntent = buildAlarmPendingIntent(id, json)
                    setExactAlarm(triggerAt, pendingIntent)
                } else {
                    // Expired; remove it
                    removeSchedule(id)
                }
            } catch (_: Exception) {
                removeSchedule(id)
            }
        }
    }

    private fun setExactAlarm(triggerAtMillis: Long, pendingIntent: PendingIntent) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent
            )
        } else {
            alarmManager.setExact(
                AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent
            )
        }
    }

    private fun buildAlarmPendingIntent(id: Int, metadata: String): PendingIntent {
        val intent = Intent(context, AlarmReceiver::class.java).apply {
            action = "dev.notify_pilot.ALARM"
            putExtra("schedule_metadata", metadata)
            putExtra("schedule_id", id)
        }
        return PendingIntent.getBroadcast(
            context, id, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun buildMetadata(
        id: Int,
        title: String?,
        body: String?,
        channelId: String?,
        groupKey: String?,
        deepLink: String?,
        payload: String?,
        actions: String?,
        cronExpression: String?
    ): String {
        val obj = JSONObject().apply {
            put("id", id)
            put("title", title ?: JSONObject.NULL)
            put("body", body ?: JSONObject.NULL)
            put("channelId", channelId ?: JSONObject.NULL)
            put("groupKey", groupKey ?: JSONObject.NULL)
            put("deepLink", deepLink ?: JSONObject.NULL)
            put("payload", payload ?: JSONObject.NULL)
            put("actions", actions ?: JSONObject.NULL)
            put("cronExpression", cronExpression ?: JSONObject.NULL)
        }
        return obj.toString()
    }

    private fun storeSchedule(id: Int, metadata: String, triggerAtMillis: Long) {
        // Add triggerAtMillis to the metadata for boot reschedule
        val obj = JSONObject(metadata)
        obj.put("triggerAtMillis", triggerAtMillis)
        val fullMetadata = obj.toString()

        val ids = getStoredScheduleIds().toMutableSet()
        ids.add(id)
        prefs.edit()
            .putString("schedule_$id", fullMetadata)
            .putStringSet(KEY_SCHEDULE_IDS, ids.map { it.toString() }.toSet())
            .apply()
    }

    private fun removeSchedule(id: Int) {
        val ids = getStoredScheduleIds().toMutableSet()
        ids.remove(id)
        prefs.edit()
            .remove("schedule_$id")
            .putStringSet(KEY_SCHEDULE_IDS, ids.map { it.toString() }.toSet())
            .apply()
    }

    private fun getStoredScheduleIds(): Set<Int> {
        val stringIds = prefs.getStringSet(KEY_SCHEDULE_IDS, emptySet()) ?: emptySet()
        return stringIds.mapNotNull { it.toIntOrNull() }.toSet()
    }
}
