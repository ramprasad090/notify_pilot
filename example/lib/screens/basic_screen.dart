import 'package:flutter/material.dart';
import 'package:notify_pilot/notify_pilot.dart';

class BasicScreen extends StatelessWidget {
  const BasicScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Basic Notifications')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _DemoButton(
            label: 'Simple notification',
            onPressed: () => NotifyPilot.show('Hello!'),
          ),
          _DemoButton(
            label: 'With body',
            onPressed: () => NotifyPilot.show(
              'Order shipped!',
              body: 'Your order #1234 is on the way',
            ),
          ),
          _DemoButton(
            label: 'With deep link',
            onPressed: () => NotifyPilot.show(
              'New message from Sarah',
              body: 'Hey, are you free tonight?',
              deepLink: '/chat/sarah_123',
              payload: {'chatId': 'sarah_123'},
            ),
          ),
          _DemoButton(
            label: 'Grouped (tap multiple times)',
            onPressed: () => NotifyPilot.show(
              'Message ${DateTime.now().second}',
              body: 'Grouped notification',
              group: 'messages',
            ),
          ),
          _DemoButton(
            label: 'On updates channel',
            onPressed: () => NotifyPilot.show(
              'Maintenance tonight',
              body: 'Servers will be down 2-4am',
              channel: 'updates',
            ),
          ),
          _DemoButton(
            label: 'With custom ID (42)',
            onPressed: () => NotifyPilot.show(
              'Custom ID notification',
              body: 'This has ID 42',
              id: 42,
            ),
          ),
          const Divider(),
          _DemoButton(
            label: 'Cancel ID 42',
            onPressed: () => NotifyPilot.cancel(42),
            color: Colors.orange,
          ),
          _DemoButton(
            label: 'Cancel all',
            onPressed: () => NotifyPilot.cancelAll(),
            color: Colors.red,
          ),
        ],
      ),
    );
  }
}

class _DemoButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final Color? color;

  const _DemoButton({
    required this.label,
    required this.onPressed,
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
