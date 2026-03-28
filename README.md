# notify_pilot

Unified notification API for Flutter. Local + push + scheduled + live activities + caller notifications in one package.

[![pub package](https://img.shields.io/pub/v/notify_pilot.svg)](https://pub.dev/packages/notify_pilot)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

## Features

**Core (v1.0.0)**

- 3-line setup -- replaces 30+ lines of boilerplate
- Local notifications with title, body, image, deep link, grouping
- Push notifications via FCM (token, topics, custom handler)
- Scheduled notifications (at time, after delay, cron expressions, repeating)
- Built-in cron parser -- pure Dart, zero dependencies
- Notification action buttons with inline reply
- Auto timezone -- pass `DateTime`, never import timezone packages
- Auto-grouping with summary notifications
- Notification history with read/unread tracking
- Analytics callbacks (delivered, opened, dismissed, action)
- Pre-built widgets (NotifyBanner, NotifyInbox, NotifyBadge)
- bg_orchestrator integration for background task triggers

**Live Activities (v1.0.1)**

- iOS Live Activities and Dynamic Island support
- Android ongoing notifications (Live Activity equivalent)
- Live Activity lifecycle management (start, update, end)
- Push token support for server-driven updates
- iOS Widget Extension templates (ride tracking, delivery, sports, timer)

**Rich Notifications (v1.0.2)**

- Alarm channel presets that bypass Do Not Disturb
- Custom notification sounds, icons, and images
- 6 notification display styles (BigText, BigPicture, Inbox, Messaging, Media, Progress)
- iOS Critical Alert support with graceful degradation
- Caller notifications (incoming, outgoing, connected, missed, ongoing)
- Progress notification updates
- Media playback state updates

## Installation

```yaml
dependencies:
  notify_pilot: ^1.0.2
```

## Quick Start

```dart
import 'package:notify_pilot/notify_pilot.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await NotifyPilot.initialize(
    defaultChannel: const NotifyChannel(
      id: 'general',
      name: 'General',
      importance: NotifyImportance.high,
    ),
    channels: [
      const NotifyChannel(id: 'messages', name: 'Messages', importance: NotifyImportance.high),
      const NotifyChannel(id: 'updates', name: 'Updates', importance: NotifyImportance.low),
      const NotifyChannel.alarm(id: 'alarms', name: 'Alarms'),
      const NotifyChannel.call(id: 'calls', name: 'Calls'),
      const NotifyChannel.timer(id: 'timers', name: 'Timers'),
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
    history: const HistoryConfig(enabled: true, maxEntries: 100),
  );

  runApp(MyApp());
}

// Anywhere in your app:
await NotifyPilot.show('Order shipped!', body: 'Order #1234 is on the way');
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

## Notification Styles

Six built-in display styles for rich notification content.

```dart
// Big Text -- expandable long text
await NotifyPilot.show('Article published',
  body: 'Your article has been published...',
  displayStyle: const NotifyDisplayStyle.bigText(
    bigText: 'Your article "Building Flutter Packages" has been published '
        'and is now live on the blog. It has already received 42 views '
        'and 5 comments. Keep up the great work!',
    summaryText: 'Blog Update',
  ),
);

// Big Picture -- expandable image
await NotifyPilot.show('New photo from Sarah',
  body: 'Check out this sunset!',
  displayStyle: NotifyDisplayStyle.bigPicture(
    picture: const NotifyImage.url('https://example.com/sunset.jpg'),
    summaryText: 'Photo from Sarah',
    hideLargeIconOnExpand: true,
  ),
);

// Inbox -- multiple lines summary
await NotifyPilot.show('5 new emails',
  body: 'From Alex, Sarah, Bob...',
  displayStyle: const NotifyDisplayStyle.inbox(
    lines: [
      'Alex: Meeting rescheduled to 3pm',
      'Sarah: Photo album shared',
      'Bob: PR review needed',
      'Dev Team: Build failed #1234',
      'HR: Leave approved',
    ],
    summaryText: '+12 more',
  ),
);

// Messaging -- chat-style conversation
await NotifyPilot.show('Team Chat',
  displayStyle: NotifyDisplayStyle.messaging(
    user: const NotifyPerson(name: 'You'),
    conversationTitle: 'Project Alpha',
    messages: [
      NotifyMessage(
        text: 'Anyone free for lunch?',
        sender: const NotifyPerson(name: 'Alex'),
        time: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
      NotifyMessage(
        text: 'Sure! 12:30?',
        sender: const NotifyPerson(name: 'Sarah'),
        time: DateTime.now().subtract(const Duration(minutes: 3)),
      ),
    ],
    isGroupConversation: true,
  ),
);

// Media -- media playback controls
await NotifyPilot.show('Now Playing',
  body: 'Artist - Song Title',
  displayStyle: const NotifyDisplayStyle.media(),
);

// Progress -- download/upload progress bar
final id = await NotifyPilot.show('Downloading...',
  body: 'app_v2.0.apk',
  displayStyle: const NotifyDisplayStyle.progress(progress: 0.0),
  ongoing: true,
);

// Update progress later
await NotifyPilot.updateProgress(id, progress: 0.75);
await NotifyPilot.updateProgress(id,
  progress: 1.0,
  title: 'Download complete',
  ongoing: false,
);
```

## Alarm Channels

Alarm channels bypass Do Not Disturb mode. Use the built-in presets for common use cases.

```dart
await NotifyPilot.initialize(
  channels: [
    const NotifyChannel.alarm(id: 'alarms', name: 'Alarms'),
    const NotifyChannel.call(id: 'calls', name: 'Calls'),
    const NotifyChannel.timer(id: 'timers', name: 'Timers'),
    const NotifyChannel.message(id: 'urgent', name: 'Urgent Messages'),
    const NotifyChannel.silent(id: 'silent', name: 'Silent'),
  ],
);

// Alarm notification -- bypasses DND, fullscreen intent
await NotifyPilot.show('Wake up!',
  body: 'Morning alarm -- 7:00 AM',
  channel: 'alarms',
  ongoing: true,
  fullscreen: true,
  turnScreenOn: true,
  actions: [
    const NotifyAction('snooze', label: 'Snooze 5 min'),
    const NotifyAction('dismiss', label: 'Dismiss', destructive: true),
  ],
);

// Timer notification
await NotifyPilot.show('Timer done!',
  body: 'Your 15-minute timer is complete',
  channel: 'timers',
  sound: const NotifySound.default_(),
);
```

## Custom Sounds

```dart
await NotifyPilot.show('Alert',
  sound: const NotifySound.custom('my_sound'),   // platform-specific lookup
);
await NotifyPilot.show('Alarm',
  sound: const NotifySound.alarm(),               // system alarm sound
);
await NotifyPilot.show('Critical',
  sound: const NotifySound.critical(),            // iOS critical alert sound
);
await NotifyPilot.show('Silent',
  sound: const NotifySound.none(),                // no sound
);
```

**Platform-specific sound file locations:**

| Platform | Location | Format |
|----------|----------|--------|
| Android | `android/app/src/main/res/raw/my_sound.mp3` | `.mp3`, `.ogg`, `.wav` |
| iOS | `Runner/Sounds/my_sound.caf` (add to Xcode project) | `.caf`, `.aiff`, `.wav` |

## Custom Icons and Images

```dart
// Large icon (shown alongside notification)
await NotifyPilot.show('Message from Sarah',
  largeIcon: const NotifyIcon.url('https://example.com/avatar.jpg'),
);

// Icon sources
const NotifyIcon.resource('ic_custom');       // Android drawable / iOS asset
const NotifyIcon.url('https://example.com/icon.png');
const NotifyIcon.asset('assets/icon.png');    // Flutter asset
const NotifyIcon.file('/path/to/icon.png');

// Image sources for BigPicture style
const NotifyImage.url('https://example.com/photo.jpg');
const NotifyImage.asset('assets/photo.jpg');
const NotifyImage.file('/path/to/photo.jpg');
```

## Caller Notifications

Full-featured caller notification system with native platform integration. Android uses fullscreen intents; iOS uses CallKit.

```dart
// Incoming call
await NotifyPilot.showIncomingCall(
  callId: 'call_123',
  callerName: 'Priya Sharma',
  callerNumber: '+91 98765 43210',
  callType: CallType.video,
  ringtone: const NotifySound.default_(),
  timeout: const Duration(seconds: 30),
  onAccept: (id) => joinCall(id),
  onDecline: (id) => api.declineCall(id),
  onTimeout: (id) => api.missedCall(id),
);

// Outgoing call
await NotifyPilot.showOutgoingCall(
  callId: 'call_456',
  callerName: 'Amit Patel',
  callerNumber: '+91 99887 76655',
  callType: CallType.audio,
  onCancel: (id) => api.cancelCall(id),
);

// Mark call as connected (switches to ongoing call UI)
await NotifyPilot.setCallConnected('call_123');

// End a call
await NotifyPilot.endCall('call_123');

// Show missed call notification
await NotifyPilot.showMissedCall(
  callId: 'call_789',
  callerName: 'Rahul Verma',
  callerNumber: '+91 91234 56789',
  actions: [
    const NotifyAction('call_back', label: 'Call Back'),
    const NotifyAction('message', label: 'Message'),
  ],
);

// Hide incoming call (e.g., caller cancelled before answer)
await NotifyPilot.hideIncomingCall('call_123');

// List active calls
final calls = await NotifyPilot.getActiveCalls();

// Listen for call lifecycle events
NotifyPilot.onCallEvent.listen((event) {
  switch (event) {
    case CallAccepted(callId: var id):
      joinCallRoom(id);
    case CallDeclined(callId: var id):
      api.declineCall(id);
    case CallEnded(callId: var id):
      cleanupCall(id);
    case CallTimeout(callId: var id):
      showMissedCallNotification(id);
    case CallMuted(callId: var id, muted: var muted):
      toggleMicrophone(id, muted);
    case CallSpeaker(callId: var id, speaker: var on):
      toggleSpeaker(id, on);
    case CallHeld(callId: var id, held: var held):
      setCallHold(id, held);
  }
});
```

## Live Activities

iOS Live Activities with Dynamic Island support. Falls back to ongoing notifications on Android.

```dart
// Start a ride tracking activity
final activityId = await NotifyPilot.startLiveActivity(
  type: 'ride_tracking',
  attributes: {
    'driverName': 'Raju Kumar',
    'vehicleNumber': 'KA-01-AB-1234',
    'vehicleType': 'sedan',
  },
  state: {
    'eta': '5 min',
    'distance': '1.2 km',
    'status': 'arriving',
    'progress': 0.3,
  },
  androidNotification: const LiveNotificationConfig(
    channelId: 'ride_tracking',
    channelName: 'Ride Tracking',
    smallIcon: '@drawable/ic_notification',
    ongoing: true,
  ),
  staleAfter: const Duration(minutes: 30),
);

// Update the activity state
await NotifyPilot.updateLiveActivity(activityId, state: {
  'eta': '2 min',
  'distance': '0.3 km',
  'status': 'arriving',
  'progress': 0.7,
});

// End the activity
await NotifyPilot.endLiveActivity(
  activityId,
  finalState: {'status': 'completed', 'eta': 'Arrived', 'progress': 1.0},
  dismissPolicy: const LiveDismissPolicy.after(Duration(minutes: 2)),
);

// Check support
final supported = await NotifyPilot.isLiveActivitySupported();
final hasDynamic = await NotifyPilot.hasDynamicIsland();

// Get push token for server-driven updates (iOS only)
final token = await NotifyPilot.getLiveActivityPushToken(activityId);

// Listen for lifecycle events
NotifyPilot.onLiveActivityEvent(activityId).listen((event) {
  // handle started, updated, ended, stale, dismissed
});
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

FCM is optional -- works without Firebase for local-only apps.

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

## iOS Live Activities Setup

To use Live Activities on iOS, you need to add a Widget Extension to your Xcode project.

**Step 1: Add Widget Extension**

1. Open `ios/Runner.xcworkspace` in Xcode.
2. Go to File > New > Target.
3. Select "Widget Extension" and click Next.
4. Name it (e.g., `NotifyPilotWidgets`). Uncheck "Include Configuration App Intent".
5. Click Finish. Activate the scheme if prompted.

**Step 2: Enable Live Activities**

Add to your main app's `Info.plist`:

```xml
<key>NSSupportsLiveActivities</key>
<true/>
```

**Step 3: Define Activity Attributes**

In the widget extension, create your `ActivityAttributes`:

```swift
import ActivityKit
import WidgetKit
import SwiftUI

struct RideTrackingAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var eta: String
        var distance: String
        var status: String
        var progress: Double
    }
    var driverName: String
    var vehicleNumber: String
    var vehicleType: String
}
```

**Step 4: Create Widget Views**

Implement the Lock Screen, Dynamic Island compact, and expanded views in your widget extension. See the [Apple ActivityKit documentation](https://developer.apple.com/documentation/activitykit) for details.

**Step 5: Shared App Group (optional)**

If you need to share data between the app and widget, add an App Group capability to both targets.

## Android Setup

Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />

<!-- For caller notifications (fullscreen intent) -->
<uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT" />

<!-- For alarm channels (bypass DND) -->
<uses-permission android:name="android.permission.ACCESS_NOTIFICATION_POLICY" />
```

For iOS, add to `ios/Runner/Info.plist`:

```xml
<key>UIBackgroundModes</key>
<array>
  <string>remote-notification</string>
  <string>voip</string>
</array>
```

## Platform Support

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
| Badge | N/A | UIApplication badge |
| Live Activities | Ongoing notification | ActivityKit (iOS 16.1+) |
| Dynamic Island | N/A | iPhone 14 Pro+ |
| Alarm channels (bypass DND) | NotificationManager | Critical Alerts (entitlement) |
| Custom sounds | res/raw/ | Bundle .caf/.aiff |
| BigText style | BigTextStyle | UNNotificationContent |
| BigPicture style | BigPictureStyle | UNNotificationAttachment |
| Inbox style | InboxStyle | Grouped summary |
| Messaging style | MessagingStyle | Communication notification |
| Media style | MediaStyle | MPNowPlayingSession |
| Progress style | setProgress() | N/A (shows text fallback) |
| Caller notifications | Fullscreen intent | CallKit |
| Incoming call UI | Custom fullscreen | Native CallKit |
| Missed call | Standard notification | Standard notification |

## License

MIT
