import 'package:cari_ambulan/features/call/domain/call_models.dart';
import 'package:cari_ambulan/features/call/presentation/providers/voice_call_provider.dart';
import 'package:cari_ambulan/features/driver/data/mock_driver_repository.dart';
import 'package:cari_ambulan/features/driver/presentation/providers/driver_home_provider.dart';
import 'package:cari_ambulan/features/driver/presentation/widgets/trip_call_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A call that is already connected, as after the driver answered.
class _ConnectedVoice extends VoiceCallNotifier {
  @override
  VoiceCallState build() => const VoiceCallState(
    status: VoiceCallStatus.connected,
    callId: 'call-1',
    peerName: 'Siti Rahmawati',
    peerRole: 'Pasien / Keluarga',
    duration: Duration(seconds: 5),
  );
}

void main() {
  late MockDriverRepository repo;

  Future<void> pumpTripScreen(
    WidgetTester tester, {
    bool connected = false,
  }) async {
    repo = MockDriverRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          driverRepositoryProvider.overrideWithValue(repo),
          if (connected) voiceCallProvider.overrideWith(_ConnectedVoice.new),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: TripCallOverlay(
              child: Column(children: [ActiveCallBar(), Text('Menuju pasien')]),
            ),
          ),
        ),
      ),
    );
  }

  VoiceCallState voiceState(WidgetTester tester) => ProviderScope.containerOf(
    tester.element(find.byType(TripCallOverlay)),
  ).read(voiceCallProvider);

  testWidgets('the reporter call rings the shared call screen', (tester) async {
    await pumpTripScreen(tester);
    expect(voiceState(tester).status, VoiceCallStatus.idle);

    repo.ringFromReporter();
    await tester.pump();

    // The same incoming call state the reporter's app uses, not a separate
    // driver-only panel.
    final call = voiceState(tester);
    expect(call.status, VoiceCallStatus.incoming);
    expect(call.peerName, 'Siti Rahmawati');
    expect(call.peerRole, 'Pasien / Keluarga');
    expect(find.text('PANGGILAN MASUK · ORDER AKTIF'), findsNothing);
    expect(find.text('Menuju pasien'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a repeated poll does not ring the same call twice', (
    tester,
  ) async {
    await pumpTripScreen(tester);
    repo.ringFromReporter();
    await tester.pump();
    final notifier = ProviderScope.containerOf(
      tester.element(find.byType(TripCallOverlay)),
    ).read(voiceCallProvider.notifier);

    expect(
      notifier.receiveCall(
        IncomingCall(id: voiceState(tester).callId!, callerName: 'Siti'),
      ),
      isFalse,
    );

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the call bar shows a connected call until hung up', (
    tester,
  ) async {
    await pumpTripScreen(tester, connected: true);

    expect(find.text('Siti Rahmawati'), findsOneWidget);
    expect(find.text('LiveKit · 00:05'), findsOneWidget);
    expect(find.text('Menuju pasien'), findsOneWidget);

    await tester.tap(find.byTooltip('Akhiri panggilan'));
    await tester.pump(const Duration(seconds: 2));

    expect(find.textContaining('LiveKit ·'), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the call bar is hidden while nothing is happening', (
    tester,
  ) async {
    await pumpTripScreen(tester);

    expect(find.byTooltip('Akhiri panggilan'), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });
}
