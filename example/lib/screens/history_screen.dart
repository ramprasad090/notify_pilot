import 'package:flutter/material.dart';
import 'package:notify_pilot/notify_pilot.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _refreshCount();
  }

  Future<void> _refreshCount() async {
    final count = await NotifyPilot.getUnreadCount();
    if (mounted) setState(() => _unreadCount = count);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await NotifyPilot.markAllRead();
              _refreshCount();
            },
            icon: const Icon(Icons.done_all),
            label: const Text('Mark all read'),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Unread: $_unreadCount',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Row(
                  children: [
                    FilledButton(
                      onPressed: () async {
                        await NotifyPilot.clearHistory();
                        _refreshCount();
                        if (mounted) setState(() {});
                      },
                      child: const Text('Clear History'),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () {
                        _refreshCount();
                        setState(() {});
                      },
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: NotifyInbox(
              onTap: (entry) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Tapped: ${entry.title}')),
                );
                _refreshCount();
              },
              groupBy: NotifyGroupBy.date,
            ),
          ),
        ],
      ),
    );
  }
}
