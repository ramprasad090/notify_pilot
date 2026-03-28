package dev.notify_pilot

import android.app.Activity
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.EventChannel
import org.json.JSONArray

/** NotifyPilotPlugin */
class NotifyPilotPlugin :
    FlutterPlugin,
    MethodCallHandler,
    ActivityAware {

    private lateinit var channel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var applicationContext: Context? = null
    private var activity: Activity? = null

    private lateinit var displayManager: NotificationDisplayManager
    private lateinit var channelManager: ChannelManager
    private lateinit var scheduleManager: ScheduleManager
    private lateinit var historyStore: HistoryStore
    private var liveNotificationManager: LiveNotificationManager? = null
    private var mediaSessionHelper: MediaSessionHelper? = null
    private var callNotificationManager: CallNotificationManager? = null

    companion object {
        private var staticChannel: MethodChannel? = null

        /**
         * Invokes a method on the Dart side from anywhere (ActionHandler, AlarmReceiver, etc.).
         */
        fun invokeMethod(method: String, arguments: Any?) {
            staticChannel?.let { ch ->
                try {
                    android.os.Handler(android.os.Looper.getMainLooper()).post {
                        ch.invokeMethod(method, arguments)
                    }
                } catch (_: Exception) {
                    // Channel may not be available if app is not running
                }
            }
        }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext

        channel = MethodChannel(binding.binaryMessenger, "dev.notify_pilot/channel")
        channel.setMethodCallHandler(this)
        staticChannel = channel

        eventChannel = EventChannel(binding.binaryMessenger, "dev.notify_pilot/events")
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                // Events are sent via the method channel invokeMethod pattern
                // EventChannel kept for potential future streaming use
            }

            override fun onCancel(arguments: Any?) {}
        })

        displayManager = NotificationDisplayManager(binding.applicationContext)
        channelManager = ChannelManager(binding.applicationContext)
        scheduleManager = ScheduleManager(binding.applicationContext)
        historyStore = HistoryStore(binding.applicationContext)
        liveNotificationManager = LiveNotificationManager(binding.applicationContext)
        mediaSessionHelper = MediaSessionHelper(binding.applicationContext)
        callNotificationManager = CallNotificationManager(binding.applicationContext)
        callNotificationManager?.onCallEvent = { callId, event, data ->
            val args = mutableMapOf<String, Any?>(
                "callId" to callId,
                "event" to event,
            )
            if (data != null) args.putAll(data)
            invokeMethod("onCallEvent", args)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        staticChannel = null
        applicationContext = null
    }

    // region ActivityAware

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    // endregion

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "initialize" -> handleInitialize(call, result)
            "show" -> handleShow(call, result)
            "scheduleAt" -> handleScheduleAt(call, result)
            "scheduleAfter" -> handleScheduleAfter(call, result)
            "scheduleCron" -> handleScheduleCron(call, result)
            "cancel" -> handleCancel(call, result)
            "cancelGroup" -> handleCancelGroup(call, result)
            "cancelAll" -> handleCancelAll(result)
            "cancelSchedule" -> handleCancelSchedule(call, result)
            "getActive" -> handleGetActive(result)
            "getScheduled" -> handleGetScheduled(result)
            "createChannel" -> handleCreateChannel(call, result)
            "deleteChannel" -> handleDeleteChannel(call, result)
            "requestPermission" -> handleRequestPermission(result)
            "getPermission" -> handleGetPermission(result)
            "setBadge" -> handleSetBadge(call, result)
            "getFcmToken" -> handleGetFcmToken(result)
            "subscribeTopic" -> handleSubscribeTopic(call, result)
            "unsubscribeTopic" -> handleUnsubscribeTopic(call, result)
            "getHistory" -> handleGetHistory(call, result)
            "clearHistory" -> handleClearHistory(result)
            "getUnreadCount" -> handleGetUnreadCount(result)
            "markRead" -> handleMarkRead(call, result)
            "openSettings" -> handleOpenSettings(result)
            // Live Activities (ongoing notifications on Android)
            "startLiveActivity" -> handleStartLiveActivity(call, result)
            "updateLiveActivity" -> handleUpdateLiveActivity(call, result)
            "endLiveActivity" -> handleEndLiveActivity(call, result)
            "endAllLiveActivities" -> handleEndAllLiveActivities(call, result)
            "getLiveActivityPushToken" -> result.success(null) // iOS only
            "isLiveActivitySupported" -> result.success(true) // Always supported on Android
            "hasDynamicIsland" -> result.success(false) // iOS only
            "getActiveLiveActivities" -> handleGetActiveLiveActivities(result)
            "getLiveActivityStatus" -> handleGetLiveActivityStatus(call, result)
            // v1.0.2
            "updateProgress" -> handleUpdateProgress(call, result)
            "setMediaPlaybackState" -> handleSetMediaPlaybackState(call, result)
            "hasCriticalAlertEntitlement" -> result.success(false) // iOS only
            // Call notifications
            "showIncomingCall" -> handleShowIncomingCall(call, result)
            "showOutgoingCall" -> handleShowOutgoingCall(call, result)
            "setCallConnected" -> handleSetCallConnected(call, result)
            "endCall" -> handleEndCall(call, result)
            "showMissedCall" -> handleShowMissedCall(call, result)
            "getActiveCalls" -> handleGetActiveCalls(result)
            "hideIncomingCall" -> handleHideIncomingCall(call, result)
            else -> result.notImplemented()
        }
    }

    // region Method Handlers

    private fun handleInitialize(call: MethodCall, result: Result) {
        channelManager.ensureDefaultChannel()
        result.success(true)
    }

    private fun handleShow(call: MethodCall, result: Result) {
        val id = call.argument<Int>("id") ?: 0
        val title = call.argument<String>("title")
        val body = call.argument<String>("body")
        val channelId = call.argument<String>("channelId")
        val groupKey = call.argument<String>("group")
        val imageUrl = call.argument<String>("image")
        val deepLink = call.argument<String>("deepLink")
        // payload can be sent as Map or String from Dart
        val payloadRaw = call.argument<Any>("payload")
        val payload: String? = when (payloadRaw) {
            is String -> payloadRaw
            is Map<*, *> -> org.json.JSONObject(payloadRaw as Map<String, Any?>).toString()
            else -> null
        }
        val autoCancel = call.argument<Boolean>("autoCancel") ?: true
        val ongoingFlag = call.argument<Boolean>("ongoing") ?: false
        val silent = call.argument<Boolean>("silent") ?: false
        val summary = call.argument<String>("summary")
        val inboxLines = call.argument<List<String>>("inboxLines")

        // v1.0.2: new fields (read but passed to displayManager as available)
        val largeIconMap = call.argument<Map<String, Any?>>("largeIcon")
        val largeIconUrl = largeIconMap?.get("url") as? String
            ?: call.argument<String>("largeIconUrl")

        @Suppress("UNCHECKED_CAST")
        val actions = call.argument<List<Map<String, Any>>>("actions")

        // v1.0.2: Read new parameters
        @Suppress("UNCHECKED_CAST")
        val displayStyle = call.argument<Map<String, Any?>>("displayStyle")
        val soundMap = call.argument<Map<String, Any?>>("sound")
        val iconMap = call.argument<Map<String, Any?>>("icon")
        val fullscreen = call.argument<Boolean>("fullscreen") ?: false
        val turnScreenOn = call.argument<Boolean>("turnScreenOn") ?: false

        displayManager.show(
            id = id, title = title, body = body, channelId = channelId,
            groupKey = groupKey, imageUrl = imageUrl, largeIconUrl = largeIconUrl,
            deepLink = deepLink, payload = payload, actions = actions,
            autoCancel = autoCancel, ongoing = ongoingFlag, silent = silent,
            summary = summary, inboxLines = inboxLines,
            displayStyleMap = displayStyle,
            soundMap = soundMap,
            fullscreen = fullscreen,
            turnScreenOn = turnScreenOn,
        )

        // Record in history
        historyStore.insert(
            id = id, title = title, body = body, channelId = channelId,
            groupKey = groupKey, deepLink = deepLink, payload = payload
        )

        result.success(id)
    }

    private fun handleScheduleAt(call: MethodCall, result: Result) {
        val id = call.argument<Int>("id") ?: 0
        val triggerAtMillis = call.argument<Number>("triggerAtMillis")?.toLong() ?: 0L
        val title = call.argument<String>("title")
        val body = call.argument<String>("body")
        val channelId = call.argument<String>("channelId")
        val groupKey = call.argument<String>("groupKey")
        val deepLink = call.argument<String>("deepLink")
        val payload = call.argument<String>("payload")
        val actionsJson = call.argument<String>("actions")

        scheduleManager.scheduleAt(
            id, triggerAtMillis, title, body, channelId, groupKey, deepLink, payload, actionsJson
        )
        result.success(id)
    }

    private fun handleScheduleAfter(call: MethodCall, result: Result) {
        val id = call.argument<Int>("id") ?: 0
        val delayMillis = call.argument<Number>("delayMillis")?.toLong() ?: 0L
        val title = call.argument<String>("title")
        val body = call.argument<String>("body")
        val channelId = call.argument<String>("channelId")
        val groupKey = call.argument<String>("groupKey")
        val deepLink = call.argument<String>("deepLink")
        val payload = call.argument<String>("payload")
        val actionsJson = call.argument<String>("actions")

        scheduleManager.scheduleAfter(
            id, delayMillis, title, body, channelId, groupKey, deepLink, payload, actionsJson
        )
        result.success(id)
    }

    private fun handleScheduleCron(call: MethodCall, result: Result) {
        val id = call.argument<Int>("id") ?: 0
        val triggerAtMillis = call.argument<Number>("triggerAtMillis")?.toLong() ?: 0L
        val cronExpression = call.argument<String>("cronExpression") ?: ""
        val title = call.argument<String>("title")
        val body = call.argument<String>("body")
        val channelId = call.argument<String>("channelId")
        val groupKey = call.argument<String>("groupKey")
        val deepLink = call.argument<String>("deepLink")
        val payload = call.argument<String>("payload")
        val actionsJson = call.argument<String>("actions")

        scheduleManager.scheduleCron(
            id, triggerAtMillis, cronExpression, title, body, channelId, groupKey, deepLink, payload, actionsJson
        )
        result.success(id)
    }

    private fun handleCancel(call: MethodCall, result: Result) {
        val id = call.argument<Int>("id") ?: 0
        val ctx = applicationContext ?: run {
            result.error("NO_CONTEXT", "Application context not available", null)
            return
        }
        val notificationManager = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.cancel(id)
        result.success(true)
    }

    private fun handleCancelGroup(call: MethodCall, result: Result) {
        val groupKey = call.argument<String>("groupKey") ?: run {
            result.error("INVALID_ARGS", "groupKey is required", null)
            return
        }
        val ctx = applicationContext ?: run {
            result.error("NO_CONTEXT", "Application context not available", null)
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val notificationManager = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val activeNotifications = notificationManager.activeNotifications
            for (notification in activeNotifications) {
                if (notification.notification.group == groupKey) {
                    notificationManager.cancel(notification.id)
                }
            }
        }
        result.success(true)
    }

    private fun handleCancelAll(result: Result) {
        val ctx = applicationContext ?: run {
            result.error("NO_CONTEXT", "Application context not available", null)
            return
        }
        val notificationManager = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.cancelAll()
        result.success(true)
    }

    private fun handleCancelSchedule(call: MethodCall, result: Result) {
        val id = call.argument<Int>("id") ?: 0
        scheduleManager.cancel(id)
        result.success(true)
    }

    private fun handleGetActive(result: Result) {
        val ctx = applicationContext ?: run {
            result.success(emptyList<Map<String, Any>>())
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val notificationManager = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val active = notificationManager.activeNotifications.map { sbn ->
                mapOf(
                    "id" to sbn.id,
                    "tag" to sbn.tag,
                    "groupKey" to sbn.notification.group
                )
            }
            result.success(active)
        } else {
            result.success(emptyList<Map<String, Any>>())
        }
    }

    private fun handleGetScheduled(result: Result) {
        result.success(scheduleManager.getScheduled())
    }

    private fun handleCreateChannel(call: MethodCall, result: Result) {
        val id = call.argument<String>("id") ?: run {
            result.error("INVALID_ARGS", "Channel id is required", null)
            return
        }
        val name = call.argument<String>("name") ?: id
        val description = call.argument<String>("description")
        val importance = call.argument<Int>("importance") ?: 3
        val soundUri = call.argument<String>("soundUri")
        val enableVibration = call.argument<Boolean>("enableVibration") ?: true
        val enableLights = call.argument<Boolean>("enableLights") ?: true
        val showBadge = call.argument<Boolean>("showBadge") ?: true

        channelManager.createChannel(
            id, name, description, importance, soundUri, enableVibration, enableLights, showBadge
        )
        result.success(true)
    }

    private fun handleDeleteChannel(call: MethodCall, result: Result) {
        val id = call.argument<String>("id") ?: run {
            result.error("INVALID_ARGS", "Channel id is required", null)
            return
        }
        channelManager.deleteChannel(id)
        result.success(true)
    }

    private fun handleRequestPermission(result: Result) {
        val requested = PermissionHelper.requestPermission(activity)
        if (!requested) {
            // Already granted or not needed
            val status = PermissionHelper.getPermissionStatus(activity)
            result.success(status == "granted")
        } else {
            // The permission dialog is shown; return false for now
            // Dart side should re-check with getPermission after user responds
            result.success(false)
        }
    }

    private fun handleGetPermission(result: Result) {
        result.success(PermissionHelper.getPermissionStatus(activity))
    }

    private fun handleSetBadge(call: MethodCall, result: Result) {
        val count = call.argument<Int>("count") ?: 0
        val ctx = applicationContext ?: run {
            result.error("NO_CONTEXT", "Application context not available", null)
            return
        }
        // Use ShortcutBadger-style intent for launchers that support it
        try {
            val badgeIntent = Intent("android.intent.action.BADGE_COUNT_UPDATE").apply {
                putExtra("badge_count", count)
                putExtra("badge_count_package_name", ctx.packageName)
                putExtra(
                    "badge_count_class_name",
                    ctx.packageManager.getLaunchIntentForPackage(ctx.packageName)
                        ?.component?.className ?: ""
                )
            }
            ctx.sendBroadcast(badgeIntent)
            result.success(true)
        } catch (_: Exception) {
            result.success(false)
        }
    }

    private fun handleGetFcmToken(result: Result) {
        FcmHandler.getToken { token ->
            android.os.Handler(android.os.Looper.getMainLooper()).post {
                result.success(token)
            }
        }
    }

    private fun handleSubscribeTopic(call: MethodCall, result: Result) {
        val topic = call.argument<String>("topic") ?: run {
            result.error("INVALID_ARGS", "topic is required", null)
            return
        }
        FcmHandler.subscribeTopic(topic) { success ->
            android.os.Handler(android.os.Looper.getMainLooper()).post {
                result.success(success)
            }
        }
    }

    private fun handleUnsubscribeTopic(call: MethodCall, result: Result) {
        val topic = call.argument<String>("topic") ?: run {
            result.error("INVALID_ARGS", "topic is required", null)
            return
        }
        FcmHandler.unsubscribeTopic(topic) { success ->
            android.os.Handler(android.os.Looper.getMainLooper()).post {
                result.success(success)
            }
        }
    }

    private fun handleGetHistory(call: MethodCall, result: Result) {
        val limit = call.argument<Int>("limit") ?: 100
        val groupFilter = call.argument<String>("groupKey")
        result.success(historyStore.query(limit, groupFilter))
    }

    private fun handleClearHistory(result: Result) {
        historyStore.clearAll()
        result.success(true)
    }

    private fun handleGetUnreadCount(result: Result) {
        result.success(historyStore.getUnreadCount())
    }

    private fun handleMarkRead(call: MethodCall, result: Result) {
        val id = call.argument<Int>("id")
        if (id != null) {
            historyStore.markRead(id)
        } else {
            historyStore.markAllRead()
        }
        result.success(true)
    }

    // region Live Activity Handlers

    @Suppress("UNCHECKED_CAST")
    private fun handleStartLiveActivity(call: MethodCall, result: Result) {
        val type = call.argument<String>("type") ?: "live"
        val config = call.argument<Map<String, Any>>("androidConfig") ?: emptyMap()
        val state = call.argument<Map<String, Any>>("state") ?: emptyMap()
        val activityId = "${type}_${System.currentTimeMillis()}"
        liveNotificationManager?.startLiveNotification(activityId, config + mapOf("type" to type), state)
        result.success(activityId)
    }

    @Suppress("UNCHECKED_CAST")
    private fun handleUpdateLiveActivity(call: MethodCall, result: Result) {
        val activityId = call.argument<String>("activityId") ?: ""
        val state = call.argument<Map<String, Any>>("state") ?: emptyMap()
        liveNotificationManager?.updateLiveNotification(activityId, state)
        result.success(true)
    }

    private fun handleEndLiveActivity(call: MethodCall, result: Result) {
        val activityId = call.argument<String>("activityId") ?: ""
        liveNotificationManager?.endLiveNotification(activityId)
        result.success(true)
    }

    private fun handleEndAllLiveActivities(call: MethodCall, result: Result) {
        val type = call.argument<String>("type")
        liveNotificationManager?.endAllLiveNotifications(type)
        result.success(true)
    }

    private fun handleGetActiveLiveActivities(result: Result) {
        val activities = liveNotificationManager?.getActiveLiveNotifications() ?: emptyList()
        result.success(activities)
    }

    private fun handleGetLiveActivityStatus(call: MethodCall, result: Result) {
        val activityId = call.argument<String>("activityId") ?: ""
        val status = liveNotificationManager?.getLiveNotificationStatus(activityId) ?: "ended"
        result.success(status)
    }

    // endregion

    // region v1.0.2 Handlers

    private fun handleUpdateProgress(call: MethodCall, result: Result) {
        val id = call.argument<Int>("id") ?: 0
        val progress = call.argument<Double>("progress") ?: 0.0
        val title = call.argument<String>("title")
        val ongoing = call.argument<Boolean>("ongoing")

        displayManager.show(
            id = id,
            title = title ?: "Downloading...",
            body = "${(progress * 100).toInt()}% complete",
            channelId = null,
            groupKey = null,
            imageUrl = null,
            largeIconUrl = null,
            deepLink = null,
            payload = null,
            actions = null,
            autoCancel = !(ongoing ?: (progress < 1.0)),
            ongoing = ongoing ?: (progress < 1.0),
            silent = true,
            summary = null,
            inboxLines = null
        )
        result.success(true)
    }

    private fun handleSetMediaPlaybackState(call: MethodCall, result: Result) {
        val isPlaying = call.argument<Boolean>("isPlaying") ?: false
        val positionMs = call.argument<Number>("positionMs")?.toLong() ?: 0L
        mediaSessionHelper?.updatePlaybackState(isPlaying, positionMs)
        result.success(true)
    }

    // endregion

    // region Call Notification Handlers

    @Suppress("UNCHECKED_CAST")
    private fun handleShowIncomingCall(call: MethodCall, result: Result) {
        val callId = call.argument<String>("callId") ?: run {
            result.error("INVALID_ARGS", "callId is required", null)
            return
        }
        val callerName = call.argument<String>("callerName") ?: ""
        val callerNumber = call.argument<String>("callerNumber")
        val callerAvatarMap = call.argument<Map<String, Any?>>("callerAvatar")
        val callerAvatar = callerAvatarMap?.get("url") as? String
        val callType = call.argument<String>("callType")
        val ringtone = call.argument<String>("ringtone")
        val timeoutMs = call.argument<Number>("timeoutMs")?.toLong() ?: 0L
        val acceptText = call.argument<String>("acceptText")
        val declineText = call.argument<String>("declineText")
        val extra = call.argument<Map<String, Any?>>("extra")

        callNotificationManager?.showIncomingCall(
            callId = callId,
            callerName = callerName,
            callerNumber = callerNumber,
            callerAvatar = callerAvatar,
            callType = callType,
            ringtone = ringtone,
            timeoutMs = timeoutMs,
            acceptText = acceptText,
            declineText = declineText,
            extra = extra
        )
        result.success(true)
    }

    private fun handleShowOutgoingCall(call: MethodCall, result: Result) {
        val callId = call.argument<String>("callId") ?: run {
            result.error("INVALID_ARGS", "callId is required", null)
            return
        }
        val callerName = call.argument<String>("callerName") ?: ""
        val callerNumber = call.argument<String>("callerNumber")
        val callerAvatarMap = call.argument<Map<String, Any?>>("callerAvatar")
        val callerAvatar = callerAvatarMap?.get("url") as? String
        val callType = call.argument<String>("callType")

        callNotificationManager?.showOutgoingCall(
            callId = callId,
            callerName = callerName,
            callerNumber = callerNumber,
            callType = callType
        )
        result.success(true)
    }

    private fun handleSetCallConnected(call: MethodCall, result: Result) {
        val callId = call.argument<String>("callId") ?: run {
            result.error("INVALID_ARGS", "callId is required", null)
            return
        }
        callNotificationManager?.setCallConnected(callId)
        result.success(true)
    }

    private fun handleEndCall(call: MethodCall, result: Result) {
        val callId = call.argument<String>("callId") ?: run {
            result.error("INVALID_ARGS", "callId is required", null)
            return
        }
        callNotificationManager?.endCall(callId)
        result.success(true)
    }

    @Suppress("UNCHECKED_CAST")
    private fun handleShowMissedCall(call: MethodCall, result: Result) {
        val callId = call.argument<String>("callId") ?: run {
            result.error("INVALID_ARGS", "callId is required", null)
            return
        }
        val callerName = call.argument<String>("callerName") ?: ""
        val callerNumber = call.argument<String>("callerNumber")
        val callerAvatarMap = call.argument<Map<String, Any?>>("callerAvatar")
        val callerAvatar = callerAvatarMap?.get("url") as? String
        val time = call.argument<Number>("time")?.toLong() ?: System.currentTimeMillis()
        val actions = call.argument<List<Map<String, Any?>>>("actions")

        callNotificationManager?.showMissedCall(
            callId = callId,
            callerName = callerName,
            callerNumber = callerNumber,
            time = time,
            actions = actions
        )
        result.success(true)
    }

    private fun handleGetActiveCalls(result: Result) {
        val calls = callNotificationManager?.getActiveCalls() ?: emptyList()
        result.success(calls)
    }

    private fun handleHideIncomingCall(call: MethodCall, result: Result) {
        val callId = call.argument<String>("callId") ?: run {
            result.error("INVALID_ARGS", "callId is required", null)
            return
        }
        callNotificationManager?.hideIncomingCall(callId)
        result.success(true)
    }

    // endregion

    private fun handleOpenSettings(result: Result) {
        val ctx = applicationContext ?: run {
            result.error("NO_CONTEXT", "Application context not available", null)
            return
        }
        try {
            val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                    putExtra(Settings.EXTRA_APP_PACKAGE, ctx.packageName)
                }
            } else {
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = android.net.Uri.parse("package:${ctx.packageName}")
                }
            }
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            ctx.startActivity(intent)
            result.success(true)
        } catch (_: Exception) {
            result.success(false)
        }
    }

    // endregion
}
