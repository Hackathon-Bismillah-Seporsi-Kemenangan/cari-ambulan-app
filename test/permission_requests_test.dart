import 'dart:async';

import 'package:cari_ambulan/core/permissions/permission_requests.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('asks one permission at a time, even after a failed request', () async {
    final events = <String>[];
    final notifications = Completer<void>();

    final first = PermissionRequests.run(() async {
      events.add('notifications asked');
      await notifications.future;
      throw StateError('denied');
    });
    final second = PermissionRequests.run(() async {
      events.add('location asked');
      return true;
    });

    await pumpEventQueue();
    expect(events, ['notifications asked']);

    notifications.complete();
    await expectLater(first, throwsStateError);
    expect(await second, isTrue);
    expect(events, ['notifications asked', 'location asked']);
  });
}
