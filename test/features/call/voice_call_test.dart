import 'dart:convert';

import 'package:cari_ambulan_app/core/network/api_client.dart';
import 'package:cari_ambulan_app/features/call/data/call_repository.dart';
import 'package:cari_ambulan_app/features/call/data/voice_room.dart';
import 'package:cari_ambulan_app/features/call/domain/call_models.dart';
import 'package:cari_ambulan_app/features/call/presentation/providers/voice_call_provider.dart';
import 'package:cari_ambulan_app/features/call/presentation/widgets/active_call_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _FakeRepo implements CallRepository {
  final calls = <String>[];

  /// What `calls/incoming` returns.
  TripCall? ringing;

  /// The status `calls/{id}` returns.
  String callStatus = 'ringing';

  /// Thrown by [start].
  Object? startError;

  @override
  Future<TripCall> start(String requestId) async {
    calls.add('start $requestId');
    if (startError case final error?) throw error;
    return const TripCall(id: 'c-1', status: 'ringing');
  }

  @override
  Future<TripCall?> incoming() async {
    calls.add('incoming');
    return ringing;
  }

  @override
  Future<TripCall> status(String callId) async =>
      TripCall(id: callId, status: callStatus);

  @override
  Future<CallConnection> connection(String callId) async {
    calls.add('token $callId');
    return (url: 'wss://lk.test', token: 'tok-$callId');
  }

  @override
  Future<void> answer(String callId) async => calls.add('answer $callId');

  @override
  Future<void> decline(String callId) async => calls.add('decline $callId');

  @override
  Future<void> end(String callId) async => calls.add('end $callId');
}

class _FakeRoom implements VoiceRoom {
  String? token;
  bool disposed = false;
  bool? muted;

  @override
  void Function()? onPeerJoined;

  @override
  void Function()? onClosed;

  @override
  Future<void> connect({required String url, required String token}) async =>
      this.token = token;

  @override
  Future<void> setMuted(bool muted) async => this.muted = muted;

  @override
  Future<void> setSpeaker(bool speaker) async {}

  @override
  Future<void> dispose() async => disposed = true;
}

void main() {
  late _FakeRepo repo;
  late List<_FakeRoom> rooms;
  late ProviderContainer container;

  VoiceCallState call() => container.read(voiceCallProvider);
  VoiceCallNotifier notifier() => container.read(voiceCallProvider.notifier);

  setUp(() {
    repo = _FakeRepo();
    rooms = [];
    container = ProviderContainer(
      overrides: [
        callRepositoryProvider.overrideWithValue(repo),
        voiceRoomFactoryProvider.overrideWithValue(() {
          final room = _FakeRoom();
          rooms.add(room);
          return room;
        }),
      ],
    );
    // Keep the provider alive between reads.
    container.listen(voiceCallProvider, (_, _) {});
  });

  tearDown(() => container.dispose());

  testWidgets('calling the driver rings, connects when they join, hangs up', (
    tester,
  ) async {
    await notifier().startCall(
      requestId: 'r-1',
      peerName: 'Budi',
      peerRole: 'Driver Ambulans',
    );
    expect(call().status, VoiceCallStatus.ringing);
    expect(call().callId, 'c-1');
    expect(rooms.single.token, 'tok-c-1');

    rooms.single.onPeerJoined!();
    expect(call().status, VoiceCallStatus.connected);
    expect(call().audioConnected, isTrue);

    await tester.pump(const Duration(seconds: 2));
    expect(call().duration, const Duration(seconds: 2));

    await notifier().toggleMute();
    expect(rooms.single.muted, isTrue);

    notifier().endCall();
    expect(call().status, VoiceCallStatus.ended);
    expect(rooms.single.disposed, isTrue);
    expect(repo.calls, ['start r-1', 'token c-1', 'end c-1']);

    await tester.pump(const Duration(milliseconds: 1500));
    expect(call().status, VoiceCallStatus.idle);
  });

  testWidgets('the other side declining ends the call with a reason', (
    tester,
  ) async {
    await notifier().startCall(
      requestId: 'r-1',
      peerName: 'Budi',
      peerRole: 'Driver Ambulans',
    );
    repo.callStatus = 'declined';
    await tester.pump(VoiceCallNotifier.pollEvery);

    expect(call().status, VoiceCallStatus.ended);
    expect(call().errorMessage, 'Panggilan ditolak');
    await tester.pump(const Duration(milliseconds: 1500));
  });

  testWidgets('a ringing call is shown once and answered with Jawab', (
    tester,
  ) async {
    repo.ringing = const TripCall(
      id: 'c-9',
      status: 'ringing',
      callerName: 'Siti',
    );
    notifier().watchIncoming(true, peerRole: 'Pasien / Keluarga');
    await tester.pump();

    expect(call().status, VoiceCallStatus.incoming);
    expect(call().peerName, 'Siti');
    expect(call().peerRole, 'Pasien / Keluarga');

    await notifier().accept();
    expect(call().status, VoiceCallStatus.connected);
    expect(repo.calls, containsAllInOrder(['answer c-9', 'token c-9']));

    // The same call, still reported ringing by a late poll, doesn't ring
    // again once hung up.
    notifier().endCall();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(VoiceCallNotifier.pollEvery);
    expect(call().status, VoiceCallStatus.idle);

    notifier().watchIncoming(false);
  });

  testWidgets('Tolak declines and the trip ending hangs up', (tester) async {
    repo.ringing = const TripCall(id: 'c-9', status: 'ringing');
    notifier().watchIncoming(true, peerRole: 'Driver Ambulans');
    await tester.pump();
    expect(call().displayName, 'Driver Ambulans');

    notifier().decline();
    expect(call().status, VoiceCallStatus.ended);
    expect(repo.calls, contains('decline c-9'));
    await tester.pump(const Duration(seconds: 1));

    repo.ringing = const TripCall(id: 'c-10', status: 'ringing');
    await tester.pump(VoiceCallNotifier.pollEvery);
    expect(call().status, VoiceCallStatus.incoming);

    notifier().watchIncoming(false);
    expect(call().status, VoiceCallStatus.ended);
    expect(repo.calls, contains('end c-10'));
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('both calling at once answers the other side\'s call', (
    tester,
  ) async {
    repo.startError = const CallAlreadyRinging('c-7');
    await notifier().startCall(
      requestId: 'r-1',
      peerName: 'Budi',
      peerRole: 'Driver Ambulans',
    );

    expect(call().status, VoiceCallStatus.connected);
    expect(call().callId, 'c-7');
    expect(repo.calls, ['start r-1', 'answer c-7', 'token c-7']);
    notifier().endCall();
    await tester.pump(const Duration(seconds: 2));
  });

  test('API: a 409 with incoming_call_id becomes CallAlreadyRinging', () async {
    final paths = <String>[];
    final client = ApiClient(
      baseUrl: 'http://api.test',
      client: MockClient((request) async {
        paths.add('${request.method} ${request.url.path}');
        if (request.url.path.endsWith('/calls')) {
          return http.Response(
            jsonEncode({
              'message': 'Lawan bicara sedang menelepon Anda.',
              'incoming_call_id': 'c-7',
            }),
            409,
          );
        }
        return http.Response(
          jsonEncode({'token': 'tok', 'url': 'wss://lk.test'}),
          200,
        );
      }),
    );
    final repo = ApiCallRepository(client);

    await expectLater(
      repo.start('r-1'),
      throwsA(isA<CallAlreadyRinging>().having((e) => e.callId, 'id', 'c-7')),
    );
    expect(await repo.connection('c-7'), (url: 'wss://lk.test', token: 'tok'));
    expect(paths, [
      'POST /api/v1/emergency-requests/r-1/calls',
      'GET /api/v1/calls/c-7/token',
    ]);
  });

  testWidgets('call screen: Jawab / Tolak while ringing, then hang up', (
    tester,
  ) async {
    repo.ringing = const TripCall(
      id: 'c-9',
      status: 'ringing',
      callerName: 'Budi',
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => ActiveCallScreen.show(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    notifier().watchIncoming(true, peerRole: 'Driver Ambulans');
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Budi'), findsOneWidget);
    expect(find.text('Panggilan masuk…'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.call_rounded));
    await tester.pump();
    expect(find.text('Tutup'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.call_end_rounded));
    await tester.pump();
    expect(find.text('Panggilan berakhir'), findsOneWidget);

    // Back to idle: the screen closes itself.
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
    expect(find.text('Budi'), findsNothing);

    notifier().watchIncoming(false);
  });
}
