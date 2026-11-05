import 'package:flutter/material.dart';

import '../theme/tidemark_colors.dart';

/// Période de montée d'une bulle d'air de la saisie : 8 s (spec 008,
/// « Mouvement », qui prime sur les 9 s de la maquette `Saisie`).
const entryAirPeriod = Duration(seconds: 8);

/// Bulles d'air de la saisie (maquette `Saisie`) : abscisse en part de la largeur
/// de la maquette (393), diamètre, et décalage dans le cycle (retards de la maquette, sur 9 s).
const _entryAirBubbles = [
  (40 / 393, 14.0, 0 / 9),
  (96 / 393, 8.0, 2.5 / 9),
  (300 / 393, 18.0, 1.2 / 9),
  (350 / 393, 10.0, 4 / 9),
  (190 / 393, 12.0, 5.5 / 9),
  (250 / 393, 7.0, 3.2 / 9),
];

/// Hauteur de montée d'une bulle, en points (maquette `Saisie`).
const _rise = 520.0;

/// Bulles d'air qui montent depuis le bas de l'écran (spec 008, « Mouvement »),
/// au rythme de [animation] (de 0 à 1 sur un cycle). Purement décoratives :
/// jamais annoncées, jamais touchables. À placer sous le contenu, et seulement
/// quand une animation d'ambiance tourne (`syncAmbientController`).
class AirBubbles extends StatelessWidget {
  const AirBubbles({super.key, required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: CustomPaint(
        size: Size.infinite,
        painter: _AirBubblesPainter(
          animation: animation,
          ring: context.colors.bubbleShine.withValues(
            alpha: Theme.of(context).brightness == Brightness.dark ? 0.2 : 0.8,
          ),
        ),
      ),
    ),
  );
}

class _AirBubblesPainter extends CustomPainter {
  _AirBubblesPainter({required this.animation, required this.ring})
    : super(repaint: animation);

  final Animation<double> animation;
  final Color ring;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final (x, d, offset) in _entryAirBubbles) {
      final t = (animation.value + offset) % 1;
      // Départ juste sous le bas de l'écran, comme la maquette.
      final y = size.height + 20 - d / 2 - t * _rise;
      final alpha = t < 0.15 ? t / 0.15 : 1 - (t - 0.15) / 0.85;
      paint.color = ring.withValues(alpha: ring.a * alpha);
      canvas.drawCircle(Offset(x * size.width, y), d / 2, paint);
    }
  }

  @override
  bool shouldRepaint(_AirBubblesPainter old) =>
      old.animation != animation || old.ring != ring;
}
