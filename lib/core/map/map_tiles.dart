import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' show runWithClient;
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vtr;

import 'style_cache.dart';

/// Base map layer for every map in the app: OpenFreeMap vector tiles (free,
/// no API key) for a clean, Google Maps-like look. Falls back to plain OSM
/// raster tiles if the style fails to load.
class MapTiles extends StatelessWidget {
  const MapTiles({super.key});

  static const attribution = '© OpenFreeMap · © OpenStreetMap';

  /// Map canvas color while tiles load.
  static const background = Color(0xFFF2F1ED);

  static const _styleUri = 'https://tiles.openfreemap.org/styles/liberty';

  // Only flat layers: 3D building extrusions and hillshade rasters are the
  // most expensive to render and add little on a phone.
  static const _layerTypes = {
    vtr.ThemeLayerType.background,
    vtr.ThemeLayerType.fill,
    vtr.ThemeLayerType.line,
    vtr.ThemeLayerType.symbol,
  };

  static Future<Style>? _style;

  /// Reads the map style once per app run, from the phone after the first
  /// start ([StyleCacheClient]). Call early (e.g. in `main`) so the map
  /// appears without waiting on the network.
  static Future<Style> preload() => _style ??= _read().then(
    (style) => Style(
      name: style.name,
      theme: style.theme.copyWith(types: _layerTypes),
      providers: style.providers,
      sprites: style.sprites,
      center: style.center,
      zoom: style.zoom,
    ),
    onError: (Object e) {
      // Forget failures so the next build retries.
      _style = null;
      throw e;
    },
  );

  static Future<Style> _read() async {
    final client = await StyleCacheClient.open();
    return runWithClient(StyleReader(uri: _styleUri).read, () => client);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Style>(
      future: preload(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final style = snapshot.data!;
          return VectorTileLayer(
            theme: style.theme,
            sprites: style.sprites,
            tileProviders: style.providers,
            layerMode: VectorTileLayerMode.raster,
          );
        }
        if (snapshot.hasError) return const _OsmFallback();
        return const SizedBox.shrink();
      },
    );
  }
}

/// Raster OSM tiles, used only when the vector style can't be loaded.
class _OsmFallback extends StatelessWidget {
  const _OsmFallback();

  @override
  Widget build(BuildContext context) {
    return TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      // OSM blocks `com.example.*` user agents, which is this app's default ID.
      userAgentPackageName: 'id.cariambulan.app',
    );
  }
}
