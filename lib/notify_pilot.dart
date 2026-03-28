/// Unified notification API for Flutter.
///
/// Local + push + scheduled notifications in 3 lines.
/// Cron scheduling, auto-grouping, notification history,
/// action buttons, analytics, and bg_orchestrator integration.
library;

// API
export 'src/api/enums.dart';
export 'src/api/fcm_config.dart';
export 'src/api/history_config.dart';
export 'src/api/notify_action.dart';
export 'src/api/notify_action_event.dart';
export 'src/api/notify_analytics.dart';
export 'src/api/notify_channel.dart';
export 'src/api/notify_history_entry.dart';
export 'src/api/notify_pilot_api.dart';
export 'src/api/notify_style.dart';
export 'src/api/notify_tap_event.dart';
export 'src/api/push_message.dart';

// Exceptions
export 'src/exceptions.dart';

// Platform (for testing)
export 'src/platform/notify_pilot_platform.dart';

// Widgets
export 'src/widgets/notify_badge.dart';
export 'src/widgets/notify_banner.dart';
export 'src/widgets/notify_inbox.dart';
