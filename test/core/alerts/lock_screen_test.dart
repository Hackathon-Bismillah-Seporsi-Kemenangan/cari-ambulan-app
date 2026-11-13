import 'package:cari_ambulan_app/core/alerts/lock_screen.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('over the lock screen only while something holds it', () async {
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('cari_ambulan/lock_screen'),
          (call) async => calls.add(call.method),
        );

    // An order rings, then the driver answers a call while it still rings.
    await LockScreen.hold('alert');
    await LockScreen.hold('call');
    await LockScreen.hold('call');
    await LockScreen.release('alert');
    expect(calls, ['show']);
    expect(LockScreen.reasons, {'call'});

    // The call ends: hidden again, so a locked phone hides the app.
    await LockScreen.release('call');
    await LockScreen.release('call');
    expect(calls, ['show', 'hide']);
    expect(LockScreen.reasons, isEmpty);
  });
}
