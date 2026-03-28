import 'dart:async';

import 'package:flutter/material.dart';

import '../api/notify_pilot_api.dart';

/// A widget that displays an unread notification count badge on its child.
///
/// ```dart
/// NotifyBadge(
///   group: 'messages',
///   child: Icon(Icons.notifications),
/// )
/// ```
class NotifyBadge extends StatefulWidget {
  /// The widget to display the badge on.
  final Widget child;

  /// Optional group to filter unread count.
  final String? group;

  /// Badge background color.
  final Color? color;

  /// Badge text color.
  final Color? textColor;

  /// Badge size (diameter).
  final double size;

  /// How often to refresh the count.
  final Duration refreshInterval;

  /// Creates a notification badge widget.
  const NotifyBadge({
    super.key,
    required this.child,
    this.group,
    this.color,
    this.textColor,
    this.size = 18,
    this.refreshInterval = const Duration(seconds: 5),
  });

  @override
  State<NotifyBadge> createState() => _NotifyBadgeState();
}

class _NotifyBadgeState extends State<NotifyBadge> {
  int _count = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(widget.refreshInterval, (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final count = await NotifyPilot.getUnreadCount(group: widget.group);
    if (mounted && count != _count) {
      setState(() => _count = count);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        widget.child,
        if (_count > 0)
          Positioned(
            right: -6,
            top: -6,
            child: Container(
              constraints: BoxConstraints(
                minWidth: widget.size,
                minHeight: widget.size,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: widget.color ?? Theme.of(context).colorScheme.error,
                borderRadius: BorderRadius.circular(widget.size / 2),
              ),
              alignment: Alignment.center,
              child: Text(
                _count > 99 ? '99+' : '$_count',
                style: TextStyle(
                  color: widget.textColor ?? Colors.white,
                  fontSize: widget.size * 0.6,
                  fontWeight: FontWeight.bold,
                  height: 1,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
