import 'dart:io';
import 'dart:math';

import 'package:cari_ambulan/core/map/map_tiles.dart';
import 'package:cari_ambulan/core/map/pmtiles_archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

/// The XYZ tile containing a point, as map apps number them.
(int, int) tileAt(double lat, double lon, int z) {
  final n = 1 << z;
  final x = ((lon + 180) / 360 * n).floor();
  final latRad = lat * pi / 180;
  final y = ((1 - log(tan(latRad) + 1 / cos(latRad)) / pi) / 2 * n).floor();
  return (x, y);
}

void main() {
  test('numbers tiles along the Hilbert curve like the PMTiles spec', () {
    expect(zxyToTileId(0, 0, 0), 0);
    expect(zxyToTileId(1, 0, 0), 1);
    expect(zxyToTileId(1, 0, 1), 2);
    expect(zxyToTileId(1, 1, 1), 3);
    expect(zxyToTileId(1, 1, 0), 4);
    expect(zxyToTileId(2, 0, 0), 5);
  });

  group('bundled East Java map', () {
    late PmTilesArchive archive;

    setUpAll(() async {
      archive = await PmTilesArchive.open('assets/map/jatim.pmtiles');
    });
    tearDownAll(() => archive.close());

    test('has street-level tiles for Jember', () async {
      expect(archive.maxZoom, 14);
      for (final z in [10, 12, 14]) {
        final (x, y) = tileAt(-8.1724, 113.7008, z);
        final tile = await archive.tile(z, x, y);
        expect(tile, isNotNull, reason: 'zoom $z');
        // Uncompressed MVT: a protobuf starting with a layer (field 3).
        expect(tile!.first, 0x1a, reason: 'zoom $z');
        expect(String.fromCharCodes(tile), contains('transportation'));
      }
    });

    test('has no buildings, only what an ambulance app needs', () async {
      final (x, y) = tileAt(-7.2575, 112.7521, 14); // central Surabaya
      final tile = String.fromCharCodes((await archive.tile(14, x, y))!);
      expect(tile, isNot(contains('building')));
      expect(tile, contains('transportation'));
    });

    test('has no tiles outside East Java', () async {
      final (x, y) = tileAt(-6.2088, 106.8456, 14); // Jakarta
      expect(await archive.tile(14, x, y), isNull);
    });

    test('serves many tiles read at the same time', () async {
      final (x, y) = tileAt(-7.2575, 112.7521, 13); // Surabaya
      final tiles = await Future.wait([
        for (var dx = -2; dx <= 2; dx++)
          for (var dy = -2; dy <= 2; dy++) archive.tile(13, x + dx, y + dy),
      ]);
      expect(tiles.whereType<Object>(), hasLength(25));
    });

    test('reads the map from inside a bigger file, as from the APK', () async {
      final dir = await Directory.systemTemp.createTemp('pmtiles');
      final bundle = File('${dir.path}/app.apk');
      await bundle.writeAsBytes([
        ...List.filled(4096, 7),
        ...await File('assets/map/jatim.pmtiles').readAsBytes(),
      ]);
      final inside = await PmTilesArchive.open(bundle.path, start: 4096);
      addTearDown(() async {
        await inside.close();
        await dir.delete(recursive: true);
      });

      final (x, y) = tileAt(-8.1724, 113.7008, 14);
      expect(await inside.tile(14, x, y), await archive.tile(14, x, y));
    });
  });

  test('map coverage is East Java', () {
    expect(MapTiles.covers(const LatLng(-8.1724, 113.7008)), isTrue); // Jember
    expect(
      MapTiles.covers(const LatLng(-7.2575, 112.7521)),
      isTrue,
    ); // Surabaya
    expect(
      MapTiles.covers(const LatLng(-6.2088, 106.8456)),
      isFalse,
    ); // Jakarta
  });
}
