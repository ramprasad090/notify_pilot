package dev.notify_pilot

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * BroadcastReceiver for call-related action events (accept, decline, end, mute, speaker, etc.).
 * Cancels the notification, dismisses IncomingCallActivity, and forwards events back to Dart.
 */
class CallActionReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val callId = intent.getStringExtra("callId") ?: return

        val event = when (intent.action) {
            "dev.notify_pilot.CALL_ACCEPTED" -> "accepted"
            "dev.notify_pilot.CALL_DECLINED" -> "declined"
            "dev.notify_pilot.CALL_ENDED" -> "ended"
            "dev.notify_pilot.CALL_HELD" -> "held"
            "dev.notify_pilot.CALL_UNHELD" -> "unheld"
            "dev.notify_pilot.CALL_MUTE" -> "muted"
            "dev.notify_pilot.CALL_SPEAKER" -> "speaker"
            "dev.notify_pilot.CALL_FAILED" -> "failed"
            "dev.notify_pilot.CALL_ACTION" -> "action"
            else -> return
        }

        // Cancel the call notification
        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.cancel(callId.hashCode())

        // Dismiss IncomingCallActivity if it's showing
        if (event == "accepted" || event == "declined" || event == "ended") {
            val hideIntent = Intent("dev.notify_pilot.HIDE_CALL").apply {
                setPackage(context.packageName)
                putExtra("callId", callId)
            }
            context.sendBroadcast(hideIntent)
        }

        // Build event args for Dart
        val args = mutableMapOf<String, Any?>(
            "callId" to callId,
            "event" to event,
        )

        // Include additional data for specific events
        when (event) {
            "action" -> {
                args["actionId"] = intent.getStringExtra("actionId")
                args["callerName"] = intent.getStringExtra("callerName")
                args["callerNumber"] = intent.getStringExtra("callerNumber")
            }
            "muted" -> args["muted"] = intent.getBooleanExtra("muted", false)
            "held" -> args["held"] = intent.getBooleanExtra("held", false)
            "speaker" -> args["speaker"] = intent.getBooleanExtra("speaker", false)
        }

        // Forward to Dart
        NotifyPilotPlugin.invokeMethod("onCallEvent", args)
    }
}
