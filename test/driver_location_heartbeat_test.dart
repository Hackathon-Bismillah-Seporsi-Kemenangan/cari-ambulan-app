import 'dart:async';

import 'package:cari_ambulan/features/auth/presentation/providers/auth_provider.dart';
import 'package:cari_ambulan/features/driver/data/mock_driver_repository.dart';
import 'package:cari_ambulan/features/driver/domain/driver_models.dart';
import 'package:cari_ambulan/features/driver/presentation/providers/driver_home_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'test_app.dart';

/// Online, parked: the GPS reports once and then stays quiet.
class _ParkedDriverRepository extends MockDriverRepository {
  final reported = <LatLng>[];
  final _gps = StreamController<LatLng>();

  @override
  Future<DriverAvailability> fetchAvailability() async =>
      DriverAvailability.online;

  @override
  Stream<LatLng> watchLocation() {
    _gps.add(const LatLng(-6.2088, 106.8222));
    return _gps.stream;
  }

  @override
  Future<void> reportLocation(LatLng location) async => reported.add(location);
}

void main() {
  testWidgets('a parked online driver keeps its position fresh', (
    tester,
  ) async {
    final repo = _ParkedDriverRepository();
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(() => FakeAuth(testDriver)),
        driverRepositoryProvider.overrideWithValue(repo),
      ],
    );
    container.listen(driverHomeProvider, (_, _) {});

    await tester.pump(const Duration(seconds: 2));
    expect(container.read(driverHomeProvider).value?.isOnline, isTrue);
    expect(repo.reported, hasLength(1));

    // No GPS movement for 3 minutes: one re-send per minute.
    await tester.pump(const Duration(minutes: 3));
    expect(repo.reported, hasLength(4));

    // Stops the heartbeat before the test checks for pending timers.
    container.dispose();
  });
}
