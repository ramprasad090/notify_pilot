import 'notify_action.dart';
import 'notify_icon.dart';
import 'notify_image.dart';
import 'notify_message.dart';
import 'notify_person.dart';

/// Display style for a notification.
///
/// Maps to Android notification styles (BigTextStyle, BigPictureStyle, etc.)
/// with iOS equivalents.
sealed class NotifyDisplayStyle {
  const NotifyDisplayStyle._();

  /// Big text style — expandable long text.
  ///
  /// Android: `NotificationCompat.BigTextStyle`
  /// iOS: shows full text in expanded notification
  const factory NotifyDisplayStyle.bigText({
    required String bigText,
    String? summaryText,
  }) = BigTextDisplayStyle;

  /// Big picture style — large image notification.
  ///
  /// Android: `NotificationCompat.BigPictureStyle`
  /// iOS: `UNNotificationAttachment` with image
  const factory NotifyDisplayStyle.bigPicture({
    required NotifyImage picture,
    NotifyIcon? largeIcon,
    String? summaryText,
    bool hideLargeIconOnExpand,
  }) = BigPictureDisplayStyle;

  /// Inbox style — multiple summary lines.
  ///
  /// Android: `NotificationCompat.InboxStyle` (up to 6 lines)
  /// iOS: shows as grouped notification summary
  const factory NotifyDisplayStyle.inbox({
    required List<String> lines,
    String? summaryText,
  }) = InboxDisplayStyle;

  /// Messaging style — chat conversation.
  ///
  /// Android: `NotificationCompat.MessagingStyle` (supports inline reply)
  /// iOS: conversation notification (iOS 15+)
  const factory NotifyDisplayStyle.messaging({
    required NotifyPerson user,
    required List<NotifyMessage> messages,
    String? conversationTitle,
    bool isGroupConversation,
  }) = MessagingDisplayStyle;

  /// Media style — music/podcast player controls.
  ///
  /// Android: `MediaStyle` with `MediaSession` token
  /// iOS: `MPNowPlayingInfoCenter`
  const factory NotifyDisplayStyle.media({
    required String title,
    String? artist,
    String? album,
    NotifyImage? albumArt,
    required bool isPlaying,
    Duration? duration,
    Duration? position,
    List<NotifyAction>? actions,
    List<int>? compactActionIndices,
  }) = MediaDisplayStyle;

  /// Progress style — download/upload/processing progress bar.
  ///
  /// Android: `setProgress()` with `NotificationCompat.Builder`
  /// iOS: shows progress text (no native progress bar)
  const factory NotifyDisplayStyle.progress({
    required double progress,
    bool indeterminate,
  }) = ProgressDisplayStyle;

  /// Serializes to a map for platform channel communication.
  Map<String, dynamic> toMap();
}

/// Big text expandable notification style.
final class BigTextDisplayStyle extends NotifyDisplayStyle {
  final String bigText;
  final String? summaryText;

  const BigTextDisplayStyle({
    required this.bigText,
    this.summaryText,
  }) : super._();

  @override
  Map<String, dynamic> toMap() => {
        'type': 'bigText',
        'bigText': bigText,
        'summaryText': summaryText,
      };
}

/// Big picture notification style with large image.
final class BigPictureDisplayStyle extends NotifyDisplayStyle {
  final NotifyImage picture;
  final NotifyIcon? largeIcon;
  final String? summaryText;
  final bool hideLargeIconOnExpand;

  const BigPictureDisplayStyle({
    required this.picture,
    this.largeIcon,
    this.summaryText,
    this.hideLargeIconOnExpand = false,
  }) : super._();

  @override
  Map<String, dynamic> toMap() => {
        'type': 'bigPicture',
        'picture': picture.toMap(),
        'largeIcon': largeIcon?.toMap(),
        'summaryText': summaryText,
        'hideLargeIconOnExpand': hideLargeIconOnExpand,
      };
}

/// Inbox style with multiple summary lines.
final class InboxDisplayStyle extends NotifyDisplayStyle {
  final List<String> lines;
  final String? summaryText;

  const InboxDisplayStyle({
    required this.lines,
    this.summaryText,
  }) : super._();

  @override
  Map<String, dynamic> toMap() => {
        'type': 'inbox',
        'lines': lines,
        'summaryText': summaryText,
      };
}

/// Messaging style for chat conversations.
final class MessagingDisplayStyle extends NotifyDisplayStyle {
  final NotifyPerson user;
  final List<NotifyMessage> messages;
  final String? conversationTitle;
  final bool isGroupConversation;

  const MessagingDisplayStyle({
    required this.user,
    required this.messages,
    this.conversationTitle,
    this.isGroupConversation = false,
  }) : super._();

  @override
  Map<String, dynamic> toMap() => {
        'type': 'messaging',
        'user': user.toMap(),
        'messages': messages.map((m) => m.toMap()).toList(),
        'conversationTitle': conversationTitle,
        'isGroupConversation': isGroupConversation,
      };
}

/// Media style for music/podcast player notifications.
final class MediaDisplayStyle extends NotifyDisplayStyle {
  final String title;
  final String? artist;
  final String? album;
  final NotifyImage? albumArt;
  final bool isPlaying;
  final Duration? duration;
  final Duration? position;
  final List<NotifyAction>? actions;
  final List<int>? compactActionIndices;

  const MediaDisplayStyle({
    required this.title,
    this.artist,
    this.album,
    this.albumArt,
    required this.isPlaying,
    this.duration,
    this.position,
    this.actions,
    this.compactActionIndices,
  }) : super._();

  @override
  Map<String, dynamic> toMap() => {
        'type': 'media',
        'title': title,
        'artist': artist,
        'album': album,
        'albumArt': albumArt?.toMap(),
        'isPlaying': isPlaying,
        'durationMs': duration?.inMilliseconds,
        'positionMs': position?.inMilliseconds,
        'actions': actions?.map((a) => a.toMap()).toList(),
        'compactActionIndices': compactActionIndices,
      };
}

/// Progress bar notification style.
final class ProgressDisplayStyle extends NotifyDisplayStyle {
  final double progress;
  final bool indeterminate;

  const ProgressDisplayStyle({
    required this.progress,
    this.indeterminate = false,
  }) : super._();

  @override
  Map<String, dynamic> toMap() => {
        'type': 'progress',
        'progress': progress,
        'indeterminate': indeterminate,
      };
}
