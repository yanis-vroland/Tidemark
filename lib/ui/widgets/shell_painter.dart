import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../theme/tidemark_colors.dart';

/// Coquillage en éventail de la maquette (spec 009 et 010), dessiné dans une
/// boîte de 100 × 90 mise à l'échelle sans déformation et centrée dans la taille
/// donnée. Avec [colors], il porte ses stries et deux éclats ; sans, c'est une
/// silhouette pleine. Décoratif : à placer sous un `ExcludeSemantics` ou dans un
/// groupe qui porte sa propre annonce.
class ShellPainter extends CustomPainter {
  const ShellPainter({required this.color, this.colors});

  final Color color;
  final TidemarkColors? colors;

  /// Boîte du dessin de la maquette.
  static const designSize = Size(100, 90);

  @override
  void paint(Canvas canvas, Size size) {
    final f = math.min(
      size.width / designSize.width,
      size.height / designSize.height,
    );
    canvas.save();
    canvas.translate(
      (size.width - designSize.width * f) / 2,
      (size.height - designSize.height * f) / 2,
    );
    canvas.scale(f);
    final shell = Path()
      ..moveTo(14, 30)
      ..quadraticBezierTo(17, 14, 28, 12)
      ..quadraticBezierTo(34, 6, 42, 9)
      ..quadraticBezierTo(50, 4, 58, 9)
      ..quadraticBezierTo(66, 6, 72, 12)
      ..quadraticBezierTo(83, 14, 86, 30)
      ..lineTo(50, 84)
      ..close();
    canvas.drawPath(shell, Paint()..color = color);
    final colors = this.colors;
    if (colors != null) {
      final ridge = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..color = colors.bubbleShine.withValues(alpha: 0.7);
      for (final top in const [
        Offset(24, 20),
        Offset(36, 12),
        Offset(50, 9),
        Offset(64, 12),
        Offset(76, 20),
      ]) {
        canvas.drawLine(const Offset(50, 82), top, ridge);
      }
      final spark = Paint()..color = colors.moon;
      canvas.drawPath(_spark(const Offset(93, 11), 5), spark);
      canvas.drawPath(_spark(const Offset(6, 47.4), 3.4), spark);
    }
    canvas.restore();
  }

  /// Éclat à quatre branches centré sur [c], de demi-taille [r].
  static Path _spark(Offset c, double r) {
    final q = r * 0.3;
    return Path()
      ..moveTo(c.dx, c.dy - r)
      ..lineTo(c.dx + q, c.dy - q)
      ..lineTo(c.dx + r, c.dy)
      ..lineTo(c.dx + q, c.dy + q)
      ..lineTo(c.dx, c.dy + r)
      ..lineTo(c.dx - q, c.dy + q)
      ..lineTo(c.dx - r, c.dy)
      ..lineTo(c.dx - q, c.dy - q)
      ..close();
  }

  @override
  bool shouldRepaint(ShellPainter old) =>
      old.color != color || old.colors != colors;
}
