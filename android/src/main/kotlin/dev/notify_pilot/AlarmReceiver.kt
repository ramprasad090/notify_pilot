package dev.notify_pilot

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import org.json.JSONObject

/**
 * BroadcastReceiver that fires when AlarmManager triggers a scheduled notification.
 * Shows the notification and sends a cronFired event back to Dart for cron-based
 * schedules so that Dart can calculate and set the next occurrence.
 */
class AlarmReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val scheduleId = intent.getIntExtra("schedule_id", -1)
        val metadataJson = intent.getStringExtra("schedule_metadata") ?: return

        val metadata: JSONObject
        try {
            metadata = JSONObject(metadataJson)
        } catch (_: Exception) {
            return
        }

        val id = metadata.optInt("id", scheduleId)
        val title = metadata.optString("title").takeIf { it != "null" && it.isNotEmpty() }
        val body = metadata.optString("body").takeIf { it != "null" && it.isNotEmpty() }
        val channelId = metadata.optString("channelId").takeIf { it != "null" && it.isNotEmpty() }
        val groupKey = metadata.optString("groupKey").takeIf { it != "null" && it.isNotEmpty() }
        val deepLink = metadata.optString("deepLink").takeIf { it != "null" && it.isNotEmpty() }
        val payload = metadata.optString("payload").takeIf { it != "null" && it.isNotEmpty() }
        val cronExpression = metadata.optString("cronExpression").takeIf { it != "null" && it.isNotEmpty() }

        // Show the notification
        val displayManager = NotificationDisplayManager(context)
        displayManager.show(
            id = id,
            title = title,
            body = body,
            channelId = channelId,
            groupKey = groupKey,
            deepLink = deepLink,
            payload = payload
        )

        // Clean up the schedule from SharedPreferences
        val prefs = context.getSharedPreferences("notify_pilot_schedules", Context.MODE_PRIVATE)
        val idsSet = prefs.getStringSet("schedule_ids", emptySet())?.toMutableSet() ?: mutableSetOf()
        idsSet.remove(id.toString())
        prefs.edit()
            .remove("schedule_$id")
            .putStringSet("schedule_ids", idsSet)
            .apply()

        // If this was a cron schedule, notify Dart so it can self-reschedule
        if (cronExpression != null) {
            val eventData = mutableMapOf<String, Any?>(
                "id" to id,
                "title" to title,
                "body" to body,
                "channelId" to channelId,
                "groupKey" to groupKey,
                "deepLink" to deepLink,
                "payload" to payload,
                "cronExpression" to cronExpression
            )
            NotifyPilotPlugin.invokeMethod("onCronFired", eventData)
        }
    }
}
