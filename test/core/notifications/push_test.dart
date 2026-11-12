import 'dart:async';
import 'dart:convert';

import 'package:cari_ambulan_app/core/network/api_client.dart';
import 'package:cari_ambulan_app/core/notifications/push_registration.dart';
import 'package:cari_ambulan_app/core/notifications/push_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('push messages', () {
    test('a call names the caller', () {
      final alert = pushAlertFor({
        'type': 'incoming_call',
        'call_id': 'c-1',
        'caller_name': 'Budi',
      });
      expect(alert?.title, 'Panggilan masuk');
      expect(alert?.body, startsWith('Budi menelepon Anda'));
      expect(pushKindOf({'type': 'incoming_call'}), PushKind.incomingCall);
    });

    test('a call without a name still reads well', () {
      final alert = pushAlertFor({'type': 'incoming_call', 'caller_name': ''});
      expect(alert?.body, startsWith('Lawan bicara menelepon Anda'));
    });

    test('a new order for the driver', () {
      expect(
        pushAlertFor({'type': 'emergency_offer'})?.title,
        'Order darurat baru',
      );
      expect(pushKindOf({'type': 'emergency_offer'}), PushKind.emergencyOffer);
    });

    test('unknown messages are ignored', () {
      expect(pushAlertFor({'type': 'something_else'}), isNull);
      expect(pushKindOf(const {}), isNull);
    });
  });

  test('push is off without Firebase settings', () async {
    expect(PushConfig.isConfigured, isFalse);
    await PushService.init();
    expect(PushService.isEnabled, isFalse);
    expect(await PushService.token(), isNull);
  });

  group('device token', () {
    late List<String> requests;
    late ApiClient client;

    setUp(() {
      requests = [];
      client = ApiClient(
        baseUrl: 'http://api.test',
        client: MockClient((request) async {
          requests.add('${request.method} ${request.url.path} ${request.body}');
          return http.Response(jsonEncode({'data': {}}), 200);
        }),
      );
    });

    test(
      'registered on sign-in, again on refresh, removed on logout',
      () async {
        final refreshes = StreamController<String>();
        final registration = PushRegistration(
          client,
          token: () async => 'tok-1',
          tokenRefreshes: refreshes.stream,
        );

        await registration.register();
        refreshes.add('tok-2');
        await pumpEventQueue();
        await registration.unregister();
        // Not listening once signed out.
        refreshes.add('tok-3');
        await pumpEventQueue();

        expect(requests, [
          'POST /api/v1/device-tokens '
              '{"token":"tok-1","device_type":"android"}',
          'POST /api/v1/device-tokens '
              '{"token":"tok-2","device_type":"android"}',
          'DELETE /api/v1/device-tokens {"token":"tok-2"}',
        ]);
        await refreshes.close();
      },
    );

    test('nothing is sent when push is off', () async {
      final registration = PushRegistration(
        client,
        token: () async => null,
        tokenRefreshes: const Stream.empty(),
      );
      await registration.register();
      await registration.unregister();
      expect(requests, isEmpty);
    });
  });
}
