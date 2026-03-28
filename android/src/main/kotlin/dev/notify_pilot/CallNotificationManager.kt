package dev.notify_pilot

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import androidx.core.app.NotificationCompat

/**
 * Manages call notifications including incoming (fullscreen), outgoing,
 * ongoing (connected), and missed call states.
 */
class CallNotificationManager(private val context: Context) {

    companion object {
        private const val CALL_CHANNEL_ID = "notify_pilot_calls"
        private const val CALL_CHANNEL_NAME = "Calls"
        private const val MISSED_CHANNEL_ID = "notify_pilot_missed_calls"
        private const val MISSED_CHANNEL_NAME = "Missed Calls"
        private val mainHandler = Handler(Looper.getMainLooper())
    }

    /**
     * Callback invoked when a call event occurs.
     * Parameters: callId, event name, optional data map.
     */
    var onCallEvent: ((String, String, Map<String, Any?>?) -> Unit)? = null

    /** Data class representing an active call entry. */
    data class CallData(
        val callId: String,
        val callerName: String,
        val callerNumber: String?,
        val callType: String?,
        var state: String, // "incoming", "outgoing", "connected", "ended"
        val extra: Map<String, Any?>?
    )

    /** Active calls keyed by callId. */
    private val activeCalls = mutableMapOf<String, CallData>()

    /** Timeout runnables keyed by callId, for auto-declining incoming calls. */
    private val timeoutRunnables = mutableMapOf<String, Runnable>()

    private val notificationManager: NotificationManager
        get() = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    init {
        ensureCallChannels()
    }

    // region Public API

    /**
     * Shows an incoming call notification with fullscreen intent and action buttons.
     */
    fun showIncomingCall(
        callId: String,
        callerName: String,
        callerNumber: String?,
        callerAvatar: String?,
        callType: String?,
        ringtone: String?,
        timeoutMs: Long,
        acceptText: String?,
        declineText: String?,
        extra: Map<String, Any?>?
    ) {
        activeCalls[callId] = CallData(
            callId = callId,
            callerName = callerName,
            callerNumber = callerNumber,
            callType = callType,
            state = "incoming",
            extra = extra
        )

        val notificationId = callId.hashCode()

        // Fullscreen intent to IncomingCallActivity
        val fullscreenIntent = Intent(context, IncomingCallActivity::class.java).apply {
            putExtra("callId", callId)
            putExtra("callerName", callerName)
            putExtra("callerNumber", callerNumber ?: "")
            putExtra("callerAvatar", callerAvatar ?: "")
            putExtra("callType", callType ?: "audio")
            putExtra("acceptText", acceptText ?: "Accept")
            putExtra("declineText", declineText ?: "Decline")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        val fullscreenPendingIntent = PendingIntent.getActivity(
            context, notificationId, fullscreenIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Accept action
        val acceptIntent = Intent(context, CallActionReceiver::class.java).apply {
            action = "dev.notify_pilot.CALL_ACCEPTED"
            putExtra("callId", callId)
        }
        val acceptPendingIntent = PendingIntent.getBroadcast(
            context, notificationId + 1, acceptIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Decline action
        val declineIntent = Intent(context, CallActionReceiver::class.java).apply {
            action = "dev.notify_pilot.CALL_DECLINED"
            putExtra("callId", callId)
        }
        val declinePendingIntent = PendingIntent.getBroadcast(
            context, notificationId + 2, declineIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val callTypeLabel = if (callType == "video") "Incoming video call" else "Incoming call"

        val builder = NotificationCompat.Builder(context, CALL_CHANNEL_ID)
            .setSmallIcon(getSmallIconResId())
            .setContentTitle(callerName)
            .setContentText(callTypeLabel)
            .setSubText(callerNumber)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setOngoing(true)
            .setAutoCancel(false)
            .setFullScreenIntent(fullscreenPendingIntent, true)
            .addAction(
                android.R.drawable.sym_action_call,
                acceptText ?: "Accept",
                acceptPendingIntent
            )
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                declineText ?: "Decline",
                declinePendingIntent
            )

        if (callerAvatar != null) {
            val bitmap = MediaDownloader.downloadSync(callerAvatar)
            if (bitmap != null) {
                builder.setLargeIcon(bitmap)
            }
        }

        notificationManager.notify(notificationId, builder.build())

        // Auto-decline timeout
        if (timeoutMs > 0) {
            val timeoutRunnable = Runnable {
                timeoutRunnables.remove(callId)
                val call = activeCalls[callId]
                if (call != null && call.state == "incoming") {
                    endCall(callId)
                    showMissedCall(
                        callId = callId,
                        callerName = callerName,
                        callerNumber = callerNumber,
                        time = System.currentTimeMillis(),
                        actions = null
                    )
                    onCallEvent?.invoke(callId, "timeout", null)
                }
            }
            timeoutRunnables[callId] = timeoutRunnable
            mainHandler.postDelayed(timeoutRunnable, timeoutMs)
        }
    }

    /**
     * Shows an outgoing call notification with a cancel button.
     */
    fun showOutgoingCall(
        callId: String,
        callerName: String,
        callerNumber: String?,
        callType: String?
    ) {
        activeCalls[callId] = CallData(
            callId = callId,
            callerName = callerName,
            callerNumber = callerNumber,
            callType = callType,
            state = "outgoing",
            extra = null
        )

        val notificationId = callId.hashCode()

        // Cancel action
        val cancelIntent = Intent(context, CallActionReceiver::class.java).apply {
            action = "dev.notify_pilot.CALL_ENDED"
            putExtra("callId", callId)
        }
        val cancelPendingIntent = PendingIntent.getBroadcast(
            context, notificationId + 3, cancelIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val callTypeLabel = if (callType == "video") "Video call" else "Calling..."

        val builder = NotificationCompat.Builder(context, CALL_CHANNEL_ID)
            .setSmallIcon(getSmallIconResId())
            .setContentTitle(callerName)
            .setContentText(callTypeLabel)
            .setSubText(callerNumber)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setOngoing(true)
            .setAutoCancel(false)
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "Cancel",
                cancelPendingIntent
            )

        notificationManager.notify(notificationId, builder.build())
    }

    /**
     * Updates an existing call notification to the connected state with a duration timer.
     */
    fun setCallConnected(callId: String) {
        val call = activeCalls[callId] ?: return
        call.state = "connected"

        // Cancel any pending timeout
        cancelTimeout(callId)

        val notificationId = callId.hashCode()

        // Mute action
        val muteIntent = Intent(context, CallActionReceiver::class.java).apply {
            action = "dev.notify_pilot.CALL_MUTE"
            putExtra("callId", callId)
        }
        val mutePendingIntent = PendingIntent.getBroadcast(
            context, notificationId + 4, muteIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Speaker action
        val speakerIntent = Intent(context, CallActionReceiver::class.java).apply {
            action = "dev.notify_pilot.CALL_SPEAKER"
            putExtra("callId", callId)
        }
        val speakerPendingIntent = PendingIntent.getBroadcast(
            context, notificationId + 5, speakerIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Hang up action
        val hangUpIntent = Intent(context, CallActionReceiver::class.java).apply {
            action = "dev.notify_pilot.CALL_ENDED"
            putExtra("callId", callId)
        }
        val hangUpPendingIntent = PendingIntent.getBroadcast(
            context, notificationId + 6, hangUpIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = NotificationCompat.Builder(context, CALL_CHANNEL_ID)
            .setSmallIcon(getSmallIconResId())
            .setContentTitle(call.callerName)
            .setContentText("Connected")
            .setSubText(call.callerNumber)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setOngoing(true)
            .setAutoCancel(false)
            .setUsesChronometer(true)
            .setChronometerCountDown(false)
            .setWhen(System.currentTimeMillis())
            .addAction(
                android.R.drawable.ic_lock_silent_mode,
                "Mute",
                mutePendingIntent
            )
            .addAction(
                android.R.drawable.ic_lock_silent_mode_off,
                "Speaker",
                speakerPendingIntent
            )
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "Hang Up",
                hangUpPendingIntent
            )

        notificationManager.notify(notificationId, builder.build())
    }

    /**
     * Ends a call: cancels the notification, removes from active calls, cancels timeout.
     */
    fun endCall(callId: String) {
        val notificationId = callId.hashCode()
        notificationManager.cancel(notificationId)
        activeCalls.remove(callId)
        cancelTimeout(callId)

        // Broadcast to dismiss IncomingCallActivity if visible
        val hideIntent = Intent("dev.notify_pilot.HIDE_CALL").apply {
            putExtra("callId", callId)
            setPackage(context.packageName)
        }
        context.sendBroadcast(hideIntent)
    }

    /**
     * Shows a missed call notification with optional action buttons.
     */
    fun showMissedCall(
        callId: String,
        callerName: String,
        callerNumber: String?,
        time: Long,
        actions: List<Map<String, Any?>>?
    ) {
        // Use a separate notification ID so it does not conflict with the active call
        val notificationId = "missed_$callId".hashCode()

        val builder = NotificationCompat.Builder(context, MISSED_CHANNEL_ID)
            .setSmallIcon(getSmallIconResId())
            .setContentTitle("Missed call")
            .setContentText(callerName)
            .setSubText(callerNumber)
            .setCategory(NotificationCompat.CATEGORY_MISSED_CALL)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)
            .setWhen(time)

        // Optional Call Back action
        if (actions != null) {
            for (action in actions) {
                val actionId = action["id"] as? String ?: continue
                val actionTitle = action["label"] as? String ?: continue

                val actionIntent = Intent(context, CallActionReceiver::class.java).apply {
                    this.action = "dev.notify_pilot.CALL_ACTION"
                    putExtra("callId", callId)
                    putExtra("actionId", actionId)
                    putExtra("callerName", callerName)
                    putExtra("callerNumber", callerNumber)
                }
                val actionPendingIntent = PendingIntent.getBroadcast(
                    context, "$actionId$callId".hashCode(), actionIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                builder.addAction(0, actionTitle, actionPendingIntent)
            }
        }

        notificationManager.notify(notificationId, builder.build())
    }

    /**
     * Hides an incoming call notification without changing call state further.
     */
    fun hideIncomingCall(callId: String) {
        val notificationId = callId.hashCode()
        notificationManager.cancel(notificationId)
        cancelTimeout(callId)

        // Broadcast to dismiss IncomingCallActivity if visible
        val hideIntent = Intent("dev.notify_pilot.HIDE_CALL").apply {
            putExtra("callId", callId)
            setPackage(context.packageName)
        }
        context.sendBroadcast(hideIntent)
    }

    /**
     * Returns a list of currently active calls with their state.
     */
    fun getActiveCalls(): List<Map<String, Any?>> {
        return activeCalls.values.map { call ->
            mapOf(
                "callId" to call.callId,
                "callerName" to call.callerName,
                "callerNumber" to call.callerNumber,
                "callType" to call.callType,
                "state" to call.state,
                "extra" to call.extra
            )
        }
    }

    // endregion

    // region Private helpers

    private fun ensureCallChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val callChannel = NotificationChannel(
            CALL_CHANNEL_ID,
            CALL_CHANNEL_NAME,
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Incoming and ongoing call notifications"
            setShowBadge(true)
            enableVibration(true)
            lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
        }
        notificationManager.createNotificationChannel(callChannel)

        val missedChannel = NotificationChannel(
            MISSED_CHANNEL_ID,
            MISSED_CHANNEL_NAME,
            NotificationManager.IMPORTANCE_DEFAULT
        ).apply {
            description = "Missed call notifications"
            setShowBadge(true)
        }
        notificationManager.createNotificationChannel(missedChannel)
    }

    private fun cancelTimeout(callId: String) {
        timeoutRunnables.remove(callId)?.let { runnable ->
            mainHandler.removeCallbacks(runnable)
        }
    }

    private fun getSmallIconResId(): Int {
        val resId = context.resources.getIdentifier(
            "ic_notification", "drawable", context.packageName
        )
        return if (resId != 0) resId else context.applicationInfo.icon
    }

    // endregion
}
