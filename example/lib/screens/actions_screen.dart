import 'package:flutter/material.dart';
import 'package:notify_pilot/notify_pilot.dart';

class ActionsScreen extends StatelessWidget {
  const ActionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Actions')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _DemoButton(
            label: 'With reply action',
            onPressed: () => NotifyPilot.show(
              'New message from Sarah',
              body: 'Hey, are you free tonight?',
              actions: [
                const NotifyAction('reply', label: 'Reply', input: true),
                const NotifyAction('mark_read', label: 'Mark Read'),
              ],
              deepLink: '/chat/sarah_123',
            ),
          ),
          _DemoButton(
            label: 'With destructive action',
            onPressed: () => NotifyPilot.show(
              'Delete confirmation',
              body: 'Do you want to delete this item?',
              actions: [
                const NotifyAction('delete', label: 'Delete', destructive: true),
                const NotifyAction('cancel', label: 'Keep'),
              ],
            ),
          ),
          _DemoButton(
            label: 'Multiple actions',
            onPressed: () => NotifyPilot.show(
              'New friend request',
              body: 'Alice wants to be your friend',
              actions: [
                const NotifyAction('accept', label: 'Accept'),
                const NotifyAction('decline', label: 'Decline', destructive: true),
                const NotifyAction('view', label: 'View Profile'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DemoButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _DemoButton({
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: FilledButton(
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}
