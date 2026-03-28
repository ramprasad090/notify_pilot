import 'package:flutter/material.dart';
import 'package:notify_pilot/notify_pilot.dart';

class WidgetsScreen extends StatelessWidget {
  const WidgetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Widgets'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: NotifyBadge(
              group: 'messages',
              child: const Icon(Icons.notifications),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('NotifyBadge',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  const Text(
                      'The bell icon in the app bar shows unread count.'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => NotifyPilot.show(
                      'Badge test',
                      body: 'This increments the badge',
                      group: 'messages',
                    ),
                    child: const Text('Send to "messages" group'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('NotifyBanner',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  const Text(
                      'Wrap your app root with NotifyBanner to show '
                      'in-app banners for foreground notifications.'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => NotifyPilot.show(
                      'Banner test',
                      body: 'This would show as a banner',
                    ),
                    child: const Text('Trigger notification'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('NotifyInbox',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  const Text(
                      'See the History screen for a full NotifyInbox demo.'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Badge Count (iOS)',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      FilledButton(
                        onPressed: () => NotifyPilot.setBadgeCount(5),
                        child: const Text('Set badge to 5'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () => NotifyPilot.clearBadge(),
                        child: const Text('Clear badge'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
