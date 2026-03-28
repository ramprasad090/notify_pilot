import 'package:flutter/material.dart';
import 'package:notify_pilot/notify_pilot.dart';

class ChannelsScreen extends StatefulWidget {
  const ChannelsScreen({super.key});

  @override
  State<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends State<ChannelsScreen> {
  List<NotifyChannel> _channels = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _channels = NotifyPilot.getChannels();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Channels')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () async {
                      await NotifyPilot.createChannel(const NotifyChannel(
                        id: 'promotions',
                        name: 'Promotions',
                        importance: NotifyImportance.low,
                      ));
                      _refresh();
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add "Promotions"'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _channels.length,
              itemBuilder: (context, index) {
                final ch = _channels[index];
                return ListTile(
                  title: Text(ch.name),
                  subtitle: Text('ID: ${ch.id} • Importance: ${ch.importance.name}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: () => NotifyPilot.show(
                      'Test on ${ch.name}',
                      body: 'Sent to channel ${ch.id}',
                      channel: ch.id,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
