/// Runs runtime-permission requests one at a time.
///
/// Android shows a single permission dialog at a time and drops a request
/// made while another is open; geolocator then never completes its future,
/// which left a new driver's home loading forever (location asked together
/// with notifications).
abstract final class PermissionRequests {
  static Future<void> _last = Future.value();

  static Future<T> run<T>(Future<T> Function() request) {
    final result = _last.then((_) => request());
    _last = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }
}
