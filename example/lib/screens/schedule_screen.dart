import 'package:flutter/material.dart';
import 'package:notify_pilot/notify_pilot.dart';

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scheduling')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _DemoButton(
            label: 'Schedule in 5 seconds',
            onPressed: () => NotifyPilot.scheduleAfter(
              const Duration(seconds: 5),
              title: 'Delayed notification',
              body: 'This was scheduled 5 seconds ago',
            ),
          ),
          _DemoButton(
            label: 'Schedule at specific time (+1 min)',
            onPressed: () => NotifyPilot.scheduleAt(
              DateTime.now().add(const Duration(minutes: 1)),
              title: 'Scheduled notification',
              body: 'This was scheduled for a specific time',
            ),
          ),
          _DemoButton(
            label: 'Cron: every minute',
            onPressed: () => NotifyPilot.scheduleCron(
              'every_minute',
              cron: '* * * * *',
              title: 'Every minute',
              body: 'This fires every minute',
            ),
          ),
          _DemoButton(
            label: 'Repeating: hourly',
            onPressed: () => NotifyPilot.scheduleRepeating(
              'hourly_sync',
              interval: RepeatInterval.hourly,
              title: 'Hourly sync',
              body: 'Data has been synced',
            ),
          ),
          const Divider(),
          _DemoButton(
            label: 'Cancel "every_minute"',
            onPressed: () => NotifyPilot.cancelSchedule('every_minute'),
            color: Colors.orange,
          ),
          _DemoButton(
            label: 'Cancel all schedules',
            onPressed: () => NotifyPilot.cancelAllSchedules(),
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
