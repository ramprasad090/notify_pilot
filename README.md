# notify_pilot

Unified notification API for Flutter. Local + push + scheduled notifications in 3 lines.

## Features

- **3-line setup** — replaces 30+ lines of boilerplate
- **Local notifications** — show, style, group, action buttons, inline reply
- **Push notifications (FCM)** — optional, auto-displays in all app states
- **Scheduled notifications** — at time, after delay, cron expressions, repeating
- **Built-in cron parser** — pure Dart, zero dependencies
- **Auto timezone** — pass `DateTime`, never import timezone packages
- **Auto-grouping** — InboxStyle on Android, threads on iOS
- **Notification history** — query, unread count, mark read
- **Analytics callbacks** — delivered, opened, dismissed, action taken
- **Pre-built widgets** — NotifyBanner, NotifyInbox, NotifyBadge
- **bg_orchestrator integration** — trigger background tasks from notification actions

## Quick Start

```dart
import 'package:notify_pilot/notify_pilot.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotifyPilot.initialize();
  runApp(MyApp());
}

// Anywhere in your app:
await NotifyPilot.show('Order shipped!', body: 'Order #1234 is on the way');
```

## Installation

```yaml
dependencies:
  notify_pilot: ^1.0.0
```

### Android

Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
```

### iOS

Add to `ios/Runner/Info.plist` (for background notifications):

```xml
<key>UIBackgroundModes</key>
<array>
  <string>remote-notification</string>
</array>
```

## Initialization

```dart
await NotifyPilot.initialize(
  defaultChannel: NotifyChannel(
    id: 'general', name: 'General',
    importance: NotifyImportance.high,
  ),
  channels: [
    NotifyChannel(id: 'messages', name: 'Messages', importance: NotifyImportance.high),
    NotifyChannel(id: 'updates', name: 'Updates', importance: NotifyImportance.low),
  ],
  onTap: (event) {
    if (event.deepLink != null) navigator.pushNamed(event.deepLink!);
  },
  onAction: (event) {
    if (event.actionId == 'reply') {
      chatService.sendReply(event.payload?['chatId'], event.inputText!);
    }
  },
  analytics: NotifyAnalytics(
    onDelivered: (n) => tracker.track('notif_delivered'),
    onOpened: (n) => tracker.track('notif_opened'),
  ),
  history: HistoryConfig(enabled: true, maxEntries: 100),
);
```

## Showing Notifications

```dart
// Basic
await NotifyPilot.show('Hello!');

// With body and deep link
await NotifyPilot.show('New message',
  body: 'Hey, are you free tonight?',
  deepLink: '/chat/sarah_123',
  payload: {'chatId': 'sarah_123'},
);

// With actions
await NotifyPilot.show('New message',
  body: 'Hey!',
  actions: [
    NotifyAction('reply', label: 'Reply', input: true),
    NotifyAction('mark_read', label: 'Mark Read'),
  ],
);

// With grouping
await NotifyPilot.show('Alice: Hey!', group: 'messages');
await NotifyPilot.show('Bob: What\'s up?', group: 'messages');
```

## Scheduling

```dart
// At specific time (auto timezone)
await NotifyPilot.scheduleAt(
  DateTime(2026, 4, 1, 9, 0),
  title: 'Meeting in 15 minutes',
);

// After delay
await NotifyPilot.scheduleAfter(
  Duration(hours: 2),
  title: 'Check on your order',
);

// Cron-based recurring
await NotifyPilot.scheduleCron('daily_medicine',
  cron: '0 9 * * *',          // Every day at 9:00 AM
  title: 'Take your medicine',
);

await NotifyPilot.scheduleCron('water_reminder',
  cron: '0 */2 8-22 * *',     // Every 2 hours between 8am-10pm
  title: 'Drink water',
);
```

## Push Notifications (FCM)

FCM is optional — works without Firebase for local-only apps.

```dart
await NotifyPilot.initialize(
  fcm: FcmConfig(
    onToken: (token) => myApi.registerDevice(token),
    topics: ['news', 'promotions'],
  ),
);

// Custom push handling
NotifyPilot.onPush((message) {
  if (message.data['type'] == 'silent') return null;
  return NotifyPilot.show(message.title ?? 'Notification', body: message.body);
});
```

## Notification History

```dart
final recent = await NotifyPilot.getHistory(limit: 20);
final unread = await NotifyPilot.getUnreadCount();
await NotifyPilot.markAllRead();
await NotifyPilot.clearHistory(olderThan: Duration(days: 30));
```

## Widgets

```dart
// In-app notification banner
NotifyBanner(
  onNotification: (notification) => true,
  child: MyApp(),
)

// Notification inbox
NotifyInbox(
  onTap: (entry) => navigator.pushNamed(entry.deepLink ?? '/'),
  groupBy: NotifyGroupBy.date,
)

// Unread badge
NotifyBadge(
  group: 'messages',
  child: Icon(Icons.notifications),
)
```

## Platforms

| Feature | Android | iOS |
|---------|---------|-----|
| Local notifications | API 21+ | iOS 13+ |
| Scheduled (exact) | AlarmManager | UNCalendarNotificationTrigger |
| Cron scheduling | Self-rescheduling | Self-rescheduling |
| Action buttons | NotificationCompat | UNNotificationAction |
| Inline reply | RemoteInput | UNTextInputNotificationAction |
| Grouping | InboxStyle | threadIdentifier |
| Images | BigPictureStyle | UNNotificationAttachment |
| History | SQLite | UserDefaults |
| FCM | Optional (runtime) | Optional (runtime) |
| Badge | N/A | UIApplication.applicationIconBadgeNumber |

## License

MIT
