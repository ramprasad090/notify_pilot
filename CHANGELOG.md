## 1.0.2

- Added alarm channel presets (`NotifyChannel.alarm()`, `.call()`, `.timer()`, `.message()`, `.silent()`)
- Added custom notification sounds (`NotifySound.custom()`, `.alarm()`, `.critical()`, etc.)
- Added custom notification icons (`NotifyIcon.resource()`, `.url()`, `.asset()`, `.file()`, `.bytes()`)
- Added custom notification images (`NotifyImage.url()`, `.asset()`, `.file()`, `.bytes()`)
- Added 6 notification display styles (`NotifyDisplayStyle.bigText()`, `.bigPicture()`, `.inbox()`, `.messaging()`, `.media()`, `.progress()`)
- Added iOS Critical Alert support with graceful degradation
- Added caller notifications (`showIncomingCall()`, `showOutgoingCall()`, `setCallConnected()`, `endCall()`, `showMissedCall()`)
- Added progress notification updates (`updateProgress()`)
- Added media playback state updates (`setMediaPlaybackState()`)

## 1.0.1

- Added iOS Live Activities and Dynamic Island support
- Added Android ongoing notifications (Live Activity equivalent)
- Added Live Activity lifecycle management (start, update, end)
- Added push token support for server-driven Live Activity updates
- Added iOS Widget Extension templates (ride tracking, delivery, sports, timer)
- Added `LiveDismissPolicy` for controlling activity dismissal
- Added `LiveActivityEvent` stream for lifecycle events

## 1.0.0

- Initial release
- Local notifications with title, body, image, deep link, grouping
- Push notifications via FCM (token, topics, custom handler)
- Scheduled notifications (at time, after delay, cron expressions, repeating)
- Notification action buttons with inline reply
- Notification history with read/unread tracking
- Auto-grouping with summary notifications
- Analytics callbacks (delivered, opened, dismissed, action)
- Pre-built widgets (NotifyInbox, NotifyBanner, NotifyBadge)
- bg_orchestrator integration for background task triggers
