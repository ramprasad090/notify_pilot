package dev.notify_pilot

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat

/**
 * Manages ongoing notifications as the Android equivalent of iOS Live Activities.
 *
 * Uses standard NotificationCompat with content text built from state data,
 * providing a reliable cross-device experience.
 */
class LiveNotificationManager(private val context: Context) {

    companion object {
        private const val LIVE_CHANNEL_ID = "notify_pilot_live"
        private const val LIVE_CHANNEL_NAME = "Live Notifications"
    }

    /** Cached config per notification string id. */
    private val configCache = mutableMapOf<String, Map<String, Any?>>()

    /** Cached state per notification string id. */
    private val stateCache = mutableMapOf<String, Map<String, Any?>>()

    /** Tracks active live notification string ids. */
    private val activeLiveIds = mutableSetOf<String>()

    private val notificationManager: NotificationManager
        get() = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    init {
        ensureLiveChannel()
    }

    /**
     * Creates an ongoing notification populated from state data.
     */
    fun startLiveNotification(id: String, config: Map<String, Any?>, state: Map<String, Any?>): String {
        configCache[id] = config
        stateCache[id] = state
        activeLiveIds.add(id)
        showNotification(id, config, state, alertOnce = false)
        return id
    }

    /**
     * Returns the status of a live notification.
     */
    fun getLiveNotificationStatus(id: String): String {
        return if (activeLiveIds.contains(id)) "active" else "ended"
    }

    /**
     * Updates an existing live notification without re-alerting the user.
     */
    fun updateLiveNotification(id: String, state: Map<String, Any?>) {
        val config = configCache[id] ?: return
        stateCache[id] = state
        showNotification(id, config, state, alertOnce = true)
    }

    /**
     * Cancels a specific live notification.
     */
    fun endLiveNotification(id: String) {
        notificationManager.cancel(id.hashCode())
        configCache.remove(id)
        stateCache.remove(id)
        activeLiveIds.remove(id)
    }

    /**
     * Cancels all live notifications matching the given type.
     */
    fun endAllLiveNotifications(type: String?) {
        val idsToRemove = if (type != null) {
            activeLiveIds.filter { id ->
                val config = configCache[id]
                config?.get("type") as? String == type
            }
        } else {
            activeLiveIds.toList()
        }

        idsToRemove.forEach { id ->
            notificationManager.cancel(id.hashCode())
            configCache.remove(id)
            stateCache.remove(id)
        }
        activeLiveIds.removeAll(idsToRemove.toSet())
    }

    /**
     * Returns a list of currently active live notifications.
     */
    fun getActiveLiveNotifications(): List<Map<String, Any?>> {
        return activeLiveIds.map { id ->
            mapOf(
                "id" to id,
                "type" to (configCache[id]?.get("type") as? String ?: ""),
                "state" to (stateCache[id] ?: emptyMap<String, Any?>()),
                "status" to "active",
                "startedAt" to System.currentTimeMillis(),
            )
        }
    }

    // region Private helpers

    private fun showNotification(
        id: String,
        config: Map<String, Any?>,
        state: Map<String, Any?>,
        alertOnce: Boolean
    ) {
        try {
            val notificationId = id.hashCode()
            val type = config["type"] as? String ?: id

            // Build title and body from state data
            val title = buildTitle(type, config, state)
            val body = buildBody(type, state)
            val progress = (state["progress"] as? Number)?.toDouble() ?: -1.0

            val builder = NotificationCompat.Builder(context, LIVE_CHANNEL_ID)
                .setSmallIcon(getSmallIconResId())
                .setContentTitle(title)
                .setContentText(body)
                .setOngoing(true)
                .setOnlyAlertOnce(alertOnce)
                .setAutoCancel(false)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setCategory(NotificationCompat.CATEGORY_STATUS)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)

            // Show progress bar if progress is available
            if (progress in 0.0..1.0) {
                builder.setProgress(100, (progress * 100).toInt(), false)
            }

            // Expanded text with all state info
            val expandedText = state.entries
                .filter { it.key != "progress" }
                .joinToString("\n") { "${formatKey(it.key)}: ${it.value}" }
            if (expandedText.isNotEmpty()) {
                builder.setStyle(NotificationCompat.BigTextStyle().bigText(expandedText))
            }

            notificationManager.notify(notificationId, builder.build())
            android.util.Log.d("NotifyPilot", "Live notification shown: id=$notificationId title=$title")
        } catch (e: Exception) {
            android.util.Log.e("NotifyPilot", "Failed to show live notification: ${e.message}", e)
        }
    }

    private fun buildTitle(type: String, config: Map<String, Any?>, state: Map<String, Any?>): String {
        // Use status or type as title context
        val status = state["status"] as? String
        val eta = state["eta"] as? String

        return when {
            // Ride tracking: "Arriving - 5 min"
            status != null && eta != null -> "${status.replaceFirstChar { it.uppercase() }} — $eta"
            // Has ETA: "ETA: 5 min"
            eta != null -> "ETA: $eta"
            // Has status: "Arriving"
            status != null -> status.replaceFirstChar { it.uppercase() }
            // Fallback to type
            else -> type.replace("_", " ").replaceFirstChar { it.uppercase() }
        }
    }

    private fun buildBody(type: String, state: Map<String, Any?>): String {
        val parts = mutableListOf<String>()

        // Common fields
        (state["distance"] as? String)?.let { parts.add(it) }
        (state["deliveryPerson"] as? String)?.let { parts.add("by $it") }
        (state["homeScore"] as? String)?.let { home ->
            val away = state["awayScore"] as? String ?: ""
            parts.add("$home vs $away")
        }
        (state["overs"] as? String)?.let { parts.add("Ov: $it") }

        return if (parts.isNotEmpty()) parts.joinToString(" • ") else ""
    }

    private fun formatKey(key: String): String {
        return key.replace(Regex("([A-Z])"), " $1")
            .replaceFirstChar { it.uppercase() }
            .trim()
    }

    private fun ensureLiveChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val channel = NotificationChannel(
            LIVE_CHANNEL_ID,
            LIVE_CHANNEL_NAME,
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Live notification updates"
            setShowBadge(false)
            enableVibration(false)
        }

        notificationManager.createNotificationChannel(channel)
    }

    private fun getSmallIconResId(): Int {
        val resId = context.resources.getIdentifier(
            "ic_notification", "drawable", context.packageName
        )
        return if (resId != 0) resId else context.applicationInfo.icon
    }

    // endregion
}
