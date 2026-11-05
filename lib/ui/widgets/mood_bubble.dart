import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../motion/ambient_motion.dart';
import '../theme/tidemark_colors.dart';
import '../theme/tidemark_tokens.dart';

/// Visage d'une bulle, de l'humeur 1 à 5 (spec 008, « La bulle de marée »).
enum BubbleFace { tearful, low, flat, smile, beaming }

/// Bulle de marée : l'humeur [mood] dessinée comme une bulle dont le niveau d'eau
/// et le visage montent avec elle (spec 008). Purement visuelle : le libellé de
/// l'humeur est toujours donné à côté ou dans la sémantique du parent (CA6).
///
/// Sous [AmbientMotion] activé, l'eau ondule et la bulle flotte ; sinon, elle est
/// dessinée au repos.
class MoodBubble extends StatefulWidget {
  const MoodBubble({
    super.key,
    required this.mood,
    required this.size,
    this.ring = false,
  }) : assert(mood >= 1 && mood <= 5, 'mood doit valoir de 1 à 5');

  final int mood;

  /// Diamètre, en points logiques.
  final double size;

  /// Anneau `tide` autour de la bulle : bulle choisie du sélecteur.
  final bool ring;

  /// Hauteur de l'eau, en part du diamètre, depuis le bas.
  static double waterLevel(int mood) =>
      const [0.17, 0.32, 0.48, 0.64, 0.79][mood - 1];

  static BubbleFace faceFor(int mood) => BubbleFace.values[mood - 1];

  @override
  State<MoodBubble> createState() => _MoodBubbleState();
}

/// Période de la houle et du flottement (spec 008, « Mouvement »).
const _swellPeriod = Duration(milliseconds: 3200);
const _bobPeriod = Duration(milliseconds: 3400);

class _MoodBubbleState extends State<MoodBubble> with TickerProviderStateMixin {
  AnimationController? _swell;
  AnimationController? _bob;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _swell = syncAmbientController(
      context: context,
      vsync: this,
      current: _swell,
      period: _swellPeriod,
    );
    _bob = syncAmbientController(
      context: context,
      vsync: this,
      current: _bob,
      period: _bobPeriod,
      reverse: true,
    );
  }

  @override
  void dispose() {
    _swell?.dispose();
    _bob?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final swell = _swell;
    final bob = _bob;
    Widget bubble = CustomPaint(
      size: Size.square(widget.size),
      painter: _BubblePainter(
        mood: widget.mood,
        colors: colors,
        ring: widget.ring,
        phase: swell ?? const AlwaysStoppedAnimation(0),
      ),
    );
    if (bob != null) {
      bubble = AnimatedBuilder(
        animation: bob,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, -3 * Curves.easeInOut.transform(bob.value)),
          child: child,
        ),
        child: bubble,
      );
    }
    return ExcludeSemantics(
      child: SizedBox.square(dimension: widget.size, child: bubble),
    );
  }
}

class _BubblePainter extends CustomPainter {
  _BubblePainter({
    required this.mood,
    required this.colors,
    required this.ring,
    required this.phase,
  }) : super(repaint: phase);

  final int mood;
  final TidemarkColors colors;
  final bool ring;
  final Animation<double> phase;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final center = Offset(s / 2, s / 2);
    final circle = Path()
      ..addOval(Rect.fromCircle(center: center, radius: s / 2));

    if (ring) {
      canvas.drawCircle(
        center,
        s / 2 + TidemarkSize.ringWidth * 1.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = TidemarkSize.ringWidth
          ..color = colors.tide,
      );
    }

    canvas.save();
    canvas.clipPath(circle);
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = colors.moodSoftColor(mood),
    );

    // Eau : la crête touche le niveau, les creux descendent en dessous ; la
    // houle décale la vague d'une période par cycle.
    final top = s * (1 - MoodBubble.waterLevel(mood));
    final amplitude = s * 0.018;
    final period = s / 2;
    final shift = phase.value * period;
    final crest = Path();
    for (var x = -period; x <= s + period; x += s / 48) {
      final y =
          top + amplitude * (1 - math.cos(2 * math.pi * (x + shift) / period));
      if (x == -period) {
        crest.moveTo(x, y);
      } else {
        crest.lineTo(x, y);
      }
    }
    final water = Path.from(crest)
      ..lineTo(s + period, s)
      ..lineTo(-period, s)
      ..close();
    canvas.drawPath(water, Paint()..color = colors.moodColor(mood));
    canvas.drawPath(
      crest,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.022
        ..strokeCap = StrokeCap.round
        ..color = colors.bubbleShine.withValues(alpha: 0.7),
    );

    // Reflet.
    canvas.save();
    canvas.translate(s * 0.29, s * 0.23);
    canvas.rotate(-32 * math.pi / 180);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: s * 0.2, height: s * 0.11),
      Paint()..color = colors.bubbleShine,
    );
    canvas.restore();

    _paintFace(canvas, s / 48);
    canvas.restore();
  }

  /// Visage dessiné dans une boîte de 48 × 48, mise à l'échelle par [f].
  void _paintFace(Canvas canvas, double f) {
    final ink = colors.onMood;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2 * f
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = ink;
    final fill = Paint()..color = ink;
    Offset p(double x, double y) => Offset(x * f, y * f);
    Path curve(
      double x1,
      double y1,
      double cx,
      double cy,
      double x2,
      double y2,
    ) => Path()
      ..moveTo(x1 * f, y1 * f)
      ..quadraticBezierTo(cx * f, cy * f, x2 * f, y2 * f);
    void cheeks(double y) {
      final cheek = Paint()..color = colors.bubbleCheek;
      canvas.drawCircle(p(13.5, y), 2.6 * f, cheek);
      canvas.drawCircle(p(34.5, y), 2.6 * f, cheek);
    }

    final face = MoodBubble.faceFor(mood);
    if (face != BubbleFace.beaming) {
      canvas.drawCircle(p(18, 21), 2.3 * f, fill);
      canvas.drawCircle(p(30, 21), 2.3 * f, fill);
    }
    switch (face) {
      case BubbleFace.tearful:
        canvas.drawLine(p(14.5, 16.5), p(20, 18.2), stroke);
        canvas.drawLine(p(33.5, 16.5), p(28, 18.2), stroke);
        canvas.drawPath(curve(19, 31.5, 24, 27, 29, 31.5), stroke);
        final tear = Path()
          ..moveTo(31.5 * f, 24 * f)
          ..quadraticBezierTo(34 * f, 27.5 * f, 31.5 * f, 29 * f)
          ..quadraticBezierTo(29 * f, 27.5 * f, 31.5 * f, 24 * f)
          ..close();
        canvas.drawPath(tear, Paint()..color = colors.bubbleTear);
      case BubbleFace.low:
        canvas.drawPath(curve(19.5, 30.5, 24, 28.3, 28.5, 30.5), stroke);
      case BubbleFace.flat:
        canvas.drawLine(p(19.5, 29.5), p(28.5, 29.5), stroke);
      case BubbleFace.smile:
        canvas.drawPath(curve(18.5, 27.5, 24, 33, 29.5, 27.5), stroke);
        cheeks(26);
      case BubbleFace.beaming:
        canvas.drawPath(curve(15.5, 21.5, 18, 18.2, 20.5, 21.5), stroke);
        canvas.drawPath(curve(27.5, 21.5, 30, 18.2, 32.5, 21.5), stroke);
        final mouth = curve(17.5, 26.5, 24, 36, 30.5, 26.5)..close();
        canvas.drawPath(mouth, fill);
        canvas.drawPath(mouth, stroke);
        cheeks(26.5);
        final spark = Path();
        const cx = 38.0, cy = 8.0, r = 3.4, q = 1.0;
        spark
          ..moveTo(cx * f, (cy - r) * f)
          ..lineTo((cx + q) * f, (cy - q) * f)
          ..lineTo((cx + r) * f, cy * f)
          ..lineTo((cx + q) * f, (cy + q) * f)
          ..lineTo(cx * f, (cy + r) * f)
          ..lineTo((cx - q) * f, (cy + q) * f)
          ..lineTo((cx - r) * f, cy * f)
          ..lineTo((cx - q) * f, (cy - q) * f)
          ..close();
        canvas.drawPath(spark, Paint()..color = colors.bubbleShine);
    }
  }

  @override
  bool shouldRepaint(_BubblePainter old) =>
      old.mood != mood || old.colors != colors || old.ring != ring;
}
