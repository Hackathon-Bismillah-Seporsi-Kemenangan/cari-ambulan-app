import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/medical_repository.dart';
import '../../domain/medical_profile.dart';

/// The signed-in user's Medical ID; reloaded for each account.
final medicalProfileProvider = FutureProvider<MedicalProfile>((ref) {
  ref.watch(authProvider.select((auth) => auth.value?.id));
  return ref.watch(medicalRepositoryProvider).fetch();
});

/// The Medical ID shown was edited offline and hasn't reached the server.
final medicalSyncPendingProvider = FutureProvider<bool>((ref) async {
  await ref.watch(medicalProfileProvider.future);
  return ref.read(medicalRepositoryProvider).hasPendingSync();
});
