import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart';
import 'package:path_provider/path_provider.dart';

import '../logging/app_log.dart';

/// Serves the map style's files (style, tile index, sprites) from the
/// phone, so the map draws without first making several requests in a
/// row. Each file is refreshed in the background for the next start.
///
/// Copies older than [_maxAge] are fetched first instead, since the tile
/// index names this week's tile set; they are still used when offline.
class StyleCacheClient extends BaseClient {
  StyleCacheClient._(this._folder);

  static const _maxAge = Duration(days: 3);

  final Directory _folder;
  final _network = Client();

  static Future<StyleCacheClient> open() async {
    final base = await getApplicationSupportDirectory();
    final folder = Directory('${base.path}/map_style');
    await folder.create(recursive: true);
    return StyleCacheClient._(folder);
  }

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    if (request.method != 'GET') return _network.send(request);
    final file = File(
      '${_folder.path}/${base64Url.encode(utf8.encode('${request.url}'))}',
    );
    final saved = await _read(file);
    if (saved != null) {
      final (bytes, age) = saved;
      if (age < _maxAge) {
        unawaited(
          _download(request.url, file).then<void>(
            (_) {},
            onError: (Object e) =>
                AppLog.warn('Map', 'Style refresh failed', e),
          ),
        );
        return _response(bytes, request);
      }
    }
    try {
      return _response(await _download(request.url, file), request);
    } catch (e) {
      // Offline: an old copy still draws the map.
      if (saved != null) return _response(saved.$1, request);
      rethrow;
    }
  }

  Future<(List<int>, Duration)?> _read(File file) async {
    try {
      final modified = await file.lastModified();
      return (await file.readAsBytes(), DateTime.now().difference(modified));
    } on FileSystemException {
      return null;
    }
  }

  /// Fetches [url] and saves it; throws unless the server answers 200.
  Future<List<int>> _download(Uri url, File file) async {
    final response = await _network.get(url);
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode}', uri: url);
    }
    // Written aside and renamed, so a crash never leaves half a file.
    final partial = File('${file.path}.part');
    await partial.writeAsBytes(response.bodyBytes, flush: true);
    await partial.rename(file.path);
    return response.bodyBytes;
  }

  StreamedResponse _response(List<int> bytes, BaseRequest request) =>
      StreamedResponse(
        Stream.value(bytes),
        200,
        contentLength: bytes.length,
        request: request,
        // The style is UTF-8; without a charset it would be read as Latin-1.
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
}
