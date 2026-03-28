import 'dart:async';

import 'package:flutter/material.dart';
import 'package:notify_pilot/notify_pilot.dart';

class CallerScreen extends StatefulWidget {
  const CallerScreen({super.key});

  @override
  State<CallerScreen> createState() => _CallerScreenState();
}

class _CallerScreenState extends State<CallerScreen> {
  StreamSubscription<CallEvent>? _callEventSub;
  final List<String> _eventLog = [];

  @override
  void initState() {
    super.initState();
    _callEventSub = NotifyPilot.onCallEvent.listen((event) {
      final label = switch (event) {
        CallAccepted(callId: var id) => 'Accepted: $id',
        CallDeclined(callId: var id) => 'Declined: $id',
        CallEnded(callId: var id) => 'Ended: $id',
        CallTimeout(callId: var id) => 'Timeout: $id',
        CallMuted(callId: var id, muted: var m) =>
          '${m ? "Muted" : "Unmuted"}: $id',
        CallSpeaker(callId: var id, speaker: var s) =>
          'Speaker ${s ? "on" : "off"}: $id',
        CallHeld(callId: var id, held: var h) =>
          '${h ? "Held" : "Resumed"}: $id',
      };
      setState(() => _eventLog.insert(0, label));
    });
  }

  @override
  void dispose() {
    _callEventSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Caller Notifications')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Incoming Calls',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _DemoButton(
            label: 'Incoming audio call',
            onPressed: _showIncomingAudio,
          ),
          _DemoButton(
            label: 'Incoming video call',
            onPressed: _showIncomingVideo,
          ),
          _DemoButton(
            label: 'Hide incoming call',
            onPressed: _hideIncoming,
            color: Colors.orange,
          ),
          const Divider(height: 32),
          Text('Call Actions',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _DemoButton(
            label: 'Accept call (set connected)',
            onPressed: _acceptCall,
            color: Colors.green,
          ),
          _DemoButton(
            label: 'End call',
            onPressed: _endCall,
            color: Colors.red,
          ),
          const Divider(height: 32),
          Text('Outgoing & Missed',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _DemoButton(
            label: 'Show outgoing call',
            onPressed: _showOutgoing,
          ),
          _DemoButton(
            label: 'Show missed call',
            onPressed: _showMissed,
          ),
          const Divider(height: 32),
          Text('Management',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _DemoButton(
            label: 'List active calls',
            onPressed: _listActiveCalls,
          ),
          if (_eventLog.isNotEmpty) ...[
            const Divider(height: 32),
            Text('Event Log',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...List.generate(
              _eventLog.length > 10 ? 10 : _eventLog.length,
              (i) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  _eventLog[i],
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showIncomingAudio() async {
    await NotifyPilot.showIncomingCall(
      callId: 'call_audio_${DateTime.now().millisecondsSinceEpoch}',
      callerName: 'Priya Sharma',
      callerNumber: '+91 98765 43210',
      callType: CallType.audio,
      ringtone: const NotifySound.default_(),
      timeout: const Duration(seconds: 30),
      onAccept: (id) {
        debugPrint('Call accepted: $id');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Accepted call: $id')),
          );
        }
      },
      onDecline: (id) => debugPrint('Call declined: $id'),
      onTimeout: (id) => debugPrint('Call timed out: $id'),
    );
  }

  Future<void> _showIncomingVideo() async {
    await NotifyPilot.showIncomingCall(
      callId: 'call_video_${DateTime.now().millisecondsSinceEpoch}',
      callerName: 'Rahul Verma',
      callerNumber: '+91 91234 56789',
      callType: CallType.video,
      ringtone: const NotifySound.default_(),
      timeout: const Duration(seconds: 30),
      onAccept: (id) {
        debugPrint('Video call accepted: $id');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Accepted video call: $id')),
          );
        }
      },
      onDecline: (id) => debugPrint('Video call declined: $id'),
      onTimeout: (id) => debugPrint('Video call timed out: $id'),
    );
  }

  Future<void> _hideIncoming() async {
    final calls = await NotifyPilot.getActiveCalls();
    final ringing =
        calls.where((c) => c.state == CallState.ringing).toList();
    if (ringing.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No ringing calls to hide')),
      );
      return;
    }
    await NotifyPilot.hideIncomingCall(ringing.first.callId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Hidden call: ${ringing.first.callId}')),
    );
  }

  Future<void> _acceptCall() async {
    final calls = await NotifyPilot.getActiveCalls();
    final ringing =
        calls.where((c) => c.state == CallState.ringing).toList();
    if (ringing.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No ringing calls to accept')),
      );
      return;
    }
    await NotifyPilot.setCallConnected(ringing.first.callId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Connected: ${ringing.first.callerName}')),
    );
  }

  Future<void> _endCall() async {
    final calls = await NotifyPilot.getActiveCalls();
    final active = calls
        .where((c) =>
            c.state == CallState.connected || c.state == CallState.ringing)
        .toList();
    if (active.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active calls to end')),
      );
      return;
    }
    await NotifyPilot.endCall(active.first.callId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Ended call with ${active.first.callerName}')),
    );
  }

  Future<void> _showOutgoing() async {
    await NotifyPilot.showOutgoingCall(
      callId: 'call_out_${DateTime.now().millisecondsSinceEpoch}',
      callerName: 'Amit Patel',
      callerNumber: '+91 99887 76655',
      callType: CallType.audio,
      onCancel: (id) => debugPrint('Outgoing call cancelled: $id'),
    );
  }

  Future<void> _showMissed() async {
    await NotifyPilot.showMissedCall(
      callId: 'call_missed_${DateTime.now().millisecondsSinceEpoch}',
      callerName: 'Deepa Nair',
      callerNumber: '+91 87654 32100',
      time: DateTime.now().subtract(const Duration(minutes: 3)),
      actions: [
        const NotifyAction('call_back', label: 'Call Back'),
        const NotifyAction('message', label: 'Message'),
      ],
    );
  }

  Future<void> _listActiveCalls() async {
    final calls = await NotifyPilot.getActiveCalls();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Active Calls'),
        content: Text(calls.isEmpty
            ? 'No active calls'
            : calls
                .map((c) =>
                    '${c.callerName} (${c.callType.name}, ${c.state.name})')
                .join('\n')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('OK'))
        ],
      ),
    );
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
