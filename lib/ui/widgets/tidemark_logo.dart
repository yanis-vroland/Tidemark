import 'package:flutter/material.dart';

import '../theme/tidemark_colors.dart';

/// Logo de Tidemark (spec 007) : un T dont la barre est une vague, et un point
/// au pied de la lettre, sur une tuile `brand`.
///
/// Même géométrie que `tool/generate_brand.py` (constantes `MARK_*`), qui
/// produit les icônes et l'écran de lancement ; un test vérifie qu'elles
/// concordent. Coordonnées dans une boîte de 48 × 48, qui est la tuile.
/// Décoratif : rien n'est annoncé au lecteur d'écran (CA5).
class TidemarkLogo extends StatelessWidget {
  const TidemarkLogo({super.key, required this.size});

  /// Côté de la tuile, en points.
  final double size;

  static const double tileRadius = 11;
  static const double stroke = 3.2;
  static const Offset waveStart = Offset(10, 16);
  static const double waveHalfWidth = 7;
  static const double waveDepth = 3.2;
  static const int waveHalves = 4;
  static const Offset stemTop = Offset(24, 22);
  static const Offset stemBottom = Offset(24, 37);
  static const Offset dotCenter = Offset(31.5, 37);
  static const double dotRadius = 2.6;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: TidemarkLogoPainter(
            tile: colors.brand,
            mark: colors.onBrand,
            accent: colors.brandAccent,
          ),
        ),
      ),
    );
  }
}

/// Peint le logo à la taille de son canevas.
class TidemarkLogoPainter extends CustomPainter {
  const TidemarkLogoPainter({
    required this.tile,
    required this.mark,
    required this.accent,
  });

  final Color tile;
  final Color mark;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 48, size.height / 48);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 48, 48),
        const Radius.circular(TidemarkLogo.tileRadius),
      ),
      Paint()..color = tile,
    );
    final line = Paint()
      ..color = mark
      ..style = PaintingStyle.stroke
      ..strokeWidth = TidemarkLogo.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    // La première demi-onde monte, les suivantes alternent.
    const start = TidemarkLogo.waveStart;
    final wave = Path()..moveTo(start.dx, start.dy);
    for (var k = 0; k < TidemarkLogo.waveHalves; k++) {
      final x = start.dx + k * TidemarkLogo.waveHalfWidth;
      final sign = k.isEven ? -1 : 1;
      wave.quadraticBezierTo(
        x + TidemarkLogo.waveHalfWidth / 2,
        start.dy + sign * TidemarkLogo.waveDepth,
        x + TidemarkLogo.waveHalfWidth,
        start.dy,
      );
    }
    canvas
      ..drawPath(wave, line)
      ..drawLine(TidemarkLogo.stemTop, TidemarkLogo.stemBottom, line)
      ..drawCircle(
        TidemarkLogo.dotCenter,
        TidemarkLogo.dotRadius,
        Paint()..color = accent,
      );
  }

  @override
  bool shouldRepaint(TidemarkLogoPainter oldDelegate) =>
      oldDelegate.tile != tile ||
      oldDelegate.mark != mark ||
      oldDelegate.accent != accent;
}
