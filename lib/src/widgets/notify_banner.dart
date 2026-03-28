import 'package:flutter/material.dart';

import '../api/notify_tap_event.dart';
import '../platform/notify_pilot_platform.dart';

/// A widget that displays in-app notification banners when notifications
/// arrive while the app is in the foreground.
///
/// Wrap your app's root widget with [NotifyBanner] to show animated
/// banners for foreground notifications.
///
/// ```dart
/// NotifyBanner(
///   onNotification: (notification) => true, // return false to suppress
///   child: MyApp(),
/// )
/// ```
class NotifyBanner extends StatefulWidget {
  /// The child widget (typically your app's root).
  final Widget child;

  /// Called when a foreground notification arrives.
  /// Return `true` to show the banner, `false` to suppress it.
  final bool Function(NotifyTapEvent notification)? onNotification;

  /// Called when the banner is tapped.
  final void Function(NotifyTapEvent notification)? onTap;

  /// Duration the banner is displayed.
  final Duration displayDuration;

  /// Creates an in-app notification banner widget.
  const NotifyBanner({
    super.key,
    required this.child,
    this.onNotification,
    this.onTap,
    this.displayDuration = const Duration(seconds: 4),
  });

  @override
  State<NotifyBanner> createState() => _NotifyBannerState();
}

class _NotifyBannerState extends State<NotifyBanner>
    with SingleTickerProviderStateMixin {
  OverlayEntry? _overlayEntry;
  late AnimationController _animationController;
  NotifyTapEvent? _currentNotification;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _listenForNotifications();
  }

  void _listenForNotifications() {
    NotifyPilotPlatform.instance.setEventHandler((type, data) {
      if (type == 'onForegroundNotification') {
        final event = NotifyTapEvent.fromMap(data);
        final shouldShow = widget.onNotification?.call(event) ?? true;
        if (shouldShow && mounted) {
          _showBanner(event);
        }
      }
    });
  }

  void _showBanner(NotifyTapEvent notification) {
    _dismissBanner();
    _currentNotification = notification;

    _overlayEntry = OverlayEntry(
      builder: (context) => _BannerOverlay(
        notification: notification,
        animation: _animationController,
        onTap: () {
          widget.onTap?.call(notification);
          _dismissBanner();
        },
        onDismiss: _dismissBanner,
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    _animationController.forward();

    Future.delayed(widget.displayDuration, () {
      if (mounted && _currentNotification == notification) {
        _dismissBanner();
      }
    });
  }

  void _dismissBanner() {
    if (_overlayEntry != null) {
      _animationController.reverse().then((_) {
        _overlayEntry?.remove();
        _overlayEntry = null;
      });
    }
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _BannerOverlay extends StatelessWidget {
  final NotifyTapEvent notification;
  final Animation<double> animation;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _BannerOverlay({
    required this.notification,
    required this.animation,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -1),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        )),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(12),
                child: Dismissible(
                  key: ValueKey(notification.notificationId),
                  direction: DismissDirection.up,
                  onDismissed: (_) => onDismiss(),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.notifications,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (notification.title != null)
                                Text(
                                  notification.title!,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              if (notification.body != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  notification.body!,
                                  style: Theme.of(context).textTheme.bodySmall,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
