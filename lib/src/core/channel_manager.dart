import '../api/enums.dart';
import '../api/notify_channel.dart';
import '../platform/notify_pilot_platform.dart';

/// Manages notification channels.
///
/// Tracks registered channels, provides defaults, and delegates
/// creation/deletion to the native platform.
class ChannelManager {
  final Map<String, NotifyChannel> _channels = {};
  late final NotifyChannel _defaultChannel;

  /// The default channel used when no channel is specified.
  NotifyChannel get defaultChannel => _defaultChannel;

  /// All registered channels.
  List<NotifyChannel> get channels => _channels.values.toList();

  /// Initializes channels, creating them on the native platform.
  Future<void> initialize({
    NotifyChannel? defaultChannel,
    List<NotifyChannel> channels = const [],
  }) async {
    _defaultChannel = defaultChannel ??
        const NotifyChannel(
          id: 'default',
          name: 'Default',
          importance: NotifyImportance.high,
        );

    _channels[_defaultChannel.id] = _defaultChannel;
    for (final channel in channels) {
      _channels[channel.id] = channel;
    }

    // Create all channels on native platform
    final platform = NotifyPilotPlatform.instance;
    for (final channel in _channels.values) {
      await platform.createChannel(channel.toMap());
    }
  }

  /// Resolves a channel ID to a [NotifyChannel].
  ///
  /// Returns the default channel if [channelId] is null or not found.
  NotifyChannel resolve(String? channelId) {
    if (channelId == null) return _defaultChannel;
    return _channels[channelId] ?? _defaultChannel;
  }

  /// Creates and registers a new channel.
  Future<void> createChannel(NotifyChannel channel) async {
    _channels[channel.id] = channel;
    await NotifyPilotPlatform.instance.createChannel(channel.toMap());
  }

  /// Deletes a channel by ID.
  Future<void> deleteChannel(String channelId) async {
    _channels.remove(channelId);
    await NotifyPilotPlatform.instance.deleteChannel(channelId);
  }
}
