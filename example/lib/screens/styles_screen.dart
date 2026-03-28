import 'package:flutter/material.dart';
import 'package:notify_pilot/notify_pilot.dart';

class StylesScreen extends StatefulWidget {
  const StylesScreen({super.key});

  @override
  State<StylesScreen> createState() => _StylesScreenState();
}

class _StylesScreenState extends State<StylesScreen> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notification Styles')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Display Styles',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _DemoButton(
            label: 'Big Text',
            onPressed: _showBigText,
          ),
          _DemoButton(
            label: 'Big Picture',
            onPressed: _showBigPicture,
          ),
          _DemoButton(
            label: 'Inbox (5 lines)',
            onPressed: _showInbox,
          ),
          _DemoButton(
            label: 'Messaging',
            onPressed: _showMessaging,
          ),
          _DemoButton(
            label: 'Progress (animated)',
            onPressed: _showProgress,
          ),
          const Divider(height: 32),
          Text('Custom Sounds',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _DemoButton(
            label: 'Default sound',
            onPressed: () => NotifyPilot.show('Default Sound',
                body: 'Uses system default', sound: const NotifySound.default_()),
          ),
          _DemoButton(
            label: 'Silent',
            onPressed: () => NotifyPilot.show('Silent',
                body: 'No sound', sound: const NotifySound.none()),
          ),
          const Divider(height: 32),
          Text('Alarm Channels',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _DemoButton(
            label: 'Alarm notification',
            onPressed: _showAlarm,
          ),
          _DemoButton(
            label: 'Timer notification',
            onPressed: _showTimer,
          ),
          const Divider(height: 32),
          Text('Custom Icons & Images',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _DemoButton(
            label: 'With large icon',
            onPressed: _showWithLargeIcon,
          ),
        ],
      ),
    );
  }

  Future<void> _showBigText() async {
    await NotifyPilot.show(
      'Article published',
      body: 'Your article has been published...',
      displayStyle: const NotifyDisplayStyle.bigText(
        bigText:
            'Your article "Building Flutter Packages" has been published '
            'and is now live on the blog. It has already received 42 views '
            'and 5 comments. Keep up the great work!',
        summaryText: 'Blog Update',
      ),
    );
  }

  Future<void> _showBigPicture() async {
    await NotifyPilot.show(
      'New photo from Sarah',
      body: 'Check out this sunset!',
      displayStyle: NotifyDisplayStyle.bigPicture(
        picture: const NotifyImage.url(
            'https://picsum.photos/800/400'),
        summaryText: 'Photo from Sarah',
        hideLargeIconOnExpand: true,
      ),
    );
  }

  Future<void> _showInbox() async {
    await NotifyPilot.show(
      '5 new emails',
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
  }

  Future<void> _showMessaging() async {
    await NotifyPilot.show(
      'Team Chat',
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
          NotifyMessage(
            text: 'Works for me',
            sender: null, // current user
            time: DateTime.now(),
          ),
        ],
        isGroupConversation: true,
      ),
    );
  }

  Future<void> _showProgress() async {
    final id = await NotifyPilot.show(
      'Downloading...',
      body: 'flutter_app_v2.0.apk',
      displayStyle: const NotifyDisplayStyle.progress(progress: 0.0),
      ongoing: true,
    );
    // Animate progress
    for (var i = 1; i <= 10; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      final progress = i / 10;
      await NotifyPilot.updateProgress(
        id,
        progress: progress,
        title: progress >= 1.0 ? 'Download complete' : null,
        ongoing: progress < 1.0,
      );
    }
  }

  Future<void> _showAlarm() async {
    await NotifyPilot.show(
      'Wake up!',
      body: 'Morning alarm — 7:00 AM',
      channel: 'alarms',
      ongoing: true,
      fullscreen: true,
      turnScreenOn: true,
      actions: [
        const NotifyAction('snooze', label: 'Snooze 5 min'),
        const NotifyAction('dismiss', label: 'Dismiss', destructive: true),
      ],
    );
  }

  Future<void> _showTimer() async {
    await NotifyPilot.show(
      'Timer done!',
      body: 'Your 15-minute timer is complete',
      channel: 'timers',
      sound: const NotifySound.default_(),
    );
  }

  Future<void> _showWithLargeIcon() async {
    await NotifyPilot.show(
      'Sarah sent a message',
      body: 'Hey, are you free tonight?',
      largeIcon: const NotifyIcon.url(
          'https://picsum.photos/200'),
    );
  }
}

class _DemoButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color? color;

  const _DemoButton({
    required this.label,
    this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: FilledButton(
        onPressed: onPressed,
        style: color != null
            ? FilledButton.styleFrom(backgroundColor: color)
            : null,
        child: Text(label),
      ),
    );
  }
}
