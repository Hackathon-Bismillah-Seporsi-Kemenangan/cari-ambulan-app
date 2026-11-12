import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_providers.dart';
import '../domain/saved_address.dart';

final addressRepositoryProvider = Provider<AddressRepository>(
  (ref) => ApiAddressRepository(ref.watch(apiClientProvider)),
);

/// The patient's saved addresses (`me/addresses`), at most 20.
abstract class AddressRepository {
  /// Newest first.
  Future<List<SavedAddress>> fetch();

  Future<SavedAddress> add(SavedAddress address);

  Future<void> remove(String id);
}

class ApiAddressRepository implements AddressRepository {
  const ApiAddressRepository(this._client);

  final ApiClient _client;

  @override
  Future<List<SavedAddress>> fetch() async {
    final json = await _client.get('me/addresses');
    return [
      for (final item in json?['data'] as List? ?? const [])
        SavedAddress.fromJson(item as Map<String, dynamic>),
    ];
  }

  @override
  Future<SavedAddress> add(SavedAddress address) async {
    final json = await _client.post('me/addresses', address.toJson());
    final data = json?['data'];
    return data is Map<String, dynamic> ? SavedAddress.fromJson(data) : address;
  }

  @override
  Future<void> remove(String id) => _client.delete('me/addresses/$id');
}
