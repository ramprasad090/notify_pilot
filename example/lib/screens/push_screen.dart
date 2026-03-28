import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:notify_pilot/notify_pilot.dart';

class PushScreen extends StatefulWidget {
  const PushScreen({super.key});

  @override
  State<PushScreen> createState() => _PushScreenState();
}

class _PushScreenState extends State<PushScreen> {
  String? _token;
  String _status = 'Not fetched';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Push (FCM)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('FCM Token',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(_token ?? _status,
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      FilledButton(
                        onPressed: () async {
                          setState(() => _status = 'Fetching...');
                          try {
                            final token = await NotifyPilot.getFcmToken();
                            setState(() {
                              _token = token;
                              _status = token != null
                                  ? 'Token received'
                                  : 'No token (Firebase not configured)';
                            });
                          } catch (e) {
                            setState(() => _status = 'Error: $e');
                          }
                        },
                        child: const Text('Get Token'),
                      ),
                      if (_token != null) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _token!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Token copied!')),
                            );
                          },
                          icon: const Icon(Icons.copy),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Topics', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _TopicTile(topic: 'news'),
          _TopicTile(topic: 'promotions'),
          _TopicTile(topic: 'updates'),
        ],
      ),
    );
  }
}

class _TopicTile extends StatefulWidget {
  final String topic;
  const _TopicTile({required this.topic});

  @override
  State<_TopicTile> createState() => _TopicTileState();
}

class _TopicTileState extends State<_TopicTile> {
  bool _subscribed = false;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(widget.topic),
      value: _subscribed,
      onChanged: (value) async {
        if (value) {
          await NotifyPilot.subscribeTopic(widget.topic);
        } else {
          await NotifyPilot.unsubscribeTopic(widget.topic);
        }
        setState(() => _subscribed = value);
      },
    );
  }
}
