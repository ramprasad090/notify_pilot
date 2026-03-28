package dev.notify_pilot

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * BroadcastReceiver for call-related action events (accept, decline, end, mute, speaker, etc.).
 * Forwards events back to Dart via the plugin's method channel.
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
            "dev.notify_pilot.CALL_MUTE" -> "mute"
            "dev.notify_pilot.CALL_SPEAKER" -> "speaker"
            "dev.notify_pilot.CALL_FAILED" -> "failed"
            "dev.notify_pilot.CALL_ACTION" -> "action"
            else -> return
        }

        val args = mutableMapOf<String, Any?>(
            "callId" to callId,
            "event" to event
        )

        // Include additional data for missed call actions
        if (event == "action") {
            val actionId = intent.getStringExtra("actionId")
            val callerName = intent.getStringExtra("callerName")
            val callerNumber = intent.getStringExtra("callerNumber")
            args["actionId"] = actionId
            args["callerName"] = callerName
            args["callerNumber"] = callerNumber
        }

        NotifyPilotPlugin.invokeMethod("onCallEvent", args)
    }
}
