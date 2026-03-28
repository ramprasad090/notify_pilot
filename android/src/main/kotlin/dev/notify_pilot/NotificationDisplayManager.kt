package dev.notify_pilot

import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.app.NotificationCompat
import androidx.core.app.RemoteInput
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors

class NotificationDisplayManager(private val context: Context) {

    companion object {
        private const val DEFAULT_CHANNEL_ID = "notify_pilot_default"
        private const val REMOTE_INPUT_KEY = "notify_pilot_reply"
        private val executor = Executors.newCachedThreadPool()
        private val mainHandler = Handler(Looper.getMainLooper())
    }

    /**
     * Builds and displays a notification.
     *
     * @param id Notification id
     * @param title Notification title
     * @param body Notification body text
     * @param channelId Channel id (defaults to notify_pilot_default)
     * @param groupKey Optional group key for grouped notifications
     * @param imageUrl Optional URL for BigPictureStyle image
     * @param largeIconUrl Optional URL for large icon
     * @param deepLink Optional deep link URI string
     * @param payload Optional JSON payload string
     * @param actions List of action maps with keys: id, title, icon (optional), isReply (optional)
     * @param autoCancel Whether notification is auto-cancelled on tap
     * @param ongoing Whether the notification is ongoing
     * @param silent Whether the notification is silent
     * @param summary Optional summary text for InboxStyle grouped notifications
     * @param inboxLines Optional list of lines for InboxStyle
     */
    fun show(
        id: Int,
        title: String?,
        body: String?,
        channelId: String? = null,
        groupKey: String? = null,
        imageUrl: String? = null,
        largeIconUrl: String? = null,
        deepLink: String? = null,
        payload: String? = null,
        actions: List<Map<String, Any>>? = null,
        autoCancel: Boolean = true,
        ongoing: Boolean = false,
        silent: Boolean = false,
        summary: String? = null,
        inboxLines: List<String>? = null
    ) {
        val effectiveChannelId = channelId ?: DEFAULT_CHANNEL_ID

        // Download images on a background thread, then build notification on main thread
        executor.execute {
            val imageBitmap = imageUrl?.let { downloadBitmap(it) }
            val largeIconBitmap = largeIconUrl?.let { downloadBitmap(it) }

            mainHandler.post {
                buildAndNotify(
                    id, title, body, effectiveChannelId, groupKey,
                    imageBitmap, largeIconBitmap, deepLink, payload,
                    actions, autoCancel, ongoing, silent, summary, inboxLines
                )
            }
        }
    }

    private fun buildAndNotify(
        id: Int,
        title: String?,
        body: String?,
        channelId: String,
        groupKey: String?,
        imageBitmap: Bitmap?,
        largeIconBitmap: Bitmap?,
        deepLink: String?,
        payload: String?,
        actions: List<Map<String, Any>>?,
        autoCancel: Boolean,
        ongoing: Boolean,
        silent: Boolean,
        summary: String?,
        inboxLines: List<String>?
    ) {
        val tapIntent = buildTapIntent(id, title, body, deepLink, payload, groupKey)

        val builder = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(getSmallIconResId())
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(autoCancel)
            .setOngoing(ongoing)
            .setContentIntent(tapIntent)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)

        if (silent) {
            builder.setSilent(true)
        }

        if (largeIconBitmap != null) {
            builder.setLargeIcon(largeIconBitmap)
        }

        // BigPictureStyle for image notifications
        if (imageBitmap != null) {
            val bigPictureStyle = NotificationCompat.BigPictureStyle()
                .bigPicture(imageBitmap)
                .setBigContentTitle(title)
                .setSummaryText(body)
            builder.setStyle(bigPictureStyle)
        }
        // InboxStyle for grouped notifications
        else if (!inboxLines.isNullOrEmpty()) {
            val inboxStyle = NotificationCompat.InboxStyle()
            inboxLines.forEach { inboxStyle.addLine(it) }
            if (summary != null) inboxStyle.setSummaryText(summary)
            inboxStyle.setBigContentTitle(title)
            builder.setStyle(inboxStyle)
        }
        // Default BigTextStyle for long body text
        else if (body != null && body.length > 40) {
            builder.setStyle(NotificationCompat.BigTextStyle().bigText(body))
        }

        // Group support
        if (groupKey != null) {
            builder.setGroup(groupKey)
        }

        // Action buttons
        actions?.forEach { actionMap ->
            val actionId = actionMap["id"] as? String ?: return@forEach
            val actionTitle = actionMap["title"] as? String ?: return@forEach
            val isReply = actionMap["isReply"] as? Boolean ?: false

            val actionIntent = buildActionIntent(id, actionId, actionTitle, deepLink, payload, groupKey)

            if (isReply) {
                val remoteInput = RemoteInput.Builder(REMOTE_INPUT_KEY)
                    .setLabel(actionTitle)
                    .build()
                val action = NotificationCompat.Action.Builder(0, actionTitle, actionIntent)
                    .addRemoteInput(remoteInput)
                    .build()
                builder.addAction(action)
            } else {
                builder.addAction(0, actionTitle, actionIntent)
            }
        }

        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(id, builder.build())

        // If there is a group, also show a summary notification
        if (groupKey != null) {
            showGroupSummary(channelId, groupKey, summary ?: title ?: "")
        }
    }

    private fun showGroupSummary(channelId: String, groupKey: String, summaryText: String) {
        val summaryBuilder = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(getSmallIconResId())
            .setGroup(groupKey)
            .setGroupSummary(true)
            .setAutoCancel(true)
            .setStyle(
                NotificationCompat.InboxStyle()
                    .setSummaryText(summaryText)
            )

        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        // Use a stable summary id derived from the group key
        val summaryId = groupKey.hashCode()
        notificationManager.notify(summaryId, summaryBuilder.build())
    }

    private fun buildTapIntent(
        id: Int,
        title: String?,
        body: String?,
        deepLink: String?,
        payload: String?,
        groupKey: String?
    ): PendingIntent {
        val intent = Intent(context, ActionHandler::class.java).apply {
            action = "dev.notify_pilot.TAP"
            putExtra("notification_id", id)
            putExtra("title", title)
            putExtra("body", body)
            putExtra("deep_link", deepLink)
            putExtra("payload", payload)
            putExtra("group_key", groupKey)
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        return PendingIntent.getBroadcast(context, id, intent, flags)
    }

    private fun buildActionIntent(
        notificationId: Int,
        actionId: String,
        actionTitle: String,
        deepLink: String?,
        payload: String?,
        groupKey: String?
    ): PendingIntent {
        val intent = Intent(context, ActionHandler::class.java).apply {
            action = "dev.notify_pilot.ACTION"
            putExtra("notification_id", notificationId)
            putExtra("action_id", actionId)
            putExtra("action_title", actionTitle)
            putExtra("deep_link", deepLink)
            putExtra("payload", payload)
            putExtra("group_key", groupKey)
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        val requestCode = notificationId * 1000 + actionId.hashCode()
        return PendingIntent.getBroadcast(context, requestCode, intent, flags)
    }

    private fun downloadBitmap(url: String): Bitmap? {
        return try {
            val connection = URL(url).openConnection() as HttpURLConnection
            connection.connectTimeout = 10_000
            connection.readTimeout = 10_000
            connection.doInput = true
            connection.connect()
            val inputStream = connection.inputStream
            BitmapFactory.decodeStream(inputStream).also {
                inputStream.close()
                connection.disconnect()
            }
        } catch (e: Exception) {
            null
        }
    }

    private fun getSmallIconResId(): Int {
        // Try to use the app's notification icon, fall back to app icon
        val resId = context.resources.getIdentifier(
            "ic_notification", "drawable", context.packageName
        )
        return if (resId != 0) resId else context.applicationInfo.icon
    }
}
