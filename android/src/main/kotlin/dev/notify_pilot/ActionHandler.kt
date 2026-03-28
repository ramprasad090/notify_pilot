package dev.notify_pilot

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.app.RemoteInput

/**
 * BroadcastReceiver for notification tap and action button events.
 * Sends events back to Dart via the plugin's method channel.
 */
class ActionHandler : BroadcastReceiver() {

    companion object {
        private const val REMOTE_INPUT_KEY = "notify_pilot_reply"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val notificationId = intent.getIntExtra("notification_id", -1)
        val title = intent.getStringExtra("title")
        val body = intent.getStringExtra("body")
        val deepLink = intent.getStringExtra("deep_link")
        val payload = intent.getStringExtra("payload")
        val groupKey = intent.getStringExtra("group_key")

        when (intent.action) {
            "dev.notify_pilot.TAP" -> {
                val eventData = buildEventMap(notificationId, title, body, deepLink, payload, groupKey)

                // Launch the app
                val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                launchIntent?.let {
                    it.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    if (deepLink != null) it.putExtra("deep_link", deepLink)
                    if (payload != null) it.putExtra("payload", payload)
                    context.startActivity(it)
                }

                // Invoke Dart callback
                NotifyPilotPlugin.invokeMethod("onTap", eventData)
            }

            "dev.notify_pilot.ACTION" -> {
                val actionId = intent.getStringExtra("action_id")
                val actionTitle = intent.getStringExtra("action_title")

                // Check for inline reply text
                val remoteInputResults = RemoteInput.getResultsFromIntent(intent)
                val replyText = remoteInputResults?.getCharSequence(REMOTE_INPUT_KEY)?.toString()

                val eventData = buildEventMap(notificationId, title, body, deepLink, payload, groupKey).apply {
                    put("actionId", actionId)
                    put("actionTitle", actionTitle)
                    if (replyText != null) put("replyText", replyText)
                }

                // Cancel the notification after action
                val notificationManager =
                    context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                notificationManager.cancel(notificationId)

                // Invoke Dart callback
                NotifyPilotPlugin.invokeMethod("onAction", eventData)
            }
        }
    }

    private fun buildEventMap(
        id: Int,
        title: String?,
        body: String?,
        deepLink: String?,
        payload: String?,
        groupKey: String?
    ): MutableMap<String, Any?> {
        return mutableMapOf(
            "id" to id,
            "title" to title,
            "body" to body,
            "deepLink" to deepLink,
            "payload" to payload,
            "groupKey" to groupKey
        )
    }
}
