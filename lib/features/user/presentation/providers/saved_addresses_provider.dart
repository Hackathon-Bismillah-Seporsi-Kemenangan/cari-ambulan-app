import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/address_repository.dart';
import '../../domain/saved_address.dart';

/// The signed-in patient's saved addresses; reloaded for each account.
final savedAddressesProvider = FutureProvider<List<SavedAddress>>((ref) {
  final userId = ref.watch(authProvider.select((auth) => auth.value?.id));
  if (userId == null) return const [];
  return ref.watch(addressRepositoryProvider).fetch();
});
