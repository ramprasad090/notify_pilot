import 'package:flutter/services.dart' show MethodCall, MethodChannel;

import 'notify_pilot_platform.dart';

/// Method channel implementation of [NotifyPilotPlatform].
class MethodChannelNotifyPilot extends NotifyPilotPlatform {
  /// The method channel used to interact with the native platform.
  final MethodChannel _channel =
      const MethodChannel('dev.notify_pilot/channel');

  void Function(String type, Map<String, dynamic> data)? _eventHandler;

  /// Creates the method channel implementation.
  MethodChannelNotifyPilot() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    final handler = _eventHandler;
    if (handler == null) return;

    final data = (call.arguments as Map?)?.cast<String, dynamic>() ?? {};
    handler(call.method, data);
  }

  @override
  void setEventHandler(
      void Function(String type, Map<String, dynamic> data) handler) {
    _eventHandler = handler;
  }

  @override
  Future<bool> initialize(Map<String, dynamic> config) async {
    final result = await _channel.invokeMethod<bool>('initialize', config);
    return result ?? false;
  }

  @override
  Future<int> show(Map<String, dynamic> notification) async {
    final result = await _channel.invokeMethod<int>('show', notification);
    return result ?? -1;
  }

  @override
  Future<int> scheduleAt(Map<String, dynamic> notification) async {
    final result = await _channel.invokeMethod<int>('scheduleAt', notification);
    return result ?? -1;
  }

  @override
  Future<int> scheduleAfter(Map<String, dynamic> notification) async {
    final result =
        await _channel.invokeMethod<int>('scheduleAfter', notification);
    return result ?? -1;
  }

  @override
  Future<bool> scheduleCron(Map<String, dynamic> schedule) async {
    final result =
        await _channel.invokeMethod<bool>('scheduleCron', schedule);
    return result ?? false;
  }

  @override
  Future<bool> cancel(int id) async {
    final result = await _channel.invokeMethod<bool>('cancel', {'id': id});
    return result ?? false;
  }

  @override
  Future<bool> cancelGroup(String group) async {
    final result =
        await _channel.invokeMethod<bool>('cancelGroup', {'group': group});
    return result ?? false;
  }

  @override
  Future<bool> cancelAll() async {
    final result = await _channel.invokeMethod<bool>('cancelAll');
    return result ?? false;
  }

  @override
  Future<bool> cancelSchedule(String tag) async {
    final result =
        await _channel.invokeMethod<bool>('cancelSchedule', {'tag': tag});
    return result ?? false;
  }

  @override
  Future<List<Map<String, dynamic>>> getActive() async {
    final result = await _channel.invokeListMethod<Map>('getActive');
    return result
            ?.map((e) => e.cast<String, dynamic>())
            .toList() ??
        [];
  }

  @override
  Future<List<Map<String, dynamic>>> getScheduled() async {
    final result = await _channel.invokeListMethod<Map>('getScheduled');
    return result
            ?.map((e) => e.cast<String, dynamic>())
            .toList() ??
        [];
  }

  @override
  Future<bool> createChannel(Map<String, dynamic> channel) async {
    final result =
        await _channel.invokeMethod<bool>('createChannel', channel);
    return result ?? false;
  }

  @override
  Future<bool> deleteChannel(String channelId) async {
    final result = await _channel
        .invokeMethod<bool>('deleteChannel', {'channelId': channelId});
    return result ?? false;
  }

  @override
  Future<bool> requestPermission() async {
    final result = await _channel.invokeMethod<bool>('requestPermission');
    return result ?? false;
  }

  @override
  Future<String> getPermission() async {
    final result = await _channel.invokeMethod<String>('getPermission');
    return result ?? 'notDetermined';
  }

  @override
  Future<bool> setBadge(int count) async {
    final result =
        await _channel.invokeMethod<bool>('setBadge', {'count': count});
    return result ?? false;
  }

  @override
  Future<String?> getFcmToken() async {
    return await _channel.invokeMethod<String?>('getFcmToken');
  }

  @override
  Future<bool> subscribeTopic(String topic) async {
    final result = await _channel
        .invokeMethod<bool>('subscribeTopic', {'topic': topic});
    return result ?? false;
  }

  @override
  Future<bool> unsubscribeTopic(String topic) async {
    final result = await _channel
        .invokeMethod<bool>('unsubscribeTopic', {'topic': topic});
    return result ?? false;
  }

  @override
  Future<List<Map<String, dynamic>>> getHistory(
      Map<String, dynamic> query) async {
    final result =
        await _channel.invokeListMethod<Map>('getHistory', query);
    return result
            ?.map((e) => e.cast<String, dynamic>())
            .toList() ??
        [];
  }

  @override
  Future<bool> clearHistory(Map<String, dynamic>? options) async {
    final result =
        await _channel.invokeMethod<bool>('clearHistory', options);
    return result ?? false;
  }

  @override
  Future<int> getUnreadCount(String? group) async {
    final result = await _channel
        .invokeMethod<int>('getUnreadCount', {'group': group});
    return result ?? 0;
  }

  @override
  Future<bool> markRead(Map<String, dynamic> options) async {
    final result =
        await _channel.invokeMethod<bool>('markRead', options);
    return result ?? false;
  }

  @override
  Future<bool> openSettings() async {
    final result = await _channel.invokeMethod<bool>('openSettings');
    return result ?? false;
  }
}
