import 'package:flutter/material.dart';
import 'package:notify_pilot/notify_pilot.dart';

import 'screens/basic_screen.dart';
import 'screens/schedule_screen.dart';
import 'screens/actions_screen.dart';
import 'screens/channels_screen.dart';
import 'screens/history_screen.dart';
import 'screens/push_screen.dart';
import 'screens/widgets_screen.dart';
import 'screens/live_activity_screen.dart';
import 'screens/styles_screen.dart';
import 'screens/caller_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await NotifyPilot.initialize(
    defaultChannel: const NotifyChannel(
      id: 'general',
      name: 'General',
      importance: NotifyImportance.high,
    ),
    channels: [
      const NotifyChannel(
          id: 'messages', name: 'Messages', importance: NotifyImportance.high),
      const NotifyChannel(
          id: 'updates', name: 'Updates', importance: NotifyImportance.low),
      const NotifyChannel(
          id: 'reminders',
          name: 'Reminders',
          importance: NotifyImportance.max),
      const NotifyChannel.alarm(id: 'alarms', name: 'Alarms'),
      const NotifyChannel.timer(id: 'timers', name: 'Timers'),
      const NotifyChannel.call(id: 'calls', name: 'Calls'),
    ],
    onTap: (event) {
      debugPrint('Notification tapped: ${event.title} → ${event.deepLink}');
    },
    onAction: (event) {
      debugPrint('Action: ${event.actionId}, input: ${event.inputText}');
    },
    analytics: NotifyAnalytics(
      onDelivered: (n) => debugPrint('Analytics: delivered ${n.title}'),
      onOpened: (n) => debugPrint('Analytics: opened ${n.title}'),
    ),
    history: const HistoryConfig(enabled: true, maxEntries: 100),
  );

  runApp(const NotifyPilotExample());
}

class NotifyPilotExample extends StatelessWidget {
  const NotifyPilotExample({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NotifyPilot Demo',
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final demos = <_DemoItem>[
      _DemoItem(
        icon: Icons.notifications,
        title: 'Basic Notifications',
        subtitle: 'Show, image, deep link, group',
        builder: (_) => const BasicScreen(),
      ),
      _DemoItem(
        icon: Icons.schedule,
        title: 'Scheduling',
        subtitle: 'At time, after delay, cron',
        builder: (_) => const ScheduleScreen(),
      ),
      _DemoItem(
        icon: Icons.touch_app,
        title: 'Actions',
        subtitle: 'Buttons, inline reply',
        builder: (_) => const ActionsScreen(),
      ),
      _DemoItem(
        icon: Icons.tune,
        title: 'Channels',
        subtitle: 'Create, list, delete',
        builder: (_) => const ChannelsScreen(),
      ),
      _DemoItem(
        icon: Icons.history,
        title: 'History',
        subtitle: 'Inbox, unread count',
        builder: (_) => const HistoryScreen(),
      ),
      _DemoItem(
        icon: Icons.cloud,
        title: 'Push (FCM)',
        subtitle: 'Token, topics',
        builder: (_) => const PushScreen(),
      ),
      _DemoItem(
        icon: Icons.widgets,
        title: 'Widgets',
        subtitle: 'Banner, badge, inbox',
        builder: (_) => const WidgetsScreen(),
      ),
      _DemoItem(
        icon: Icons.play_circle,
        title: 'Live Activities',
        subtitle: 'Ride tracking, delivery, Dynamic Island',
        builder: (_) => const LiveActivityScreen(),
      ),
      _DemoItem(
        icon: Icons.style,
        title: 'Styles & Media',
        subtitle: 'BigText, BigPicture, Inbox, Progress, Alarms',
        builder: (_) => const StylesScreen(),
      ),
      _DemoItem(
        icon: Icons.phone,
        title: 'Caller Notifications',
        subtitle: 'Incoming, outgoing, missed calls',
        builder: (_) => const CallerScreen(),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('NotifyPilot Demo'),
      ),
      body: ListView.builder(
        itemCount: demos.length,
        itemBuilder: (context, index) {
          final demo = demos[index];
          return ListTile(
            leading: Icon(demo.icon),
            title: Text(demo.title),
            subtitle: Text(demo.subtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: demo.builder),
            ),
          );
        },
      ),
    );
  }
}

class _DemoItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final WidgetBuilder builder;

  const _DemoItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.builder,
  });
}
