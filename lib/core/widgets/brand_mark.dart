import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Shape of the coloured tile behind the mark.
enum BrandTile {
  /// Rounded square, as shown inside the app.
  rounded,

  /// Full-bleed square (iOS and maskable launcher icons).
  square,

  /// No tile: only the mark (Android adaptive foreground).
  none,
}

/// The CariAmbulan logo: a search ring that has found its ambulance (the
/// dot in the ring's opening) around a medical cross. The ring doubles as
/// the "C" of Cari.
///
/// Drawn as vectors so it stays sharp at any size. The launcher icons are
/// rendered from this same painter by `tool/render_brand.dart`.
class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    this.size = 40,
    this.color = AppColors.emergency,
  });

  final double size;

  /// Tile colour: red for patients, blue on driver screens.
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(size),
        painter: BrandMarkPainter(color: color),
      ),
    );
  }
}

class BrandMarkPainter extends CustomPainter {
  const BrandMarkPainter({
    this.color = AppColors.emergency,
    this.tile = BrandTile.rounded,
    this.markScale = 1,
    this.markColor = Colors.white,
  });

  final Color color;
  final BrandTile tile;

  /// Shrinks the mark inside the tile (launcher safe zones).
  final double markScale;
  final Color markColor;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final rect = Offset.zero & Size.square(s);

    if (tile != BrandTile.none) {
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(color, Colors.white, 0.14)!,
            color,
            Color.lerp(color, Colors.black, 0.16)!,
          ],
          stops: const [0, 0.45, 1],
        ).createShader(rect);
      if (tile == BrandTile.square) {
        canvas.drawRect(rect, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(s * 0.24)),
          paint,
        );
      }
    }

    canvas.save();
    canvas.translate(s / 2, s / 2);
    canvas.scale(markScale);

    final mark = Paint()
      ..color = markColor
      ..isAntiAlias = true;

    // Search ring, open towards the top right.
    const gapCenter = -math.pi / 4;
    const gapHalf = 34 * math.pi / 180;
    final radius = s * 0.285;
    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: radius),
      gapCenter + gapHalf,
      2 * math.pi - 2 * gapHalf,
      false,
      Paint()
        ..color = markColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.1
        ..strokeCap = StrokeCap.round,
    );

    // The ambulance that was found.
    canvas.drawCircle(
      Offset(math.cos(gapCenter), math.sin(gapCenter)) * radius,
      s * 0.058,
      mark,
    );

    // Medical cross.
    final arm = s * 0.25;
    final thick = s * 0.088;
    final corner = Radius.circular(s * 0.022);
    for (final r in [
      Rect.fromCenter(center: Offset.zero, width: arm, height: thick),
      Rect.fromCenter(center: Offset.zero, width: thick, height: arm),
    ]) {
      canvas.drawRRect(RRect.fromRectAndRadius(r, corner), mark);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(BrandMarkPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.tile != tile ||
      oldDelegate.markScale != markScale ||
      oldDelegate.markColor != markColor;
}
