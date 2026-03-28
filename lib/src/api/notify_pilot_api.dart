import 'dart:async';

import '../core/analytics_emitter.dart';
import '../core/channel_manager.dart';
import '../core/group_manager.dart';
import '../core/history_manager.dart';
import '../core/id_generator.dart';
import '../core/permission_manager.dart';
import '../core/schedule_manager.dart';
import '../platform/notify_pilot_platform.dart';
import 'call_types.dart';
import 'enums.dart';
import 'fcm_config.dart';
import 'history_config.dart';
import 'live_activity_config.dart';
import 'live_activity_event.dart';
import 'live_activity_info.dart';
import 'notify_action.dart';
import 'notify_action_event.dart';
import 'notify_analytics.dart';
import 'notify_channel.dart';
import 'notify_display_style.dart';
import 'notify_history_entry.dart';
import 'notify_icon.dart';
import 'notify_image.dart';
import 'notify_sound.dart';
import 'notify_style.dart';
import 'notify_tap_event.dart';
import 'push_message.dart';

/// Unified notification API for Flutter.
///
/// Provides a single static API for local notifications, push notifications
/// (FCM), and scheduled notifications with minimal boilerplate.
///
/// ```dart
/// await NotifyPilot.initialize();
/// await NotifyPilot.show('Hello!', body: 'World');
/// ```
class NotifyPilot {
  NotifyPilot._();

  static bool _initialized = false;
  static final ChannelManager _channelManager = ChannelManager();
  static final GroupManager _groupManager = GroupManager();
  static final ScheduleManager _scheduleManager = ScheduleManager();
  static final HistoryManager _historyManager = HistoryManager();
  static final AnalyticsEmitter _analyticsEmitter = AnalyticsEmitter();
  static final PermissionManager _permissionManager = PermissionManager();

  static void Function(NotifyTapEvent event)? _onTap;
  static void Function(NotifyActionEvent event)? _onAction;
  static FcmConfig? _fcmConfig;
  // ignore: unused_field
  static LiveActivityInitConfig? _liveActivityConfig;
  static String _androidIcon = '@mipmap/ic_launcher';
  static Future<int?> Function(PushMessage message)? _onPush;
  static void Function(String token)? _onTokenRefresh;
  static final Map<String, StreamController<LiveActivityEvent>>
      _liveActivityEventControllers = {};
  static final Map<String, StreamController<String>>
      _liveActivityPushTokenControllers = {};
  static final StreamController<CallEvent> _callEventController =
      StreamController<CallEvent>.broadcast();

  /// Initializes the notification system.
  ///
  /// Must be called before any other [NotifyPilot] method,
  /// typically in `main()` after `WidgetsFlutterBinding.ensureInitialized()`.
  ///
  /// Handles timezone setup, permission requests, channel creation,
  /// and optional FCM configuration automatically.
  static Future<void> initialize({
    NotifyChannel? defaultChannel,
    List<NotifyChannel> channels = const [],
    FcmConfig? fcm,
    LiveActivityInitConfig? liveActivity,
    void Function(NotifyTapEvent event)? onTap,
    void Function(NotifyActionEvent event)? onAction,
    void Function(NotifyTapEvent event)? onLaunch,
    NotifyAnalytics? analytics,
    HistoryConfig? history,
    String androidIcon = '@mipmap/ic_launcher',
  }) async {
    if (_initialized) return;

    _onTap = onTap;
    _onAction = onAction;
    _fcmConfig = fcm;
    _liveActivityConfig = liveActivity;
    _androidIcon = androidIcon;

    // Initialize analytics
    _analyticsEmitter.initialize(analytics);

    // Initialize history
    _historyManager.initialize(history);

    // Set up event handler for native callbacks
    NotifyPilotPlatform.instance.setEventHandler(_handleNativeEvent);

    // Initialize native platform
    await NotifyPilotPlatform.instance.initialize({
      'androidIcon': androidIcon,
      'history': history?.toMap(),
      'fcmEnabled': fcm != null,
      'fcmTopics': fcm?.topics ?? [],
      'liveActivity': liveActivity?.toMap(),
    });

    // Initialize channels
    await _channelManager.initialize(
      defaultChannel: defaultChannel,
      channels: channels,
    );

    // Handle FCM token
    if (fcm != null) {
      final token = await NotifyPilotPlatform.instance.getFcmToken();
      if (token != null) {
        fcm.onToken?.call(token);
      }
    }

    _initialized = true;
  }

  /// Displays a notification immediately.
  ///
  /// Returns the notification ID (auto-generated or overridden via [id]).
  ///
  /// ```dart
  /// await NotifyPilot.show('Hello!');
  /// await NotifyPilot.show('Order shipped!', body: 'Order #1234 is on the way');
  /// ```
  static Future<int> show(
    String title, {
    String? body,
    String? image,
    String? channel,
    String? group,
    String? deepLink,
    Map<String, dynamic>? payload,
    List<NotifyAction>? actions,
    NotifyStyle? style,
    int? id,
    // v1.0.2: Rich media & styles
    NotifySound? sound,
    NotifyIcon? icon,
    NotifyIcon? largeIcon,
    NotifyImage? notifyImage,
    NotifyDisplayStyle? displayStyle,
    bool? fullscreen,
    bool? turnScreenOn,
    bool? ongoing,
  }) async {
    _ensureInitialized();

    final notifId = id ?? IdGenerator.generate();
    final resolvedChannel = _channelManager.resolve(channel);

    final data = <String, dynamic>{
      'id': notifId,
      'title': title,
      'body': body,
      'image': image,
      'channelId': resolvedChannel.id,
      'channelName': resolvedChannel.name,
      'channelImportance': resolvedChannel.importance.index,
      'group': group,
      'deepLink': deepLink,
      'payload': payload,
      'actions': actions?.map((a) => a.toMap()).toList(),
      'style': style?.toMap(),
      'androidIcon': _androidIcon,
      // v1.0.2
      'sound': sound?.toMap(),
      'icon': icon?.toMap(),
      'largeIcon': largeIcon?.toMap(),
      'notifyImage': notifyImage?.toMap(),
      'displayStyle': displayStyle?.toMap(),
      'fullscreen': fullscreen,
      'turnScreenOn': turnScreenOn,
      'ongoing': ongoing,
    };

    if (group != null) {
      _groupManager.addToGroup(group, notifId);
      data['groupSummaryId'] = _groupManager.getSummaryId(group);
      data['groupCount'] = _groupManager.groupCount(group);
    }

    final resultId = await NotifyPilotPlatform.instance.show(data);

    // Record in history
    if (_historyManager.isEnabled) {
      final entry = NotifyHistoryEntry(
        id: resultId,
        title: title,
        body: body,
        channel: resolvedChannel.id,
        group: group,
        deepLink: deepLink,
        payload: payload,
        timestamp: DateTime.now(),
      );
      await _historyManager.record(entry);
      _analyticsEmitter.onDelivered(entry);
    }

    return resultId;
  }

  /// Schedules a notification at a specific date and time.
  ///
  /// Timezone is handled automatically — just pass a regular [DateTime].
  ///
  /// ```dart
  /// await NotifyPilot.scheduleAt(
  ///   DateTime(2026, 4, 1, 9, 0),
  ///   title: 'Meeting in 15 minutes',
  /// );
  /// ```
  static Future<int> scheduleAt(
    DateTime dateTime, {
    required String title,
    String? body,
    String? channel,
    String? group,
    String? deepLink,
    Map<String, dynamic>? payload,
    List<NotifyAction>? actions,
    NotifyStyle? style,
    int? id,
  }) async {
    _ensureInitialized();

    final resolvedChannel = _channelManager.resolve(channel);
    return _scheduleManager.scheduleAt(
      dateTime,
      title: title,
      body: body,
      id: id,
      extra: {
        'channelId': resolvedChannel.id,
        'channelName': resolvedChannel.name,
        'channelImportance': resolvedChannel.importance.index,
        'group': group,
        'deepLink': deepLink,
        'payload': payload,
        'actions': actions?.map((a) => a.toMap()).toList(),
        'style': style?.toMap(),
        'androidIcon': _androidIcon,
      },
    );
  }

  /// Schedules a notification after a delay.
  ///
  /// ```dart
  /// await NotifyPilot.scheduleAfter(
  ///   Duration(hours: 2),
  ///   title: 'Check on your order',
  /// );
  /// ```
  static Future<int> scheduleAfter(
    Duration delay, {
    required String title,
    String? body,
    String? channel,
    String? group,
    String? deepLink,
    Map<String, dynamic>? payload,
    List<NotifyAction>? actions,
    NotifyStyle? style,
    int? id,
  }) async {
    _ensureInitialized();

    final resolvedChannel = _channelManager.resolve(channel);
    return _scheduleManager.scheduleAfter(
      delay,
      title: title,
      body: body,
      id: id,
      extra: {
        'channelId': resolvedChannel.id,
        'channelName': resolvedChannel.name,
        'channelImportance': resolvedChannel.importance.index,
        'group': group,
        'deepLink': deepLink,
        'payload': payload,
        'actions': actions?.map((a) => a.toMap()).toList(),
        'style': style?.toMap(),
        'androidIcon': _androidIcon,
      },
    );
  }

  /// Schedules a cron-based recurring notification.
  ///
  /// Uses standard cron syntax: `minute hour dayOfMonth month dayOfWeek`
  ///
  /// ```dart
  /// await NotifyPilot.scheduleCron('daily_medicine',
  ///   cron: '0 9 * * *',
  ///   title: 'Take your medicine',
  /// );
  /// ```
  static Future<void> scheduleCron(
    String tag, {
    required String cron,
    required String title,
    String? body,
    String? channel,
    Map<String, dynamic>? payload,
  }) async {
    _ensureInitialized();

    final resolvedChannel = _channelManager.resolve(channel);
    await _scheduleManager.scheduleCron(
      tag,
      cron: cron,
      title: title,
      body: body,
      extra: {
        'channelId': resolvedChannel.id,
        'channelName': resolvedChannel.name,
        'channelImportance': resolvedChannel.importance.index,
        'payload': payload,
        'androidIcon': _androidIcon,
      },
    );
  }

  /// Schedules a simple repeating notification.
  ///
  /// ```dart
  /// await NotifyPilot.scheduleRepeating('sync',
  ///   interval: RepeatInterval.hourly,
  ///   title: 'Data synced',
  /// );
  /// ```
  static Future<void> scheduleRepeating(
    String tag, {
    required RepeatInterval interval,
    required String title,
    String? body,
    String? channel,
  }) async {
    _ensureInitialized();

    final resolvedChannel = _channelManager.resolve(channel);
    await _scheduleManager.scheduleRepeating(
      tag,
      interval: interval,
      title: title,
      body: body,
      extra: {
        'channelId': resolvedChannel.id,
        'channelName': resolvedChannel.name,
        'channelImportance': resolvedChannel.importance.index,
        'androidIcon': _androidIcon,
      },
    );
  }

  /// Cancels a scheduled notification by tag.
  static Future<void> cancelSchedule(String tag) async {
    _ensureInitialized();
    await _scheduleManager.cancelSchedule(tag);
  }

  /// Cancels all scheduled notifications.
  static Future<void> cancelAllSchedules() async {
    _ensureInitialized();
    await _scheduleManager.cancelAllSchedules();
  }

  /// Returns all active cron schedules.
  static Future<List<Map<String, dynamic>>> getActiveSchedules() async {
    _ensureInitialized();
    return NotifyPilotPlatform.instance.getScheduled();
  }

  // ── Push Notifications (FCM) ──────────────────────────────────────

  /// Registers a handler for incoming push messages.
  ///
  /// The handler can return a notification ID (from [show]) to display
  /// the push as a local notification, or `null` to suppress it.
  static void onPush(Future<int?> Function(PushMessage message) handler) {
    _onPush = handler;
  }

  /// Returns the current FCM token.
  static Future<String?> getFcmToken() async {
    _ensureInitialized();
    return NotifyPilotPlatform.instance.getFcmToken();
  }

  /// Registers a callback for FCM token refreshes.
  static void onTokenRefresh(void Function(String token) callback) {
    _onTokenRefresh = callback;
  }

  /// Subscribes to an FCM topic.
  static Future<void> subscribeTopic(String topic) async {
    _ensureInitialized();
    await NotifyPilotPlatform.instance.subscribeTopic(topic);
  }

  /// Unsubscribes from an FCM topic.
  static Future<void> unsubscribeTopic(String topic) async {
    _ensureInitialized();
    await NotifyPilotPlatform.instance.unsubscribeTopic(topic);
  }

  // ── Notification History ──────────────────────────────────────────

  /// Queries notification history.
  static Future<List<NotifyHistoryEntry>> getHistory({
    int? limit,
    String? group,
  }) async {
    _ensureInitialized();
    return _historyManager.getHistory(limit: limit, group: group);
  }

  /// Returns the count of unread notifications.
  static Future<int> getUnreadCount({String? group}) async {
    _ensureInitialized();
    return _historyManager.getUnreadCount(group: group);
  }

  /// Marks all notifications as read.
  static Future<void> markAllRead() async {
    _ensureInitialized();
    await _historyManager.markAllRead();
  }

  /// Marks a specific notification as read.
  static Future<void> markRead({required int notificationId}) async {
    _ensureInitialized();
    await _historyManager.markRead(notificationId: notificationId);
  }

  /// Clears notification history.
  static Future<void> clearHistory({Duration? olderThan}) async {
    _ensureInitialized();
    await _historyManager.clearHistory(olderThan: olderThan);
  }

  // ── Notification Management ───────────────────────────────────────

  /// Cancels a notification by ID.
  static Future<void> cancel(int id) async {
    _ensureInitialized();
    await NotifyPilotPlatform.instance.cancel(id);
  }

  /// Cancels all notifications in a group.
  static Future<void> cancelGroup(String group) async {
    _ensureInitialized();
    await NotifyPilotPlatform.instance.cancelGroup(group);
    _groupManager.clear();
  }

  /// Cancels all notifications.
  static Future<void> cancelAll() async {
    _ensureInitialized();
    await NotifyPilotPlatform.instance.cancelAll();
    _groupManager.clear();
  }

  /// Returns all currently active (displayed) notifications.
  static Future<List<Map<String, dynamic>>> getActiveNotifications() async {
    _ensureInitialized();
    return NotifyPilotPlatform.instance.getActive();
  }

  /// Sets the app icon badge count (iOS).
  static Future<void> setBadgeCount(int count) async {
    _ensureInitialized();
    await NotifyPilotPlatform.instance.setBadge(count);
  }

  /// Clears the app icon badge (iOS).
  static Future<void> clearBadge() async {
    _ensureInitialized();
    await NotifyPilotPlatform.instance.setBadge(0);
  }

  /// Returns the current notification permission status.
  static Future<NotifyPermission> getPermissionStatus() async {
    _ensureInitialized();
    return _permissionManager.getPermissionStatus();
  }

  /// Requests notification permission from the user.
  static Future<bool> requestPermission() async {
    _ensureInitialized();
    return _permissionManager.requestPermission();
  }

  /// Opens the system notification settings for this app.
  static Future<void> openSettings() async {
    _ensureInitialized();
    await NotifyPilotPlatform.instance.openSettings();
  }

  // ── Channels ──────────────────────────────────────────────────────

  /// Creates a new notification channel (Android).
  static Future<void> createChannel(NotifyChannel channel) async {
    _ensureInitialized();
    await _channelManager.createChannel(channel);
  }

  /// Deletes a notification channel (Android).
  static Future<void> deleteChannel(String channelId) async {
    _ensureInitialized();
    await _channelManager.deleteChannel(channelId);
  }

  /// Returns all registered channels.
  static List<NotifyChannel> getChannels() {
    _ensureInitialized();
    return _channelManager.channels;
  }

  // ── Live Activities ────────────────────────────────────────────────

  /// Starts a Live Activity (iOS) or ongoing notification (Android).
  ///
  /// Returns a unique activity ID.
  ///
  /// ```dart
  /// final activityId = await NotifyPilot.startLiveActivity(
  ///   type: 'ride_tracking',
  ///   attributes: {'driverName': 'Raju Kumar'},
  ///   state: {'eta': '5 min', 'status': 'arriving'},
  /// );
  /// ```
  static Future<String> startLiveActivity({
    required String type,
    required Map<String, dynamic> attributes,
    required Map<String, dynamic> state,
    LiveNotificationConfig? androidNotification,
    Duration? staleAfter,
  }) async {
    _ensureInitialized();
    return NotifyPilotPlatform.instance.startLiveActivity({
      'type': type,
      'attributes': attributes,
      'state': state,
      'androidConfig': androidNotification?.toMap(),
      'staleAfterMs': staleAfter?.inMilliseconds,
    });
  }

  /// Updates the dynamic state of a Live Activity.
  static Future<void> updateLiveActivity(
    String activityId, {
    required Map<String, dynamic> state,
  }) async {
    _ensureInitialized();
    await NotifyPilotPlatform.instance.updateLiveActivity({
      'activityId': activityId,
      'state': state,
    });
  }

  /// Ends a Live Activity with an optional final state.
  static Future<void> endLiveActivity(
    String activityId, {
    Map<String, dynamic>? finalState,
    LiveDismissPolicy dismissPolicy = const LiveDismissPolicy.default_(),
  }) async {
    _ensureInitialized();
    await NotifyPilotPlatform.instance.endLiveActivity({
      'activityId': activityId,
      'finalState': finalState,
      'dismissPolicy': dismissPolicy.toMap(),
    });
    _liveActivityEventControllers.remove(activityId)?.close();
    _liveActivityPushTokenControllers.remove(activityId)?.close();
  }

  /// Ends all Live Activities, optionally filtered by type.
  static Future<void> endAllLiveActivities({String? type}) async {
    _ensureInitialized();
    await NotifyPilotPlatform.instance.endAllLiveActivities(type);
    _liveActivityEventControllers.clear();
    _liveActivityPushTokenControllers.clear();
  }

  /// Gets the push token for server-driven updates (iOS only).
  static Future<String?> getLiveActivityPushToken(String activityId) async {
    _ensureInitialized();
    return NotifyPilotPlatform.instance.getLiveActivityPushToken(activityId);
  }

  /// Listens for push token updates on a Live Activity (iOS only).
  ///
  /// The token can change during the activity's lifetime.
  static Stream<String> onLiveActivityPushTokenUpdate(String activityId) {
    _ensureInitialized();
    return _liveActivityPushTokenControllers
        .putIfAbsent(activityId, () => StreamController<String>.broadcast())
        .stream;
  }

  /// Checks if Live Activities are supported on this device.
  ///
  /// Returns `true` on iOS 16.1+ when the user hasn't disabled Live Activities.
  /// Returns `true` on all Android versions (uses ongoing notifications).
  static Future<bool> isLiveActivitySupported() async {
    _ensureInitialized();
    return NotifyPilotPlatform.instance.isLiveActivitySupported();
  }

  /// Checks if Dynamic Island is available (iPhone 14 Pro+).
  static Future<bool> hasDynamicIsland() async {
    _ensureInitialized();
    return NotifyPilotPlatform.instance.hasDynamicIsland();
  }

  /// Returns all currently active Live Activities.
  static Future<List<LiveActivityInfo>> getActiveLiveActivities() async {
    _ensureInitialized();
    final maps = await NotifyPilotPlatform.instance.getActiveLiveActivities();
    return maps.map((m) => LiveActivityInfo.fromMap(m)).toList();
  }

  /// Gets the status of a specific Live Activity.
  static Future<LiveActivityStatus> getLiveActivityStatus(
      String activityId) async {
    _ensureInitialized();
    final status =
        await NotifyPilotPlatform.instance.getLiveActivityStatus(activityId);
    return LiveActivityStatus.values.firstWhere(
      (s) => s.name == status,
      orElse: () => LiveActivityStatus.ended,
    );
  }

  /// Listens for lifecycle events on a Live Activity.
  static Stream<LiveActivityEvent> onLiveActivityEvent(String activityId) {
    _ensureInitialized();
    return _liveActivityEventControllers
        .putIfAbsent(
            activityId, () => StreamController<LiveActivityEvent>.broadcast())
        .stream;
  }

  // ── v1.0.2: Progress & Media ─────────────────────────────────────

  /// Updates a progress notification.
  ///
  /// ```dart
  /// await NotifyPilot.updateProgress(notificationId, progress: 0.85);
  /// ```
  static Future<void> updateProgress(
    int id, {
    required double progress,
    String? title,
    bool? ongoing,
  }) async {
    _ensureInitialized();
    await NotifyPilotPlatform.instance.updateProgress({
      'id': id,
      'progress': progress,
      'title': title,
      'ongoing': ongoing,
    });
  }

  /// Updates media playback state for a media-style notification.
  static Future<void> setMediaPlaybackState(
    int id, {
    required bool isPlaying,
    Duration? position,
  }) async {
    _ensureInitialized();
    await NotifyPilotPlatform.instance.setMediaPlaybackState({
      'id': id,
      'isPlaying': isPlaying,
      'positionMs': position?.inMilliseconds,
    });
  }

  /// Checks if iOS Critical Alert entitlement is available.
  static Future<bool> hasCriticalAlertEntitlement() async {
    _ensureInitialized();
    return NotifyPilotPlatform.instance.hasCriticalAlertEntitlement();
  }

  // ── Caller Notifications ──────────────────────────────────────────

  /// Shows an incoming call notification/fullscreen UI.
  ///
  /// Android: fullscreen intent with accept/decline buttons.
  /// iOS: CallKit native call UI.
  ///
  /// ```dart
  /// await NotifyPilot.showIncomingCall(
  ///   callId: 'call_123',
  ///   callerName: 'Sarah Johnson',
  ///   callerNumber: '+91 98765 43210',
  ///   callType: CallType.video,
  /// );
  /// ```
  static Future<void> showIncomingCall({
    required String callId,
    required String callerName,
    String? callerNumber,
    NotifyIcon? callerAvatar,
    CallType callType = CallType.audio,
    NotifySound? ringtone,
    Duration? timeout,
    String acceptText = 'Accept',
    String declineText = 'Decline',
    void Function(String callId)? onAccept,
    void Function(String callId)? onDecline,
    void Function(String callId)? onTimeout,
    bool showOverLockScreen = true,
    bool turnScreenOn = true,
    bool keepScreenOn = false,
    Map<String, dynamic>? extra,
  }) async {
    _ensureInitialized();
    _callAcceptHandler = onAccept;
    _callDeclineHandler = onDecline;
    _callTimeoutHandler = onTimeout;
    await NotifyPilotPlatform.instance.showIncomingCall({
      'callId': callId,
      'callerName': callerName,
      'callerNumber': callerNumber,
      'callerAvatar': callerAvatar?.toMap(),
      'callType': callType.name,
      'ringtone': ringtone?.toMap(),
      'timeoutMs': timeout?.inMilliseconds,
      'acceptText': acceptText,
      'declineText': declineText,
      'showOverLockScreen': showOverLockScreen,
      'turnScreenOn': turnScreenOn,
      'keepScreenOn': keepScreenOn,
      'extra': extra,
    });
  }

  /// Shows an outgoing call notification.
  static Future<void> showOutgoingCall({
    required String callId,
    required String callerName,
    String? callerNumber,
    NotifyIcon? callerAvatar,
    CallType callType = CallType.audio,
    void Function(String callId)? onCancel,
  }) async {
    _ensureInitialized();
    _callCancelHandler = onCancel;
    await NotifyPilotPlatform.instance.showOutgoingCall({
      'callId': callId,
      'callerName': callerName,
      'callerNumber': callerNumber,
      'callerAvatar': callerAvatar?.toMap(),
      'callType': callType.name,
    });
  }

  /// Marks a call as connected (switches to ongoing call UI).
  ///
  /// Android: shows compact foreground service notification with
  /// mute / speaker / hangup buttons.
  /// iOS: CallKit green bar at top of screen.
  static Future<void> setCallConnected(String callId) async {
    _ensureInitialized();
    await NotifyPilotPlatform.instance.setCallConnected(callId);
  }

  /// Ends a call and removes the call UI/notification.
  static Future<void> endCall(String callId) async {
    _ensureInitialized();
    await NotifyPilotPlatform.instance.endCall(callId);
  }

  /// Shows a missed call notification.
  static Future<void> showMissedCall({
    required String callId,
    required String callerName,
    String? callerNumber,
    NotifyIcon? callerAvatar,
    DateTime? time,
    List<NotifyAction>? actions,
  }) async {
    _ensureInitialized();
    await NotifyPilotPlatform.instance.showMissedCall({
      'callId': callId,
      'callerName': callerName,
      'callerNumber': callerNumber,
      'callerAvatar': callerAvatar?.toMap(),
      'time': (time ?? DateTime.now()).millisecondsSinceEpoch,
      'actions': actions?.map((a) => a.toMap()).toList(),
    });
  }

  /// Returns all currently active calls.
  static Future<List<CallInfo>> getActiveCalls() async {
    _ensureInitialized();
    final maps = await NotifyPilotPlatform.instance.getActiveCalls();
    return maps.map((m) => CallInfo.fromMap(m)).toList();
  }

  /// Hides an incoming call notification (e.g., caller cancelled).
  static Future<void> hideIncomingCall(String callId) async {
    _ensureInitialized();
    await NotifyPilotPlatform.instance.hideIncomingCall(callId);
  }

  /// Stream of call lifecycle events.
  ///
  /// ```dart
  /// NotifyPilot.onCallEvent.listen((event) {
  ///   switch (event) {
  ///     case CallAccepted(callId: var id):
  ///       joinCall(id);
  ///     case CallDeclined(callId: var id):
  ///       api.declineCall(id);
  ///   }
  /// });
  /// ```
  static Stream<CallEvent> get onCallEvent => _callEventController.stream;

  // Call callback handlers (set via showIncomingCall/showOutgoingCall)
  static void Function(String callId)? _callAcceptHandler;
  static void Function(String callId)? _callDeclineHandler;
  static void Function(String callId)? _callTimeoutHandler;
  static void Function(String callId)? _callCancelHandler;

  // ── Internal ──────────────────────────────────────────────────────

  static void _ensureInitialized() {
    assert(_initialized,
        'NotifyPilot.initialize() must be called before using any other method.');
  }

  static void _handleNativeEvent(String type, Map<String, dynamic> data) {
    switch (type) {
      case 'onTap':
        final event = NotifyTapEvent.fromMap(data);
        _onTap?.call(event);
      case 'onAction':
        final event = NotifyActionEvent.fromMap(data);
        _onAction?.call(event);
      case 'onTokenRefresh':
        final token = data['token'] as String?;
        if (token != null) {
          _onTokenRefresh?.call(token);
          _fcmConfig?.onTokenRefresh?.call(token);
        }
      case 'onPush':
        final message = PushMessage.fromMap(data);
        _handlePush(message);
      case 'onCronFired':
        final tag = data['tag'] as String?;
        if (tag != null) {
          _scheduleManager.reschedule(tag);
        }
      case 'onDismissed':
        if (_historyManager.isEnabled) {
          final id = data['notificationId'] as int?;
          if (id != null) {
            // Update history status to dismissed
          }
        }
      case 'onLiveActivityEvent':
        final activityId = data['activityId'] as String?;
        if (activityId != null) {
          final event = LiveActivityEvent.fromMap(data);
          _liveActivityEventControllers[activityId]?.add(event);
        }
      case 'onLiveActivityPushTokenUpdate':
        final activityId = data['activityId'] as String?;
        final token = data['pushToken'] as String?;
        if (activityId != null && token != null) {
          _liveActivityPushTokenControllers[activityId]?.add(token);
        }
      case 'onCallEvent':
        final callEvent = CallEvent.fromMap(data);
        _callEventController.add(callEvent);
        // Also invoke direct callbacks
        final callId = data['callId'] as String? ?? '';
        final event = data['event'] as String?;
        switch (event) {
          case 'accepted':
            _callAcceptHandler?.call(callId);
          case 'declined':
            _callDeclineHandler?.call(callId);
          case 'timeout':
            _callTimeoutHandler?.call(callId);
          case 'ended':
            _callCancelHandler?.call(callId);
        }
    }
  }

  static Future<void> _handlePush(PushMessage message) async {
    if (_onPush != null) {
      await _onPush!(message);
    } else {
      // Default: auto-display push as local notification
      await show(
        message.title ?? 'Notification',
        body: message.body,
        image: message.imageUrl,
        deepLink: message.data['deepLink'],
        group: message.data['group'] ?? 'push',
      );
    }
  }

  /// Resets the plugin state. For testing only.
  static void reset() {
    _initialized = false;
    _onTap = null;
    _onAction = null;
    _fcmConfig = null;
    _liveActivityConfig = null;
    _onPush = null;
    _onTokenRefresh = null;
    _groupManager.clear();
    for (final c in _liveActivityEventControllers.values) {
      c.close();
    }
    _liveActivityEventControllers.clear();
    for (final c in _liveActivityPushTokenControllers.values) {
      c.close();
    }
    _liveActivityPushTokenControllers.clear();
    _callAcceptHandler = null;
    _callDeclineHandler = null;
    _callTimeoutHandler = null;
    _callCancelHandler = null;
    IdGenerator.reset();
  }
}
