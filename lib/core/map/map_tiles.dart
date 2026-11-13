import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vtr;

import '../logging/app_log.dart';
import 'pmtiles_archive.dart';

/// Base map layer for every map in the app, fully offline: East Java vector
/// tiles from the bundled `jatim.pmtiles`, drawn with the OpenFreeMap
/// "liberty" style and icons (also bundled). Outside East Java the map is
/// blank.
class MapTiles extends StatefulWidget {
  const MapTiles({super.key});

  static const attribution = '© OpenMapTiles · © OpenStreetMap';

  /// Map canvas color while tiles load, and outside East Java.
  static const background = Color(0xFFF2F1ED);

  /// The area `jatim.pmtiles` covers (its header's bounds).
  static final coverage = LatLngBounds(
    const LatLng(-8.85, 110.88),
    const LatLng(-5.04, 116.27),
  );

  /// Below this the tiles are empty: the file has no data for zoom 0-7.
  static const minZoom = 8.0;

  /// Keeps every map's center over East Java, so it can't be dragged off
  /// onto a blank area.
  static final cameraConstraint = CameraConstraint.containCenter(
    bounds: coverage,
  );

  static bool covers(LatLng point) => coverage.contains(point);

  /// The nearest point inside the coverage. A map must start there:
  /// [cameraConstraint] rejects a starting center outside it.
  static LatLng clamp(LatLng point) => LatLng(
    point.latitude.clamp(coverage.south, coverage.north),
    point.longitude.clamp(coverage.west, coverage.east),
  );

  static const _tilesAsset = 'assets/map/jatim.pmtiles';
  static const _styleAsset = 'assets/map/liberty.json';
  static const _spritesAsset = 'assets/map/sprites@2x';

  /// Bump when `jatim.pmtiles` is replaced, so phones that copy the file
  /// (not Android, which reads it in place) take the new one.
  static const _tilesVersion = 'jatim-2026-11-09-no-buildings';

  // Only flat layers: 3D building extrusions and hillshade rasters are the
  // most expensive to render and add little on a phone.
  static const _layerTypes = {
    vtr.ThemeLayerType.background,
    vtr.ThemeLayerType.fill,
    vtr.ThemeLayerType.line,
    vtr.ThemeLayerType.symbol,
  };

  static Future<Style>? _style;

  /// Prepares the map once per app run. Call early (e.g. in `main`) so the
  /// map appears without waiting. Off Android, the first start also copies
  /// the tiles out of the app (~80 MB, a few seconds).
  static Future<Style> preload() => _style ??= _load().catchError((Object e) {
    AppLog.warn('Map', 'Offline map unavailable', e);
    // Forget failures so the next build retries.
    _style = null;
    throw e;
  });

  static Future<Style> _load() async {
    final (archive, styleJson, spritesJson) = await (
      _openTiles(),
      rootBundle.loadString(_styleAsset),
      rootBundle.loadString('$_spritesAsset.json'),
    ).wait;

    final style = jsonDecode(styleJson) as Map<String, dynamic>;
    return Style(
      name: style['name'] as String?,
      theme: vtr.ThemeReader().read(style).copyWith(types: _layerTypes),
      // The style's only vector source; its hillshade raster is unused.
      providers: TileProviders({'openmaptiles': _PmTilesProvider(archive)}),
      sprites: SpriteStyle(
        atlasProvider: () async =>
            (await rootBundle.load('$_spritesAsset.png')).buffer.asUint8List(),
        index: vtr.SpriteIndexReader().read(jsonDecode(spritesJson)),
      ),
    );
  }

  static const _assets = MethodChannel('cari_ambulan/assets');

  /// Android reads the tiles in place inside the installed app (stored
  /// uncompressed for that). Elsewhere, or if that fails, they are copied
  /// out of the app once.
  static Future<PmTilesArchive> _openTiles() async {
    final folder = Directory(
      '${(await getApplicationSupportDirectory()).path}/map',
    );

    if (Platform.isAndroid) {
      try {
        final location = await _assets.invokeMapMethod<String, Object>(
          'location',
          _tilesAsset,
        );
        if (location != null) {
          final archive = await PmTilesArchive.open(
            location['path']! as String,
            start: location['offset']! as int,
          );
          // A copy left by an older version of the app is no longer needed.
          if (await folder.exists()) await folder.delete(recursive: true);
          return archive;
        }
      } catch (e) {
        AppLog.warn('Map', 'Reading the map inside the app failed', e);
      }
    }

    return PmTilesArchive.open(await _copyTiles(folder));
  }

  static Future<String> _copyTiles(Directory folder) async {
    final file = File('${folder.path}/jatim.pmtiles');
    final copied = File('${folder.path}/jatim.version');

    final current =
        await file.exists() &&
        await copied.exists() &&
        await copied.readAsString() == _tilesVersion;
    if (!current) {
      AppLog.info('Map', 'Copying offline map to the phone');
      await folder.create(recursive: true);
      final bytes = await rootBundle.load(_tilesAsset);
      // Write under another name first: an interrupted copy must not look
      // complete on the next start.
      final partial = File('${file.path}.part');
      await partial.writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        flush: true,
      );
      await partial.rename(file.path);
      await copied.writeAsString(_tilesVersion, flush: true);
    }
    return file.path;
  }

  @override
  State<MapTiles> createState() => _MapTilesState();
}

class _MapTilesState extends State<MapTiles> {
  late Future<Style> _style = MapTiles.preload();
  Timer? _retry;

  @override
  void dispose() {
    _retry?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Style>(
      future: _style,
      builder: (context, snapshot) {
        final style = snapshot.data;
        if (snapshot.hasError) {
          // Don't stay blank: try again shortly.
          _retry ??= Timer(const Duration(seconds: 2), () {
            if (!mounted) return;
            setState(() {
              _retry = null;
              _style = MapTiles.preload();
            });
          });
        }
        if (style == null) return const SizedBox.shrink();
        return VectorTileLayer(
          theme: style.theme,
          sprites: style.sprites,
          tileProviders: style.providers,
          layerMode: VectorTileLayerMode.raster,
        );
      },
    );
  }
}

/// Serves tiles from the bundled PMTiles file. Where the file has none
/// (outside East Java) it serves an empty tile, so the map stays blank there
/// instead of retrying.
class _PmTilesProvider extends VectorTileProvider {
  _PmTilesProvider(this._archive);

  final PmTilesArchive _archive;

  static final _empty = Uint8List(0);

  @override
  int get minimumZoom => _archive.minZoom;

  @override
  int get maximumZoom => _archive.maxZoom;

  @override
  TileOffset get tileOffset => TileOffset.DEFAULT;

  @override
  Future<Uint8List> provide(TileIdentity tile) async =>
      await _archive.tile(tile.z, tile.x, tile.y) ?? _empty;
}

/// Tells the user the offline map stops at East Java when their position is
/// outside it (the map there is blank). Put it in a map's children.
class MapCoverageNote extends StatelessWidget {
  const MapCoverageNote({super.key, required this.location});

  final LatLng location;

  @override
  Widget build(BuildContext context) {
    if (MapTiles.covers(location)) return const SizedBox.shrink();
    return IgnorePointer(
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'Peta offline hanya mencakup Jawa Timur. '
            'Lokasi Anda di luar area peta.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
