package dev.notify_pilot

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat

/**
 * Manages ongoing notifications with custom RemoteViews layouts,
 * serving as the Android equivalent of iOS Live Activities.
 */
class LiveNotificationManager(private val context: Context) {

    companion object {
        private const val LIVE_CHANNEL_ID = "notify_pilot_live"
        private const val LIVE_CHANNEL_NAME = "Live Notifications"
        private val mainHandler = Handler(Looper.getMainLooper())
    }

    /** Cached config per notification string id. */
    private val configCache = mutableMapOf<String, Map<String, Any?>>()

    /** Tracks active live notification string ids. */
    private val activeLiveIds = mutableSetOf<String>()

    private val notificationManager: NotificationManager
        get() = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    init {
        ensureLiveChannel()
    }

    /**
     * Creates an ongoing notification with a custom or default RemoteViews layout.
     *
     * @param id String identifier for this live notification
     * @param config Configuration map with keys: title, type, customLayoutName
     * @param state State map with data to populate the layout (title, subtitle, eta, progress, etc.)
     */
    fun startLiveNotification(id: String, config: Map<String, Any?>, state: Map<String, Any?>): String {
        configCache[id] = config
        activeLiveIds.add(id)

        val notificationId = id.hashCode()
        val customLayoutName = config["customLayoutName"] as? String
        val title = state["title"] as? String ?: config["title"] as? String ?: ""

        val remoteViews = if (customLayoutName != null) {
            buildCustomLayout(customLayoutName, state)
        } else {
            RemoteViewsBuilder.buildDefaultLayout(context, state)
        }

        val tapIntent = buildTapIntent(id, state)

        val builder = NotificationCompat.Builder(context, LIVE_CHANNEL_ID)
            .setSmallIcon(getSmallIconResId())
            .setContentTitle(title)
            .setCustomContentView(remoteViews)
            .setCustomBigContentView(remoteViews)
            .setOngoing(true)
            .setOnlyAlertOnce(false)
            .setAutoCancel(false)
            .setContentIntent(tapIntent)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_STATUS)

        notificationManager.notify(notificationId, builder.build())
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
     *
     * @param id String identifier for the live notification
     * @param state Updated state map
     */
    fun updateLiveNotification(id: String, state: Map<String, Any?>) {
        val config = configCache[id] ?: return
        val notificationId = id.hashCode()
        val customLayoutName = config["customLayoutName"] as? String
        val title = state["title"] as? String ?: config["title"] as? String ?: ""

        val remoteViews = if (customLayoutName != null) {
            buildCustomLayout(customLayoutName, state)
        } else {
            RemoteViewsBuilder.buildDefaultLayout(context, state)
        }

        val tapIntent = buildTapIntent(id, state)

        val builder = NotificationCompat.Builder(context, LIVE_CHANNEL_ID)
            .setSmallIcon(getSmallIconResId())
            .setContentTitle(title)
            .setCustomContentView(remoteViews)
            .setCustomBigContentView(remoteViews)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setAutoCancel(false)
            .setContentIntent(tapIntent)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_STATUS)

        notificationManager.notify(notificationId, builder.build())
    }

    /**
     * Cancels a specific live notification.
     *
     * @param id String identifier for the live notification
     */
    fun endLiveNotification(id: String) {
        val notificationId = id.hashCode()
        notificationManager.cancel(notificationId)
        configCache.remove(id)
        activeLiveIds.remove(id)
    }

    /**
     * Cancels all live notifications matching the given type.
     *
     * @param type The type string from the config to match against
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
        }
        activeLiveIds.removeAll(idsToRemove.toSet())
    }

    /**
     * Returns a list of currently active live notifications with their ids and configs.
     */
    fun getActiveLiveNotifications(): List<Map<String, Any?>> {
        return activeLiveIds.map { id ->
            mapOf(
                "id" to id,
                "notificationId" to id.hashCode(),
                "config" to (configCache[id] ?: emptyMap<String, Any?>())
            )
        }
    }

    /**
     * Always returns "supported" on Android.
     */
    fun isLiveActivitySupported(): String = "supported"

    /**
     * Always returns false on Android (Dynamic Island is an iOS feature).
     */
    fun hasDynamicIsland(): Boolean = false

    // region Private helpers

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

    private fun buildCustomLayout(layoutName: String, state: Map<String, Any?>): RemoteViews {
        val layoutResId = context.resources.getIdentifier(
            layoutName, "layout", context.packageName
        )
        val views = if (layoutResId != 0) {
            RemoteViews(context.packageName, layoutResId)
        } else {
            // Fall back to default layout if custom layout not found
            return RemoteViewsBuilder.buildDefaultLayout(context, state)
        }
        RemoteViewsBuilder.populateRemoteViews(views, state)
        return views
    }

    private fun buildTapIntent(id: String, state: Map<String, Any?>): PendingIntent {
        val intent = Intent(context, ActionHandler::class.java).apply {
            action = "dev.notify_pilot.LIVE_TAP"
            putExtra("live_notification_id", id)
            putExtra("payload", state["payload"] as? String)
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        return PendingIntent.getBroadcast(context, id.hashCode(), intent, flags)
    }

    private fun getSmallIconResId(): Int {
        val resId = context.resources.getIdentifier(
            "ic_notification", "drawable", context.packageName
        )
        return if (resId != 0) resId else context.applicationInfo.icon
    }

    // endregion
}
