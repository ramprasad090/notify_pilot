import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:notify_pilot/notify_pilot.dart';
class MockNotifyPilotPlatform extends Mock implements NotifyPilotPlatform {}

void main() {
  late MockNotifyPilotPlatform mockPlatform;

  setUp(() {
    mockPlatform = MockNotifyPilotPlatform();
    NotifyPilotPlatform.instance = mockPlatform;
    NotifyPilot.reset();
  });

  group('NotifyPilot', () {
    group('initialize', () {
      test('initializes with default settings', () async {
        when(() => mockPlatform.initialize(any()))
            .thenAnswer((_) async => true);
        when(() => mockPlatform.createChannel(any()))
            .thenAnswer((_) async => true);
        when(() => mockPlatform.setEventHandler(any())).thenReturn(null);

        await NotifyPilot.initialize();

        verify(() => mockPlatform.initialize(any())).called(1);
        // Default channel should be created
        verify(() => mockPlatform.createChannel(any())).called(1);
      });

      test('initializes with custom channels', () async {
        when(() => mockPlatform.initialize(any()))
            .thenAnswer((_) async => true);
        when(() => mockPlatform.createChannel(any()))
            .thenAnswer((_) async => true);
        when(() => mockPlatform.setEventHandler(any())).thenReturn(null);

        await NotifyPilot.initialize(
          channels: [
            const NotifyChannel(id: 'messages', name: 'Messages'),
            const NotifyChannel(id: 'updates', name: 'Updates'),
          ],
        );

        // Default + 2 custom channels = 3
        verify(() => mockPlatform.createChannel(any())).called(3);
      });

      test('only initializes once', () async {
        when(() => mockPlatform.initialize(any()))
            .thenAnswer((_) async => true);
        when(() => mockPlatform.createChannel(any()))
            .thenAnswer((_) async => true);
        when(() => mockPlatform.setEventHandler(any())).thenReturn(null);

        await NotifyPilot.initialize();
        await NotifyPilot.initialize(); // second call should be no-op

        verify(() => mockPlatform.initialize(any())).called(1);
      });
    });

    group('show', () {
      setUp(() async {
        when(() => mockPlatform.initialize(any()))
            .thenAnswer((_) async => true);
        when(() => mockPlatform.createChannel(any()))
            .thenAnswer((_) async => true);
        when(() => mockPlatform.setEventHandler(any())).thenReturn(null);
        when(() => mockPlatform.show(any()))
            .thenAnswer((_) async => 42);

        await NotifyPilot.initialize();
      });

      test('shows basic notification', () async {
        final id = await NotifyPilot.show('Hello!');

        expect(id, 42);
        final call = verify(() => mockPlatform.show(captureAny()))
            .captured
            .single as Map<String, dynamic>;
        expect(call['title'], 'Hello!');
      });

      test('shows notification with body', () async {
        await NotifyPilot.show('Title', body: 'Body text');

        final call = verify(() => mockPlatform.show(captureAny()))
            .captured
            .single as Map<String, dynamic>;
        expect(call['title'], 'Title');
        expect(call['body'], 'Body text');
      });

      test('shows notification with custom ID', () async {
        await NotifyPilot.show('Test', id: 99);

        final call = verify(() => mockPlatform.show(captureAny()))
            .captured
            .single as Map<String, dynamic>;
        expect(call['id'], 99);
      });

      test('shows notification with actions', () async {
        await NotifyPilot.show(
          'Message',
          actions: [
            const NotifyAction('reply', label: 'Reply', input: true),
            const NotifyAction('dismiss', label: 'Dismiss'),
          ],
        );

        final call = verify(() => mockPlatform.show(captureAny()))
            .captured
            .single as Map<String, dynamic>;
        final actions = call['actions'] as List;
        expect(actions.length, 2);
        expect((actions[0] as Map)['id'], 'reply');
        expect((actions[0] as Map)['input'], true);
      });

      test('shows notification with deep link and payload', () async {
        await NotifyPilot.show(
          'Test',
          deepLink: '/chat/123',
          payload: {'chatId': '123'},
        );

        final call = verify(() => mockPlatform.show(captureAny()))
            .captured
            .single as Map<String, dynamic>;
        expect(call['deepLink'], '/chat/123');
        expect(call['payload'], {'chatId': '123'});
      });
    });

    group('cancel', () {
      setUp(() async {
        when(() => mockPlatform.initialize(any()))
            .thenAnswer((_) async => true);
        when(() => mockPlatform.createChannel(any()))
            .thenAnswer((_) async => true);
        when(() => mockPlatform.setEventHandler(any())).thenReturn(null);

        await NotifyPilot.initialize();
      });

      test('cancels by ID', () async {
        when(() => mockPlatform.cancel(42))
            .thenAnswer((_) async => true);

        await NotifyPilot.cancel(42);
        verify(() => mockPlatform.cancel(42)).called(1);
      });

      test('cancels all', () async {
        when(() => mockPlatform.cancelAll())
            .thenAnswer((_) async => true);

        await NotifyPilot.cancelAll();
        verify(() => mockPlatform.cancelAll()).called(1);
      });

      test('cancels by group', () async {
        when(() => mockPlatform.cancelGroup('messages'))
            .thenAnswer((_) async => true);

        await NotifyPilot.cancelGroup('messages');
        verify(() => mockPlatform.cancelGroup('messages')).called(1);
      });
    });

    group('permissions', () {
      setUp(() async {
        when(() => mockPlatform.initialize(any()))
            .thenAnswer((_) async => true);
        when(() => mockPlatform.createChannel(any()))
            .thenAnswer((_) async => true);
        when(() => mockPlatform.setEventHandler(any())).thenReturn(null);

        await NotifyPilot.initialize();
      });

      test('gets permission status', () async {
        when(() => mockPlatform.getPermission())
            .thenAnswer((_) async => 'granted');

        final status = await NotifyPilot.getPermissionStatus();
        expect(status, NotifyPermission.granted);
      });

      test('requests permission', () async {
        when(() => mockPlatform.requestPermission())
            .thenAnswer((_) async => true);

        final result = await NotifyPilot.requestPermission();
        expect(result, true);
      });
    });

    group('channels', () {
      setUp(() async {
        when(() => mockPlatform.initialize(any()))
            .thenAnswer((_) async => true);
        when(() => mockPlatform.createChannel(any()))
            .thenAnswer((_) async => true);
        when(() => mockPlatform.setEventHandler(any())).thenReturn(null);

        await NotifyPilot.initialize();
      });

      test('creates channel', () async {
        await NotifyPilot.createChannel(
          const NotifyChannel(id: 'promo', name: 'Promotions'),
        );

        // Called during init (default) + this call
        verify(() => mockPlatform.createChannel(any())).called(2);
      });

      test('deletes channel', () async {
        when(() => mockPlatform.deleteChannel('promo'))
            .thenAnswer((_) async => true);

        await NotifyPilot.deleteChannel('promo');
        verify(() => mockPlatform.deleteChannel('promo')).called(1);
      });

      test('returns registered channels', () {
        final channels = NotifyPilot.getChannels();
        expect(channels.length, 1); // default channel
        expect(channels.first.id, 'default');
      });
    });
  });
}
