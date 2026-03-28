package dev.notify_pilot

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * BroadcastReceiver for BOOT_COMPLETED. Re-registers all stored scheduled
 * notifications with AlarmManager since alarms are cleared on reboot.
 */
class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == "android.intent.action.QUICKBOOT_POWERON" ||
            intent.action == "com.htc.intent.action.QUICKBOOT_POWERON"
        ) {
            // Ensure default channel exists
            val channelManager = ChannelManager(context)
            channelManager.ensureDefaultChannel()

            // Re-register all stored schedules
            val scheduleManager = ScheduleManager(context)
            scheduleManager.rescheduleAll()
        }
    }
}
