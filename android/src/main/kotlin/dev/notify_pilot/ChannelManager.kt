package dev.notify_pilot

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build

class ChannelManager(private val context: Context) {

    private val notificationManager: NotificationManager
        get() = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    /**
     * Creates a notification channel (API 26+).
     *
     * @param id Channel id
     * @param name Human-readable channel name
     * @param description Channel description
     * @param importance 0-5 mapped to Android importance constants
     * @param soundUri Optional custom sound URI string
     * @param enableVibration Whether vibration is enabled
     * @param enableLights Whether lights are enabled
     * @param showBadge Whether to show badge
     */
    fun createChannel(
        id: String,
        name: String,
        description: String? = null,
        importance: Int = 3,
        soundUri: String? = null,
        enableVibration: Boolean = true,
        enableLights: Boolean = true,
        showBadge: Boolean = true
    ) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val androidImportance = mapImportance(importance)
        val channel = NotificationChannel(id, name, androidImportance).apply {
            this.description = description
            this.enableVibration(enableVibration)
            this.enableLights(enableLights)
            this.setShowBadge(showBadge)

            if (soundUri != null) {
                val audioAttributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
                setSound(Uri.parse(soundUri), audioAttributes)
            }
        }

        notificationManager.createNotificationChannel(channel)
    }

    fun deleteChannel(id: String) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            notificationManager.deleteNotificationChannel(id)
        }
    }

    /**
     * Ensures a default channel exists. Called during plugin initialization.
     */
    fun ensureDefaultChannel() {
        createChannel(
            id = "notify_pilot_default",
            name = "Default",
            description = "Default notification channel",
            importance = 3
        )
    }

    /**
     * Maps importance level 0-5 to Android NotificationManager importance constants.
     *
     * 0 -> IMPORTANCE_NONE
     * 1 -> IMPORTANCE_MIN
     * 2 -> IMPORTANCE_LOW
     * 3 -> IMPORTANCE_DEFAULT
     * 4 -> IMPORTANCE_HIGH
     * 5 -> IMPORTANCE_MAX
     */
    private fun mapImportance(level: Int): Int {
        return when (level) {
            0 -> NotificationManager.IMPORTANCE_NONE
            1 -> NotificationManager.IMPORTANCE_MIN
            2 -> NotificationManager.IMPORTANCE_LOW
            3 -> NotificationManager.IMPORTANCE_DEFAULT
            4 -> NotificationManager.IMPORTANCE_HIGH
            5 -> NotificationManager.IMPORTANCE_MAX
            else -> NotificationManager.IMPORTANCE_DEFAULT
        }
    }
}
