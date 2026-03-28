import 'package:flutter/material.dart';

import '../api/enums.dart';
import '../api/notify_history_entry.dart';
import '../api/notify_pilot_api.dart';

/// A pre-built widget that displays a notification history inbox.
///
/// ```dart
/// NotifyInbox(
///   onTap: (entry) => navigator.pushNamed(entry.deepLink ?? '/'),
///   groupBy: NotifyGroupBy.date,
/// )
/// ```
class NotifyInbox extends StatefulWidget {
  /// Called when a notification entry is tapped.
  final void Function(NotifyHistoryEntry entry)? onTap;

  /// How to group notifications.
  final NotifyGroupBy? groupBy;

  /// Maximum number of entries to display.
  final int limit;

  /// Optional group filter.
  final String? group;

  /// Widget to show when the inbox is empty.
  final Widget? emptyWidget;

  /// Creates a notification inbox widget.
  const NotifyInbox({
    super.key,
    this.onTap,
    this.groupBy,
    this.limit = 50,
    this.group,
    this.emptyWidget,
  });

  @override
  State<NotifyInbox> createState() => _NotifyInboxState();
}

class _NotifyInboxState extends State<NotifyInbox> {
  List<NotifyHistoryEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final entries = await NotifyPilot.getHistory(
      limit: widget.limit,
      group: widget.group,
    );
    if (mounted) {
      setState(() {
        _entries = entries;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_entries.isEmpty) {
      return widget.emptyWidget ??
          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.notifications_none, size: 48, color: Colors.grey),
                SizedBox(height: 8),
                Text('No notifications',
                    style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
    }

    if (widget.groupBy != null) {
      return _buildGroupedList();
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        itemCount: _entries.length,
        itemBuilder: (context, index) =>
            _buildEntry(context, _entries[index]),
      ),
    );
  }

  Widget _buildGroupedList() {
    final groups = <String, List<NotifyHistoryEntry>>{};
    for (final entry in _entries) {
      final key = switch (widget.groupBy!) {
        NotifyGroupBy.date => _formatDate(entry.timestamp),
        NotifyGroupBy.channel => entry.channel ?? 'Default',
        NotifyGroupBy.group => entry.group ?? 'Ungrouped',
      };
      groups.putIfAbsent(key, () => []).add(entry);
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        itemCount: groups.length,
        itemBuilder: (context, index) {
          final key = groups.keys.elementAt(index);
          final items = groups[key]!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  key,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              ...items.map((entry) => _buildEntry(context, entry)),
              const Divider(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEntry(BuildContext context, NotifyHistoryEntry entry) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: entry.isRead
            ? Colors.grey.shade200
            : Theme.of(context).colorScheme.primaryContainer,
        child: Icon(
          entry.isRead ? Icons.notifications_none : Icons.notifications,
          color: entry.isRead
              ? Colors.grey
              : Theme.of(context).colorScheme.primary,
          size: 20,
        ),
      ),
      title: Text(
        entry.title,
        style: TextStyle(
          fontWeight: entry.isRead ? FontWeight.normal : FontWeight.bold,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: entry.body != null
          ? Text(
              entry.body!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: Text(
        _formatTime(entry.timestamp),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      onTap: () {
        if (!entry.isRead) {
          NotifyPilot.markRead(notificationId: entry.id);
        }
        widget.onTap?.call(entry);
      },
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dt.year, dt.month, dt.day);

    if (date == today) return 'Today';
    if (date == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return '${dt.month}/${dt.day}/${dt.year}';
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dt.month}/${dt.day}';
  }
}
