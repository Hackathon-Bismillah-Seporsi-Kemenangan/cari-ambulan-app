import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';

/// One API client for the whole app; the auth layer sets its token.
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());
