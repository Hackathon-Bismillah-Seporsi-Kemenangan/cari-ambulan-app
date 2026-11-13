import 'dart:io';
import 'dart:typed_data';

/// Reads tiles from a PMTiles v3 file on the phone
/// (https://github.com/protomaps/PMTiles/blob/main/spec/v3/spec.md).
///
/// Tiles are found through the file's directories instead of reading the
/// whole file, so only the requested tile's bytes are loaded.
class PmTilesArchive {
  PmTilesArchive._(this._file, this._start, this._header, this._root);

  final RandomAccessFile _file;

  /// Where the archive begins in [_file]: 0 for a file of its own, more when
  /// it is read from inside another file (e.g. the APK).
  final int _start;
  final _PmTilesHeader _header;
  final List<_Entry> _root;

  /// Leaf directories already read, by their offset in the file.
  final _leaves = <int, List<_Entry>>{};

  /// Reads run one at a time: they share the file's read position.
  Future<void> _lastRead = Future.value();

  int get minZoom => _header.minZoom;
  int get maxZoom => _header.maxZoom;

  static Future<PmTilesArchive> open(String path, {int start = 0}) async {
    final file = await File(path).open();
    try {
      final header = _PmTilesHeader.parse(await _readAt(file, start, 127));
      if (header.tileType != _mvt) {
        throw const FormatException('PMTiles: only vector (MVT) tiles');
      }
      final root = _parseDirectory(
        header.decompress(
          await _readAt(file, start + header.rootOffset, header.rootLength),
        ),
      );
      return PmTilesArchive._(file, start, header, root);
    } catch (_) {
      await file.close();
      rethrow;
    }
  }

  /// The tile's uncompressed MVT bytes, or null when the file has no tile
  /// there (outside its area or zoom range).
  Future<Uint8List?> tile(int z, int x, int y) async {
    if (z < _header.minZoom || z > _header.maxZoom) return null;
    final tileId = zxyToTileId(z, x, y);

    var directory = _root;
    // The spec allows at most 3 levels of leaf directories.
    for (var depth = 0; depth <= 3; depth++) {
      final entry = _find(directory, tileId);
      if (entry == null) return null;
      if (entry.runLength > 0) {
        final bytes = await _read(
          _header.tileDataOffset + entry.offset,
          entry.length,
        );
        return _header.decompressTile(bytes);
      }
      directory = await _leaf(entry);
    }
    return null;
  }

  Future<void> close() => _file.close();

  Future<List<_Entry>> _leaf(_Entry entry) async {
    final cached = _leaves[entry.offset];
    if (cached != null) return cached;
    final leaf = _parseDirectory(
      _header.decompress(
        await _read(_header.leafOffset + entry.offset, entry.length),
      ),
    );
    return _leaves[entry.offset] = leaf;
  }

  Future<Uint8List> _read(int offset, int length) {
    final read = _lastRead.then((_) => _readAt(_file, _start + offset, length));
    _lastRead = read.then((_) {}, onError: (_) {});
    return read;
  }

  static Future<Uint8List> _readAt(
    RandomAccessFile file,
    int offset,
    int length,
  ) async {
    await file.setPosition(offset);
    final bytes = await file.read(length);
    if (bytes.length != length) {
      throw const FormatException('PMTiles: file ends early');
    }
    return bytes;
  }

  /// The entry covering [tileId]: the last one starting at or before it.
  /// Leaf pointers (run length 0) cover every id up to the next entry.
  static _Entry? _find(List<_Entry> entries, int tileId) {
    var low = 0;
    var high = entries.length - 1;
    while (low <= high) {
      final mid = (low + high) >> 1;
      final cmp = entries[mid].tileId - tileId;
      if (cmp < 0) {
        low = mid + 1;
      } else if (cmp > 0) {
        high = mid - 1;
      } else {
        return entries[mid];
      }
    }
    if (high < 0) return null;
    final entry = entries[high];
    if (entry.runLength == 0) return entry;
    return tileId - entry.tileId < entry.runLength ? entry : null;
  }

  static List<_Entry> _parseDirectory(Uint8List bytes) {
    final reader = _VarintReader(bytes);
    final count = reader.next();
    final tileIds = List<int>.filled(count, 0);
    final runLengths = List<int>.filled(count, 0);
    final lengths = List<int>.filled(count, 0);
    final offsets = List<int>.filled(count, 0);

    var lastId = 0;
    for (var i = 0; i < count; i++) {
      lastId += reader.next();
      tileIds[i] = lastId;
    }
    for (var i = 0; i < count; i++) {
      runLengths[i] = reader.next();
    }
    for (var i = 0; i < count; i++) {
      lengths[i] = reader.next();
    }
    for (var i = 0; i < count; i++) {
      final value = reader.next();
      // 0 means "right after the previous entry".
      offsets[i] = value == 0 && i > 0
          ? offsets[i - 1] + lengths[i - 1]
          : value - 1;
    }

    return [
      for (var i = 0; i < count; i++)
        _Entry(tileIds[i], offsets[i], lengths[i], runLengths[i]),
    ];
  }
}

/// Position of a tile on the Hilbert curve PMTiles orders its tiles by,
/// after every tile of the lower zoom levels.
int zxyToTileId(int z, int x, int y) {
  final n = 1 << z;
  if (x < 0 || y < 0 || x >= n || y >= n) {
    throw RangeError('Tile $z/$x/$y is outside zoom $z');
  }
  // 4^0 + 4^1 + ... + 4^(z-1)
  var id = ((1 << (2 * z)) - 1) ~/ 3;
  var tx = x;
  var ty = y;
  for (var s = n >> 1; s > 0; s >>= 1) {
    final rx = (tx & s) > 0 ? 1 : 0;
    final ry = (ty & s) > 0 ? 1 : 0;
    id += s * s * ((3 * rx) ^ ry);
    if (ry == 0) {
      if (rx == 1) {
        tx = s - 1 - tx;
        ty = s - 1 - ty;
      }
      final t = tx;
      tx = ty;
      ty = t;
    }
  }
  return id;
}

const _mvt = 1;

class _PmTilesHeader {
  _PmTilesHeader({
    required this.rootOffset,
    required this.rootLength,
    required this.leafOffset,
    required this.tileDataOffset,
    required this.internalCompression,
    required this.tileCompression,
    required this.tileType,
    required this.minZoom,
    required this.maxZoom,
  });

  factory _PmTilesHeader.parse(Uint8List bytes) {
    if (String.fromCharCodes(bytes, 0, 7) != 'PMTiles' || bytes[7] != 3) {
      throw const FormatException('Not a PMTiles v3 file');
    }
    final data = ByteData.sublistView(bytes);
    int u64(int at) => data.getUint64(at, Endian.little);
    return _PmTilesHeader(
      rootOffset: u64(8),
      rootLength: u64(16),
      leafOffset: u64(40),
      tileDataOffset: u64(56),
      internalCompression: bytes[97],
      tileCompression: bytes[98],
      tileType: bytes[99],
      minZoom: bytes[100],
      maxZoom: bytes[101],
    );
  }

  final int rootOffset;
  final int rootLength;
  final int leafOffset;
  final int tileDataOffset;
  final int internalCompression;
  final int tileCompression;
  final int tileType;
  final int minZoom;
  final int maxZoom;

  Uint8List decompress(Uint8List bytes) =>
      _decompress(bytes, internalCompression);

  Uint8List decompressTile(Uint8List bytes) =>
      _decompress(bytes, tileCompression);

  /// 0 unknown and 1 none: stored as is; 2 gzip.
  static Uint8List _decompress(Uint8List bytes, int compression) =>
      switch (compression) {
        0 || 1 => bytes,
        2 => Uint8List.fromList(gzip.decode(bytes)),
        _ => throw FormatException('PMTiles: compression $compression'),
      };
}

class _Entry {
  const _Entry(this.tileId, this.offset, this.length, this.runLength);

  final int tileId;
  final int offset;
  final int length;

  /// Tiles sharing these bytes from [tileId] on; 0 points to a leaf
  /// directory instead of tile data.
  final int runLength;
}

class _VarintReader {
  _VarintReader(this._bytes);

  final Uint8List _bytes;
  int _at = 0;

  int next() {
    var value = 0;
    var shift = 0;
    while (true) {
      final byte = _bytes[_at++];
      value |= (byte & 0x7f) << shift;
      if (byte < 0x80) return value;
      shift += 7;
    }
  }
}
