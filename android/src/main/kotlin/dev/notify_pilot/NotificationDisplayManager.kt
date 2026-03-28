package dev.notify_pilot

import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ContentResolver
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.app.NotificationCompat
import androidx.core.app.Person
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
     * @param actions List of action maps with keys: id, label, icon (optional), input (optional)
     * @param autoCancel Whether notification is auto-cancelled on tap
     * @param ongoing Whether the notification is ongoing
     * @param silent Whether the notification is silent
     * @param summary Optional summary text for InboxStyle grouped notifications
     * @param inboxLines Optional list of lines for InboxStyle
     * @param displayStyleMap Optional display style map from Dart (bigText, bigPicture, inbox, messaging, progress)
     * @param soundMap Optional sound configuration map
     * @param fullscreen Whether to show as full-screen intent
     * @param turnScreenOn Whether to turn screen on when notification arrives
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
        actions: List<Map<String, Any?>>? = null,
        autoCancel: Boolean = true,
        ongoing: Boolean = false,
        silent: Boolean = false,
        summary: String? = null,
        inboxLines: List<String>? = null,
        displayStyleMap: Map<String, Any?>? = null,
        soundMap: Map<String, Any?>? = null,
        fullscreen: Boolean = false,
        turnScreenOn: Boolean = false
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
                    actions, autoCancel, ongoing, silent, summary, inboxLines,
                    displayStyleMap, soundMap, fullscreen, turnScreenOn
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
        actions: List<Map<String, Any?>>?,
        autoCancel: Boolean,
        ongoing: Boolean,
        silent: Boolean,
        summary: String?,
        inboxLines: List<String>?,
        displayStyleMap: Map<String, Any?>? = null,
        soundMap: Map<String, Any?>? = null,
        fullscreen: Boolean = false,
        turnScreenOn: Boolean = false
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

        // Apply sound configuration
        applySoundConfig(builder, soundMap)

        // Apply fullscreen intent support
        if (fullscreen) {
            val fullscreenIntent = buildTapIntent(id, title, body, deepLink, payload, groupKey)
            builder.setFullScreenIntent(fullscreenIntent, true)
            builder.setCategory(NotificationCompat.CATEGORY_ALARM)
            builder.setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
        }

        // Apply displayStyle from Dart if provided (takes precedence over legacy styles)
        var styleApplied = false
        if (displayStyleMap != null) {
            styleApplied = applyDisplayStyle(builder, displayStyleMap)
        }

        if (!styleApplied) {
            // BigPictureStyle for image notifications (legacy imageUrl support)
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
        }

        // Group support
        if (groupKey != null) {
            builder.setGroup(groupKey)
        }

        // Action buttons (Fix 1: Dart sends "label" not "title", "input" not "isReply")
        actions?.forEach { actionMap ->
            val actionId = actionMap["id"] as? String ?: return@forEach
            val actionLabel = actionMap["label"] as? String ?: return@forEach
            val isInput = actionMap["input"] as? Boolean ?: false
            val inputHint = actionMap["inputHint"] as? String

            val actionIntent = buildActionIntent(id, actionId, actionLabel, deepLink, payload, groupKey)

            if (isInput) {
                val remoteInput = RemoteInput.Builder(REMOTE_INPUT_KEY)
                    .setLabel(inputHint ?: actionLabel)
                    .build()
                val action = NotificationCompat.Action.Builder(0, actionLabel, actionIntent)
                    .addRemoteInput(remoteInput)
                    .build()
                builder.addAction(action)
            } else {
                builder.addAction(0, actionLabel, actionIntent)
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

    /**
     * Applies a Dart-provided displayStyle to the notification builder.
     *
     * @return true if a style was applied, false otherwise
     */
    @Suppress("UNCHECKED_CAST")
    private fun applyDisplayStyle(
        builder: NotificationCompat.Builder,
        displayStyleMap: Map<String, Any?>
    ): Boolean {
        val type = displayStyleMap["type"] as? String ?: return false

        when (type) {
            "bigText" -> {
                val bigText = displayStyleMap["bigText"] as? String ?: return false
                val summaryText = displayStyleMap["summaryText"] as? String
                val style = NotificationCompat.BigTextStyle().bigText(bigText)
                if (summaryText != null) style.setSummaryText(summaryText)
                builder.setStyle(style)
            }
            "bigPicture" -> {
                val pictureMap = displayStyleMap["picture"] as? Map<String, Any?>
                val summaryText = displayStyleMap["summaryText"] as? String
                val bitmap: Bitmap? = if (pictureMap != null) {
                    // Use StyleBuilder.resolveImage for flexible image resolution
                    StyleBuilder.resolveImage(context, pictureMap)
                } else {
                    null
                }
                if (bitmap == null) return false
                val style = NotificationCompat.BigPictureStyle().bigPicture(bitmap)
                if (summaryText != null) style.setSummaryText(summaryText)
                builder.setStyle(style)
            }
            "inbox" -> {
                val lines = displayStyleMap["lines"] as? List<String> ?: return false
                val summaryText = displayStyleMap["summaryText"] as? String
                val style = NotificationCompat.InboxStyle()
                lines.forEach { style.addLine(it) }
                if (summaryText != null) style.setSummaryText(summaryText)
                builder.setStyle(style)
            }
            "messaging" -> {
                val userMap = displayStyleMap["user"] as? Map<String, Any?>
                val userName = userMap?.get("name") as? String ?: "Me"
                val conversationTitle = displayStyleMap["conversationTitle"] as? String
                val isGroupConversation = displayStyleMap["isGroupConversation"] as? Boolean ?: false
                val messages = displayStyleMap["messages"] as? List<Map<String, Any?>> ?: return false

                val userPerson = Person.Builder().setName(userName).build()
                val messagingStyle = NotificationCompat.MessagingStyle(userPerson)
                if (conversationTitle != null) {
                    messagingStyle.setConversationTitle(conversationTitle)
                }
                messagingStyle.setGroupConversation(isGroupConversation)

                messages.forEach { messageMap ->
                    val text = messageMap["text"] as? String ?: return@forEach
                    val timestamp = (messageMap["timestamp"] as? Number)?.toLong()
                        ?: System.currentTimeMillis()
                    val senderName = messageMap["sender"] as? String

                    val sender = if (senderName != null) {
                        Person.Builder().setName(senderName).build()
                    } else {
                        null
                    }

                    messagingStyle.addMessage(text, timestamp, sender)
                }

                builder.setStyle(messagingStyle)
            }
            "progress" -> {
                val progressDouble = (displayStyleMap["progress"] as? Number)?.toDouble() ?: 0.0
                val indeterminate = displayStyleMap["indeterminate"] as? Boolean ?: false
                val progressInt = (progressDouble * 100).toInt().coerceIn(0, 100)
                builder.setProgress(100, progressInt, indeterminate)
            }
            else -> return false
        }
        return true
    }

    /**
     * Applies sound configuration from the Dart-provided soundMap.
     */
    private fun applySoundConfig(
        builder: NotificationCompat.Builder,
        soundMap: Map<String, Any?>?
    ) {
        if (soundMap == null) return

        val type = soundMap["type"] as? String ?: return

        when (type) {
            "none" -> {
                builder.setSound(null)
                builder.setSilent(true)
            }
            "custom" -> {
                val name = soundMap["name"] as? String
                if (name != null) {
                    val soundUri = Uri.parse(
                        "${ContentResolver.SCHEME_ANDROID_RESOURCE}://${context.packageName}/raw/$name"
                    )
                    builder.setSound(soundUri)
                }
            }
            "alarm" -> {
                val alarmUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                builder.setSound(alarmUri)
            }
            // "default" -> default behavior, no action needed
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
