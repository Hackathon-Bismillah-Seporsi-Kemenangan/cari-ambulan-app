// Renders the logo (and previews of the onboarding illustrations) to PNG
// from the same painters the app uses:
//
//   flutter test tool/render_brand.dart     → build/brand/*.png
//   python tool/make_icons.py               → launcher icons for every platform
//
// It runs under `flutter test` only because that gives a headless renderer.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cari_ambulan/core/theme/app_colors.dart';
import 'package:cari_ambulan/core/widgets/brand_mark.dart';
import 'package:cari_ambulan/features/onboarding/presentation/widgets/onboarding_illustrations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _out = 'build/brand';

Future<void> _loadFonts() async {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot == null) return;
  final fonts = '$flutterRoot/bin/cache/artifacts/material_fonts';
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final name in files) {
      final file = File('$fonts/$name');
      if (!file.existsSync()) continue;
      final bytes = file.readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }

  await load('MaterialIcons', ['MaterialIcons-Regular.otf']);
  await load('Roboto', [
    'Roboto-Regular.ttf',
    'Roboto-Bold.ttf',
    'Roboto-Black.ttf',
  ]);
}

Future<void> _render(
  WidgetTester tester,
  String name,
  Size size,
  Widget child, {
  double pixelRatio = 1,
}) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: DefaultTextStyle(
        style: const TextStyle(fontFamily: 'Roboto'),
        child: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: key,
            child: SizedBox.fromSize(size: size, child: child),
          ),
        ),
      ),
    ),
  );
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$_out/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(data!.buffer.asUint8List());
  });
}

Widget _mark(BrandTile tile, {double scale = 1, Color? color}) => CustomPaint(
  painter: BrandMarkPainter(
    tile: tile,
    markScale: scale,
    color: color ?? AppColors.emergency,
  ),
);

Widget _slide(Color circle, Widget illustration) => ColoredBox(
  color: Colors.white,
  child: Padding(
    padding: const EdgeInsets.all(10),
    child: DecoratedBox(
      decoration: BoxDecoration(color: circle, shape: BoxShape.circle),
      child: ClipOval(child: illustration),
    ),
  ),
);

void main() {
  testWidgets('render brand assets', (tester) async {
    await _loadFonts();
    tester.view.physicalSize = const Size(1400, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    const full = Size.square(1024);
    await _render(tester, 'icon_square', full, _mark(BrandTile.square));
    await _render(tester, 'icon_rounded', full, _mark(BrandTile.rounded));
    await _render(
      tester,
      'icon_maskable',
      full,
      _mark(BrandTile.square, scale: 0.8),
    );
    await _render(
      tester,
      'icon_foreground',
      full,
      _mark(BrandTile.none, scale: 0.7),
    );

    // Previews, to look at before shipping a change.
    await _render(
      tester,
      'preview_logo',
      const Size(560, 150),
      ColoredBox(
        color: Colors.white,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (final s in [120.0, 72.0, 48.0, 28.0]) BrandMark(size: s),
            for (final s in [72.0, 28.0])
              BrandMark(size: s, color: const Color(0xFF1565C0)),
          ],
        ),
      ),
      pixelRatio: 2,
    );
    const slide = Size.square(320);
    final slides = <String, Widget>{
      'preview_patient_1': _slide(
        const Color(0xFFFDECEC),
        const SosIllustration(),
      ),
      'preview_patient_2': _slide(
        const Color(0xFFE3F0FC),
        const NearestAmbulanceIllustration(),
      ),
      'preview_patient_3': _slide(
        const Color(0xFFE6F4EA),
        const TrackingIllustration(),
      ),
      'preview_driver_1': _slide(
        const Color(0xFFE6F1FC),
        const OrderAlertIllustration(),
      ),
      'preview_driver_2': _slide(
        const Color(0xFFE6F1FC),
        const HospitalRouteIllustration(),
      ),
    };
    for (final entry in slides.entries) {
      await _render(tester, entry.key, slide, entry.value, pixelRatio: 2);
    }
  });
}
