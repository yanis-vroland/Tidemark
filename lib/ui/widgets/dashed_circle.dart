import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Cercle pointillé : grande bulle absente de la saisie, jour sans entrée de la
/// plage et du bilan (specs 008 et 009).
class DashedCirclePainter extends CustomPainter {
  const DashedCirclePainter({required this.color, this.strokeWidth = 2});

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final center = size.center(Offset.zero);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    // Environ 4 points de tiret et 4 d'espace.
    final dashes = math.max(8, (2 * math.pi * radius / 8).round());
    final sweep = 2 * math.pi / dashes;
    final rect = Rect.fromCircle(center: center, radius: radius);
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(rect, i * sweep, sweep / 2, false, paint);
    }
  }

  @override
  bool shouldRepaint(DashedCirclePainter old) =>
      old.color != color || old.strokeWidth != strokeWidth;
}
