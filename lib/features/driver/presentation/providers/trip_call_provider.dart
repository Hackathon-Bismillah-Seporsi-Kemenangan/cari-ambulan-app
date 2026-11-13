import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/driver_models.dart';
import 'driver_home_provider.dart';

/// The reporter's call on the active order, or null. Checked only while a
/// trip screen watches it. It only reports the call: ringing, answering and
/// hanging up all go through the shared call provider, so both apps show the
/// same call screen and keep the same state.
final tripCallProvider = StreamProvider.autoDispose<TripCall?>(
  (ref) => ref.watch(driverRepositoryProvider).watchTripCall(),
);
