import 'package:flutter/material.dart';

import '../theme/tidemark_colors.dart';
import '../theme/tidemark_tokens.dart';
import '../theme/tidemark_typography.dart';
import 'beach_card.dart' show dayMoodsSentence, weekdayInitials;
import 'dashed_circle.dart';
import 'mood_bubble.dart';

/// Hauteur de la mer de la marée, rivage compris.
const _seaHeight = 168.0;

/// Centre d'une bulle d'humeur 1, depuis le haut de la mer, et montée par cran.
const _lowestCenter = 132.0;
const _risePerMood = 24.0;

/// Hauteur du rivage `sand` dessiné en bas de la mer.
const _shore = 14.0;

/// Diamètre du cercle pointillé d'un jour sans entrée.
const _emptyDay = TidemarkSize.bubbleSm - 4;

/// Marée de la semaine, dans l'en-tête `sky` du bilan (spec 009, CA24) : pour chaque
/// jour noté, une bulle de l'humeur du jour posée sur une mer `sea` dont la surface
/// passe par les bulles ; un cercle pointillé pour un jour sans entrée ; les
/// initiales des jours sur une bande `sand`.
///
/// Décorative : annoncée par un seul libellé, « Humeur par jour : … ». Avec [moods]
/// à `null` (lecture en cours ou en erreur), la mer est plate et rien n'est annoncé.
class WeekTide extends StatelessWidget {
  const WeekTide({super.key, required this.moods});

  /// Humeur du jour, du lundi au dimanche ; `null` sans entrée.
  final List<int?>? moods;

  static double _centerY(int mood) => _lowestCenter - (mood - 1) * _risePerMood;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final moods = this.moods;
    final figure = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: _seaHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final column = constraints.maxWidth / 7;
              return Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _TidePainter(
                        moods: moods ?? List<int?>.filled(7, null),
                        sea: colors.sea,
                        sand: colors.sand,
                        foam: colors.bubbleShine,
                      ),
                    ),
                  ),
                  if (moods != null)
                    for (var i = 0; i < 7; i++)
                      _dayMark(i, moods[i], column, colors),
                ],
              );
            },
          ),
        ),
        ColoredBox(
          color: colors.sand,
          child: Padding(
            padding: const EdgeInsets.only(
              top: TidemarkSpacing.space1,
              bottom: 6,
            ),
            child: Row(
              children: [
                for (final initial in weekdayInitials)
                  Expanded(
                    child: Text(
                      initial,
                      textAlign: TextAlign.center,
                      style: TidemarkTypography.caption.copyWith(
                        color: colors.onSand,
                        fontWeight: FontWeight.w800,
                        fontVariations: const [FontVariation.weight(800)],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
    if (moods == null) return ExcludeSemantics(child: figure);
    return Semantics(
      container: true,
      label: 'Humeur par jour : ${dayMoodsSentence(moods)}.',
      excludeSemantics: true,
      child: figure,
    );
  }

  Widget _dayMark(int index, int? mood, double column, TidemarkColors colors) {
    final x = (index + 0.5) * column;
    if (mood == null) {
      return Positioned(
        left: x - _emptyDay / 2,
        top: _centerY(3) - _emptyDay / 2,
        child: CustomPaint(
          size: const Size.square(_emptyDay),
          painter: DashedCirclePainter(
            color: colors.bubbleShine.withValues(alpha: 0.8),
            strokeWidth: 2.5,
          ),
        ),
      );
    }
    const size = TidemarkSize.bubbleSm;
    return Positioned(
      left: x - size / 2,
      top: _centerY(mood) - size / 2,
      child: MoodBubble(mood: mood, size: size),
    );
  }
}

/// Mer dont la surface passe par l'humeur de chaque jour (humeur 3 pour un jour
/// sans entrée), écume pointillée, et rivage `sand` en bas.
class _TidePainter extends CustomPainter {
  const _TidePainter({
    required this.moods,
    required this.sea,
    required this.sand,
    required this.foam,
  });

  final List<int?> moods;
  final Color sea;
  final Color sand;
  final Color foam;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final column = w / 7;
    final points = [
      for (var i = 0; i < 7; i++)
        Offset((i + 0.5) * column, WeekTide._centerY(moods[i] ?? 3)),
    ];
    final surface = Path()
      ..moveTo(0, points.first.dy)
      ..lineTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1];
      final b = points[i];
      final mid = (a.dx + b.dx) / 2;
      surface.cubicTo(mid, a.dy, mid, b.dy, b.dx, b.dy);
    }
    surface.lineTo(w, points.last.dy);
    canvas.drawPath(
      Path.from(surface)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close(),
      Paint()..color = sea,
    );
    final foamPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..color = foam.withValues(alpha: 0.85);
    for (final metric in surface.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 8) {
        canvas.drawPath(metric.extractPath(d, d + 1), foamPaint);
      }
    }
    canvas.drawPath(
      Path()
        ..moveTo(0, h - _shore + 4)
        ..cubicTo(
          w * 0.2,
          h - _shore - 4,
          w * 0.38,
          h - _shore + 8,
          w * 0.58,
          h - _shore,
        )
        ..cubicTo(
          w * 0.75,
          h - _shore - 6,
          w * 0.9,
          h - _shore + 2,
          w,
          h - _shore,
        )
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close(),
      Paint()..color = sand,
    );
  }

  @override
  bool shouldRepaint(_TidePainter old) =>
      old.sea != sea ||
      old.sand != sand ||
      old.foam != foam ||
      !_sameMoods(old.moods, moods);

  static bool _sameMoods(List<int?> a, List<int?> b) {
    for (var i = 0; i < 7; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
