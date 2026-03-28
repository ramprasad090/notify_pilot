## 1.0.2

- Added alarm channel presets (`NotifyChannel.alarm()`, `.call()`, `.timer()`, `.message()`, `.silent()`)
- Added custom notification sounds (`NotifySound.custom()`, `.alarm()`, `.critical()`, `.systemAlarm()`, `.default_()`, `.none()`)
- Added custom notification icons (`NotifyIcon.resource()`, `.url()`, `.asset()`, `.file()`, `.bytes()`)
- Added custom notification images (`NotifyImage.url()`, `.asset()`, `.file()`, `.bytes()`)
- Added 6 notification display styles (`NotifyDisplayStyle.bigText()`, `.bigPicture()`, `.inbox()`, `.messaging()`, `.media()`, `.progress()`)
- Added iOS Critical Alert support with graceful degradation to time-sensitive
- Added caller notifications (`showIncomingCall()`, `showOutgoingCall()`, `setCallConnected()`, `endCall()`, `showMissedCall()`, `hideIncomingCall()`)
- Added call event stream (`onCallEvent`) with accept, decline, end, mute, hold, speaker, timeout events
- Added progress notification updates (`updateProgress()`)
- Added media playback state updates (`setMediaPlaybackState()`)
- Added fullscreen intent support for alarm and call notifications
- Android: fullscreen `IncomingCallActivity`, `CallConnectionService`, `CallActionReceiver`
- iOS: CallKit integration with China fallback, PushKit VoIP push support
- Fixed action button key names (Dart sends `label`/`input`, not `title`/`isReply`)
- Fixed notification display on Android for all 6 styles
- Fixed sound configuration on both platforms
- Fixed caller avatar download and display

## 1.0.1

- Added iOS Live Activities and Dynamic Island support via ActivityKit
- Added Android ongoing notifications as Live Activity equivalent
- Added Live Activity lifecycle management (`startLiveActivity()`, `updateLiveActivity()`, `endLiveActivity()`, `endAllLiveActivities()`)
- Added push token support for server-driven Live Activity updates (`getLiveActivityPushToken()`)
- Added iOS Widget Extension templates (ride tracking, delivery, sports scores, countdown timer)
- Added `LiveDismissPolicy` for controlling activity dismissal behavior
- Added `LiveActivityEvent` stream for lifecycle events
- Added `LiveActivityInfo` and `LiveActivityStatus` query APIs
- Added `LiveActivityInitConfig` for App Group and URL scheme setup

## 1.0.0

- Initial release
- Local notifications with title, body, image, deep link, grouping
- Push notifications via FCM (token, topics, custom handler)
- Scheduled notifications (at time, after delay, cron expressions, repeating)
- Built-in cron parser -- pure Dart, zero dependencies
- Notification action buttons with inline reply
- Auto timezone handling -- pass DateTime directly
- Auto-grouping with summary notifications
- Notification history with read/unread tracking
- Analytics callbacks (delivered, opened, dismissed, action)
- Pre-built widgets (NotifyInbox, NotifyBanner, NotifyBadge)
- bg_orchestrator integration for background task triggers
