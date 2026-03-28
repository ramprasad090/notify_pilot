import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'notify_pilot_method_channel.dart';

/// Platform interface for notify_pilot plugin.
///
/// Implementations must extend this class rather than implement it,
/// as new methods may be added in the future.
abstract class NotifyPilotPlatform extends PlatformInterface {
  /// Constructs a NotifyPilotPlatform.
  NotifyPilotPlatform() : super(token: _token);

  static final Object _token = Object();

  static NotifyPilotPlatform _instance = MethodChannelNotifyPilot();

  /// The default instance of [NotifyPilotPlatform].
  static NotifyPilotPlatform get instance => _instance;

  /// Sets the instance for testing.
  static set instance(NotifyPilotPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Initialize native notification infrastructure.
  Future<bool> initialize(Map<String, dynamic> config) {
    throw UnimplementedError('initialize() has not been implemented.');
  }

  /// Display a notification. Returns the notification ID.
  Future<int> show(Map<String, dynamic> notification) {
    throw UnimplementedError('show() has not been implemented.');
  }

  /// Schedule a notification at an exact time. Returns the notification ID.
  Future<int> scheduleAt(Map<String, dynamic> notification) {
    throw UnimplementedError('scheduleAt() has not been implemented.');
  }

  /// Schedule a notification after a delay. Returns the notification ID.
  Future<int> scheduleAfter(Map<String, dynamic> notification) {
    throw UnimplementedError('scheduleAfter() has not been implemented.');
  }

  /// Schedule the next occurrence of a cron-based notification.
  Future<bool> scheduleCron(Map<String, dynamic> schedule) {
    throw UnimplementedError('scheduleCron() has not been implemented.');
  }

  /// Cancel a notification by ID.
  Future<bool> cancel(int id) {
    throw UnimplementedError('cancel() has not been implemented.');
  }

  /// Cancel all notifications in a group.
  Future<bool> cancelGroup(String group) {
    throw UnimplementedError('cancelGroup() has not been implemented.');
  }

  /// Cancel all notifications.
  Future<bool> cancelAll() {
    throw UnimplementedError('cancelAll() has not been implemented.');
  }

  /// Cancel a scheduled notification by tag.
  Future<bool> cancelSchedule(String tag) {
    throw UnimplementedError('cancelSchedule() has not been implemented.');
  }

  /// Get all active (displayed) notifications.
  Future<List<Map<String, dynamic>>> getActive() {
    throw UnimplementedError('getActive() has not been implemented.');
  }

  /// Get all pending scheduled notifications.
  Future<List<Map<String, dynamic>>> getScheduled() {
    throw UnimplementedError('getScheduled() has not been implemented.');
  }

  /// Create a notification channel (Android).
  Future<bool> createChannel(Map<String, dynamic> channel) {
    throw UnimplementedError('createChannel() has not been implemented.');
  }

  /// Delete a notification channel (Android).
  Future<bool> deleteChannel(String channelId) {
    throw UnimplementedError('deleteChannel() has not been implemented.');
  }

  /// Request notification permission.
  Future<bool> requestPermission() {
    throw UnimplementedError('requestPermission() has not been implemented.');
  }

  /// Get current notification permission status.
  Future<String> getPermission() {
    throw UnimplementedError('getPermission() has not been implemented.');
  }

  /// Set the app icon badge count (iOS).
  Future<bool> setBadge(int count) {
    throw UnimplementedError('setBadge() has not been implemented.');
  }

  /// Get the FCM token.
  Future<String?> getFcmToken() {
    throw UnimplementedError('getFcmToken() has not been implemented.');
  }

  /// Subscribe to an FCM topic.
  Future<bool> subscribeTopic(String topic) {
    throw UnimplementedError('subscribeTopic() has not been implemented.');
  }

  /// Unsubscribe from an FCM topic.
  Future<bool> unsubscribeTopic(String topic) {
    throw UnimplementedError('unsubscribeTopic() has not been implemented.');
  }

  /// Query notification history.
  Future<List<Map<String, dynamic>>> getHistory(Map<String, dynamic> query) {
    throw UnimplementedError('getHistory() has not been implemented.');
  }

  /// Clear notification history.
  Future<bool> clearHistory(Map<String, dynamic>? options) {
    throw UnimplementedError('clearHistory() has not been implemented.');
  }

  /// Get unread notification count.
  Future<int> getUnreadCount(String? group) {
    throw UnimplementedError('getUnreadCount() has not been implemented.');
  }

  /// Mark notifications as read.
  Future<bool> markRead(Map<String, dynamic> options) {
    throw UnimplementedError('markRead() has not been implemented.');
  }

  /// Open system notification settings.
  Future<bool> openSettings() {
    throw UnimplementedError('openSettings() has not been implemented.');
  }

  /// Set the callback for native events (tap, action, token, push).
  void setEventHandler(void Function(String type, Map<String, dynamic> data) handler) {
    throw UnimplementedError('setEventHandler() has not been implemented.');
  }

  // ── Live Activities ──────────────────────────────────────────────

  /// Start a Live Activity (iOS) or ongoing notification (Android).
  Future<String> startLiveActivity(Map<String, dynamic> data) {
    throw UnimplementedError('startLiveActivity() has not been implemented.');
  }

  /// Update a Live Activity's dynamic state.
  Future<bool> updateLiveActivity(Map<String, dynamic> data) {
    throw UnimplementedError('updateLiveActivity() has not been implemented.');
  }

  /// End a Live Activity.
  Future<bool> endLiveActivity(Map<String, dynamic> data) {
    throw UnimplementedError('endLiveActivity() has not been implemented.');
  }

  /// End all Live Activities of a given type.
  Future<bool> endAllLiveActivities(String? type) {
    throw UnimplementedError('endAllLiveActivities() has not been implemented.');
  }

  /// Get the push token for a Live Activity (iOS only).
  Future<String?> getLiveActivityPushToken(String activityId) {
    throw UnimplementedError('getLiveActivityPushToken() has not been implemented.');
  }

  /// Check if Live Activities are supported on this device.
  Future<bool> isLiveActivitySupported() {
    throw UnimplementedError('isLiveActivitySupported() has not been implemented.');
  }

  /// Check if Dynamic Island is available on this device.
  Future<bool> hasDynamicIsland() {
    throw UnimplementedError('hasDynamicIsland() has not been implemented.');
  }

  /// Get all currently active Live Activities.
  Future<List<Map<String, dynamic>>> getActiveLiveActivities() {
    throw UnimplementedError('getActiveLiveActivities() has not been implemented.');
  }

  /// Get the status of a specific Live Activity.
  Future<String> getLiveActivityStatus(String activityId) {
    throw UnimplementedError('getLiveActivityStatus() has not been implemented.');
  }

  // ── v1.0.2: Progress & Media ────────────────────────────────────

  /// Update a progress notification.
  Future<bool> updateProgress(Map<String, dynamic> data) {
    throw UnimplementedError('updateProgress() has not been implemented.');
  }

  /// Update media playback state.
  Future<bool> setMediaPlaybackState(Map<String, dynamic> data) {
    throw UnimplementedError('setMediaPlaybackState() has not been implemented.');
  }

  /// Check if iOS Critical Alert entitlement is available.
  Future<bool> hasCriticalAlertEntitlement() {
    throw UnimplementedError('hasCriticalAlertEntitlement() has not been implemented.');
  }

  // ── Caller Notifications ────────────────────────────────────────

  /// Show an incoming call notification/screen.
  Future<bool> showIncomingCall(Map<String, dynamic> data) {
    throw UnimplementedError('showIncomingCall() has not been implemented.');
  }

  /// Show an outgoing call notification.
  Future<bool> showOutgoingCall(Map<String, dynamic> data) {
    throw UnimplementedError('showOutgoingCall() has not been implemented.');
  }

  /// Mark a call as connected (switch to ongoing call UI).
  Future<bool> setCallConnected(String callId) {
    throw UnimplementedError('setCallConnected() has not been implemented.');
  }

  /// End a call.
  Future<bool> endCall(String callId) {
    throw UnimplementedError('endCall() has not been implemented.');
  }

  /// Show a missed call notification.
  Future<bool> showMissedCall(Map<String, dynamic> data) {
    throw UnimplementedError('showMissedCall() has not been implemented.');
  }

  /// Get all active calls.
  Future<List<Map<String, dynamic>>> getActiveCalls() {
    throw UnimplementedError('getActiveCalls() has not been implemented.');
  }

  /// Hide an incoming call notification (e.g., caller cancelled).
  Future<bool> hideIncomingCall(String callId) {
    throw UnimplementedError('hideIncomingCall() has not been implemented.');
  }
}
