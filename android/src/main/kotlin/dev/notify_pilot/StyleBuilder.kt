package dev.notify_pilot

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.util.Base64
import androidx.core.app.NotificationCompat
import androidx.core.app.Person
import androidx.core.graphics.drawable.IconCompat
import java.io.File

/**
 * Builds Android notification styles from Dart-provided style parameters.
 *
 * Supports: bigText, bigPicture, inbox, messaging, media, progress.
 */
object StyleBuilder {

    /**
     * Builds a NotificationCompat.Style from the given style map.
     *
     * For "progress" style, the progress values are set directly on the builder
     * and null is returned (no separate style object needed).
     *
     * @param context Application context
     * @param styleMap Map containing "type" and style-specific parameters
     * @param builder The notification builder (used for progress style)
     * @return The constructed style, or null for progress/unknown types
     */
    fun buildStyle(
        context: Context,
        styleMap: Map<String, Any?>,
        builder: NotificationCompat.Builder? = null
    ): NotificationCompat.Style? {
        val type = styleMap["type"] as? String ?: return null

        return when (type) {
            "bigText" -> buildBigTextStyle(styleMap)
            "bigPicture" -> buildBigPictureStyle(context, styleMap)
            "inbox" -> buildInboxStyle(styleMap)
            "messaging" -> buildMessagingStyle(context, styleMap)
            "media" -> buildMediaStyle(styleMap)
            "progress" -> {
                applyProgressStyle(styleMap, builder)
                null
            }
            else -> null
        }
    }

    // region Style builders

    private fun buildBigTextStyle(styleMap: Map<String, Any?>): NotificationCompat.BigTextStyle {
        val bigText = styleMap["bigText"] as? String ?: ""
        val title = styleMap["title"] as? String
        val summary = styleMap["summary"] as? String

        return NotificationCompat.BigTextStyle()
            .bigText(bigText)
            .also { style ->
                if (title != null) style.setBigContentTitle(title)
                if (summary != null) style.setSummaryText(summary)
            }
    }

    private fun buildBigPictureStyle(
        context: Context,
        styleMap: Map<String, Any?>
    ): NotificationCompat.BigPictureStyle? {
        val title = styleMap["title"] as? String
        val summary = styleMap["summary"] as? String
        val bitmap = resolveImage(context, styleMap) ?: return null

        return NotificationCompat.BigPictureStyle()
            .bigPicture(bitmap)
            .also { style ->
                if (title != null) style.setBigContentTitle(title)
                if (summary != null) style.setSummaryText(summary)
            }
    }

    @Suppress("UNCHECKED_CAST")
    private fun buildInboxStyle(styleMap: Map<String, Any?>): NotificationCompat.InboxStyle {
        val lines = styleMap["lines"] as? List<String> ?: emptyList()
        val title = styleMap["title"] as? String
        val summary = styleMap["summary"] as? String

        return NotificationCompat.InboxStyle().also { style ->
            lines.forEach { style.addLine(it) }
            if (title != null) style.setBigContentTitle(title)
            if (summary != null) style.setSummaryText(summary)
        }
    }

    @Suppress("UNCHECKED_CAST")
    private fun buildMessagingStyle(
        context: Context,
        styleMap: Map<String, Any?>
    ): NotificationCompat.MessagingStyle? {
        val userName = styleMap["userName"] as? String ?: "Me"
        val conversationTitle = styleMap["conversationTitle"] as? String
        val isGroupConversation = styleMap["isGroupConversation"] as? Boolean ?: false
        val messages = styleMap["messages"] as? List<Map<String, Any?>> ?: return null

        val userPerson = Person.Builder()
            .setName(userName)
            .build()

        val messagingStyle = NotificationCompat.MessagingStyle(userPerson)
        if (conversationTitle != null) {
            messagingStyle.setConversationTitle(conversationTitle)
        }
        messagingStyle.setGroupConversation(isGroupConversation)

        messages.forEach { messageMap ->
            val text = messageMap["text"] as? String ?: return@forEach
            val timestamp = (messageMap["timestamp"] as? Number)?.toLong() ?: System.currentTimeMillis()
            val senderName = messageMap["sender"] as? String

            val sender = if (senderName != null) {
                val personBuilder = Person.Builder().setName(senderName)

                // Optional sender icon
                @Suppress("UNCHECKED_CAST")
                val iconMap = messageMap["icon"] as? Map<String, Any?>
                if (iconMap != null) {
                    val iconBitmap = resolveImage(context, iconMap)
                    if (iconBitmap != null) {
                        personBuilder.setIcon(IconCompat.createWithBitmap(iconBitmap))
                    }
                }

                personBuilder.build()
            } else {
                null
            }

            messagingStyle.addMessage(text, timestamp, sender)
        }

        return messagingStyle
    }

    private fun buildMediaStyle(styleMap: Map<String, Any?>): androidx.media.app.NotificationCompat.MediaStyle? {
        // MediaStyle requires the media compat library
        return try {
            val showActions = styleMap["showActionsInCompactView"] as? List<*>
            val style = androidx.media.app.NotificationCompat.MediaStyle()

            if (!showActions.isNullOrEmpty()) {
                val indices = showActions.mapNotNull { (it as? Number)?.toInt() }.toIntArray()
                style.setShowActionsInCompactView(*indices)
            }

            // Media session token is set externally via MediaSessionHelper
            style
        } catch (_: Exception) {
            // media compat dependency may not be available
            null
        }
    }

    private fun applyProgressStyle(
        styleMap: Map<String, Any?>,
        builder: NotificationCompat.Builder?
    ) {
        if (builder == null) return

        val max = (styleMap["max"] as? Number)?.toInt() ?: 100
        val progress = (styleMap["progress"] as? Number)?.toInt() ?: 0
        val indeterminate = styleMap["indeterminate"] as? Boolean ?: false

        builder.setProgress(max, progress, indeterminate)
    }

    // endregion

    // region Image resolution

    /**
     * Resolves an image from various source types.
     *
     * Supported source types in the map:
     *   - "url"      -> Downloads from network URL
     *   - "asset"    -> Loads from Flutter asset path
     *   - "file"     -> Loads from absolute file path
     *   - "bytes"    -> Decodes from Base64-encoded string
     *   - "resource" -> Loads from Android drawable resource name
     *
     * @param context Application context
     * @param imageMap Map containing "source" (type) and "value" (path/url/data)
     * @return Decoded Bitmap, or null on failure
     */
    fun resolveImage(context: Context, imageMap: Map<String, Any?>): Bitmap? {
        val source = imageMap["source"] as? String
        val value = imageMap["value"] as? String

        if (source == null && value == null) {
            // Try direct URL field (legacy / simple usage)
            val url = imageMap["url"] as? String
            if (url != null) return MediaDownloader.downloadSync(url)
            return null
        }

        if (value == null) return null

        return when (source) {
            "url" -> MediaDownloader.downloadSync(value)
            "asset" -> loadAssetBitmap(context, value)
            "file" -> loadFileBitmap(value)
            "bytes" -> decodeBase64Bitmap(value)
            "resource" -> loadResourceBitmap(context, value)
            else -> null
        }
    }

    private fun loadAssetBitmap(context: Context, assetPath: String): Bitmap? {
        return try {
            val key = if (assetPath.startsWith("flutter_assets/")) {
                assetPath
            } else {
                "flutter_assets/$assetPath"
            }
            val inputStream = context.assets.open(key)
            BitmapFactory.decodeStream(inputStream).also {
                inputStream.close()
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun loadFileBitmap(filePath: String): Bitmap? {
        return try {
            val file = File(filePath)
            if (file.exists()) {
                BitmapFactory.decodeFile(filePath)
            } else {
                null
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun decodeBase64Bitmap(base64String: String): Bitmap? {
        return try {
            val bytes = Base64.decode(base64String, Base64.DEFAULT)
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
        } catch (_: Exception) {
            null
        }
    }

    private fun loadResourceBitmap(context: Context, resourceName: String): Bitmap? {
        return try {
            val resId = context.resources.getIdentifier(
                resourceName, "drawable", context.packageName
            )
            if (resId != 0) {
                BitmapFactory.decodeResource(context.resources, resId)
            } else {
                null
            }
        } catch (_: Exception) {
            null
        }
    }

    // endregion
}
