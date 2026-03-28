import 'package:flutter/material.dart';
import 'package:notify_pilot/notify_pilot.dart';

class LiveActivityScreen extends StatefulWidget {
  const LiveActivityScreen({super.key});

  @override
  State<LiveActivityScreen> createState() => _LiveActivityScreenState();
}

class _LiveActivityScreenState extends State<LiveActivityScreen> {
  String? _rideActivityId;
  String? _deliveryActivityId;
  bool _supported = false;
  bool _hasDynamicIsland = false;

  @override
  void initState() {
    super.initState();
    _checkSupport();
  }

  Future<void> _checkSupport() async {
    final supported = await NotifyPilot.isLiveActivitySupported();
    final dynamicIsland = await NotifyPilot.hasDynamicIsland();
    setState(() {
      _supported = supported;
      _hasDynamicIsland = dynamicIsland;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live Activities')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Device Support',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('Live Activities: ${_supported ? "Yes" : "No"}'),
                  Text(
                      'Dynamic Island: ${_hasDynamicIsland ? "Yes" : "No"}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Ride Tracking',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _DemoButton(
            label: 'Start ride tracking',
            onPressed: _startRideTracking,
          ),
          _DemoButton(
            label: 'Update: driver arriving',
            onPressed: _rideActivityId != null ? _updateRideArriving : null,
          ),
          _DemoButton(
            label: 'Update: in ride',
            onPressed: _rideActivityId != null ? _updateRideInProgress : null,
          ),
          _DemoButton(
            label: 'End: ride completed',
            onPressed: _rideActivityId != null ? _endRide : null,
            color: Colors.green,
          ),
          const Divider(height: 32),
          Text('Food Delivery',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _DemoButton(
            label: 'Start delivery tracking',
            onPressed: _startDeliveryTracking,
          ),
          _DemoButton(
            label: 'Update: picked up',
            onPressed:
                _deliveryActivityId != null ? _updateDeliveryPickedUp : null,
          ),
          _DemoButton(
            label: 'End: delivered',
            onPressed: _deliveryActivityId != null ? _endDelivery : null,
            color: Colors.green,
          ),
          const Divider(height: 32),
          Text('Management',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _DemoButton(
            label: 'List active activities',
            onPressed: _listActivities,
          ),
          _DemoButton(
            label: 'End all activities',
            onPressed: _endAll,
            color: Colors.red,
          ),
        ],
      ),
    );
  }

  Future<void> _startRideTracking() async {
    final id = await NotifyPilot.startLiveActivity(
      type: 'ride_tracking',
      attributes: {
        'driverName': 'Raju Kumar',
        'vehicleNumber': 'KA-01-AB-1234',
        'vehicleType': 'sedan',
      },
      state: {
        'eta': '5 min',
        'distance': '1.2 km',
        'status': 'arriving',
        'progress': 0.3,
      },
      androidNotification: const LiveNotificationConfig(
        channelId: 'ride_tracking',
        channelName: 'Ride Tracking',
        smallIcon: '@drawable/ic_notification',
        ongoing: true,
      ),
      staleAfter: const Duration(minutes: 30),
    );
    setState(() => _rideActivityId = id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ride activity started: $id')),
      );
    }
  }

  Future<void> _updateRideArriving() async {
    await NotifyPilot.updateLiveActivity(_rideActivityId!, state: {
      'eta': '2 min',
      'distance': '0.3 km',
      'status': 'arriving',
      'progress': 0.7,
    });
  }

  Future<void> _updateRideInProgress() async {
    await NotifyPilot.updateLiveActivity(_rideActivityId!, state: {
      'eta': '12 min',
      'distance': '4.5 km',
      'status': 'in_ride',
      'progress': 0.4,
    });
  }

  Future<void> _endRide() async {
    await NotifyPilot.endLiveActivity(
      _rideActivityId!,
      finalState: {
        'status': 'completed',
        'eta': 'Arrived',
        'progress': 1.0,
      },
      dismissPolicy: const LiveDismissPolicy.after(Duration(minutes: 2)),
    );
    setState(() => _rideActivityId = null);
  }

  Future<void> _startDeliveryTracking() async {
    final id = await NotifyPilot.startLiveActivity(
      type: 'food_delivery',
      attributes: {
        'restaurantName': 'Pizza Palace',
        'orderNumber': '#1234',
      },
      state: {
        'status': 'preparing',
        'eta': '25 min',
        'progress': 0.2,
      },
      androidNotification: const LiveNotificationConfig(
        channelId: 'delivery_tracking',
        channelName: 'Delivery Tracking',
        smallIcon: '@drawable/ic_notification',
        ongoing: true,
      ),
    );
    setState(() => _deliveryActivityId = id);
  }

  Future<void> _updateDeliveryPickedUp() async {
    await NotifyPilot.updateLiveActivity(_deliveryActivityId!, state: {
      'status': 'on_the_way',
      'eta': '10 min',
      'deliveryPerson': 'Amit',
      'progress': 0.6,
    });
  }

  Future<void> _endDelivery() async {
    await NotifyPilot.endLiveActivity(
      _deliveryActivityId!,
      finalState: {'status': 'delivered', 'eta': 'Delivered!', 'progress': 1.0},
      dismissPolicy: const LiveDismissPolicy.immediate(),
    );
    setState(() => _deliveryActivityId = null);
  }

  Future<void> _listActivities() async {
    final activities = await NotifyPilot.getActiveLiveActivities();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Active Live Activities'),
        content: Text(activities.isEmpty
            ? 'No active activities'
            : activities
                .map((a) => '${a.type}: ${a.id} (${a.status.name})')
                .join('\n')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('OK'))
        ],
      ),
    );
  }

  Future<void> _endAll() async {
    await NotifyPilot.endAllLiveActivities();
    setState(() {
      _rideActivityId = null;
      _deliveryActivityId = null;
    });
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
