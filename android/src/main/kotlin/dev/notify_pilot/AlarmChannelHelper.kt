package dev.notify_pilot

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build

/**
 * Creates specialized notification channels for alarms, calls, and timers.
 *
 * These channels use specific AudioAttributes usage types and may bypass
 * Do Not Disturb mode for time-critical notifications.
 */
object AlarmChannelHelper {

    /**
     * Creates a notification channel for alarm-type notifications.
     *
     * Uses USAGE_ALARM audio attributes and bypasses DND.
     *
     * @param context Application context
     * @param config Map with keys: id, name, description, soundName, vibrationPattern
     */
    fun createAlarmChannel(context: Context, config: Map<String, Any?>) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val channelId = config["id"] as? String ?: "notify_pilot_alarm"
        val channelName = config["name"] as? String ?: "Alarms"
        val description = config["description"] as? String

        val channel = NotificationChannel(
            channelId,
            channelName,
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            this.description = description
            setBypassDnd(true)
            enableVibration(true)
            enableLights(true)

            // Alarm sound
            val soundName = config["soundName"] as? String
            val soundUri = resolveSoundUri(context, soundName)
            val audioAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            setSound(soundUri, audioAttributes)

            // Custom vibration pattern
            val vibrationPattern = resolveVibrationPattern(config)
            if (vibrationPattern != null) {
                this.vibrationPattern = vibrationPattern
            }
        }

        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.createNotificationChannel(channel)
    }

    /**
     * Creates a notification channel for incoming call notifications.
     *
     * Uses USAGE_NOTIFICATION_RINGTONE audio attributes.
     *
     * @param context Application context
     * @param config Map with keys: id, name, description, soundName, vibrationPattern
     */
    fun createCallChannel(context: Context, config: Map<String, Any?>) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val channelId = config["id"] as? String ?: "notify_pilot_call"
        val channelName = config["name"] as? String ?: "Calls"
        val description = config["description"] as? String

        val channel = NotificationChannel(
            channelId,
            channelName,
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            this.description = description
            setBypassDnd(true)
            enableVibration(true)
            enableLights(true)

            val soundName = config["soundName"] as? String
            val soundUri = resolveSoundUri(context, soundName)
            val audioAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            setSound(soundUri, audioAttributes)

            val vibrationPattern = resolveVibrationPattern(config)
            if (vibrationPattern != null) {
                this.vibrationPattern = vibrationPattern
            }
        }

        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.createNotificationChannel(channel)
    }

    /**
     * Creates a notification channel for timer notifications.
     *
     * Uses USAGE_ALARM audio attributes.
     *
     * @param context Application context
     * @param config Map with keys: id, name, description, soundName, vibrationPattern
     */
    fun createTimerChannel(context: Context, config: Map<String, Any?>) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val channelId = config["id"] as? String ?: "notify_pilot_timer"
        val channelName = config["name"] as? String ?: "Timers"
        val description = config["description"] as? String

        val channel = NotificationChannel(
            channelId,
            channelName,
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            this.description = description
            enableVibration(true)
            enableLights(true)

            val soundName = config["soundName"] as? String
            val soundUri = resolveSoundUri(context, soundName)
            val audioAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            setSound(soundUri, audioAttributes)

            val vibrationPattern = resolveVibrationPattern(config)
            if (vibrationPattern != null) {
                this.vibrationPattern = vibrationPattern
            }
        }

        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.createNotificationChannel(channel)
    }

    // region Private helpers

    /**
     * Resolves a sound URI from the res/raw/ directory by resource name.
     *
     * @param context Application context
     * @param soundName Resource name without extension (e.g. "alarm_sound")
     * @return URI to the raw resource, or null if not found
     */
    private fun resolveSoundUri(context: Context, soundName: String?): Uri? {
        if (soundName.isNullOrBlank()) return null

        val resId = context.resources.getIdentifier(
            soundName, "raw", context.packageName
        )

        return if (resId != 0) {
            Uri.parse("android.resource://${context.packageName}/$resId")
        } else {
            null
        }
    }

    /**
     * Resolves a vibration pattern from the config map.
     *
     * Expects "vibrationPattern" as a List of Numbers (milliseconds).
     *
     * @param config Configuration map
     * @return LongArray vibration pattern, or null if not specified
     */
    @Suppress("UNCHECKED_CAST")
    private fun resolveVibrationPattern(config: Map<String, Any?>): LongArray? {
        val pattern = config["vibrationPattern"] as? List<Number> ?: return null
        if (pattern.isEmpty()) return null
        return pattern.map { it.toLong() }.toLongArray()
    }

    // endregion
}
