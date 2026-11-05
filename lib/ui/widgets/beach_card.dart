import 'package:flutter/material.dart';

import '../../entries/entry.dart';
import '../theme/tidemark_colors.dart';
import '../theme/tidemark_tokens.dart';
import '../theme/tidemark_typography.dart';
import 'dashed_circle.dart';
import 'home_header.dart' show homeMaxTextScale;
import 'mood_bubble.dart';

/// Noms des jours, du lundi au dimanche, pour les annonces (spec 009, CA15, CA24).
const weekdayNames = [
  'lundi',
  'mardi',
  'mercredi',
  'jeudi',
  'vendredi',
  'samedi',
  'dimanche',
];

/// Initiales des jours, du lundi au dimanche.
const weekdayInitials = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

/// « lundi Bien, mardi pas d'entrée, … » : humeur du jour de chaque jour.
String dayMoodsSentence(List<int?> moods) => [
  for (var i = 0; i < 7; i++)
    '${weekdayNames[i]} ${moods[i] == null ? "pas d'entrée" : moodLabel(moods[i]!)}',
].join(', ');

/// Montée de la bulle d'un jour par cran d'humeur au-dessus de 1 (CA14).
const _liftPerMood = 8.0;

/// Diamètre du cercle pointillé d'un jour sans entrée (maquette).
const _emptyDay = 32.0;

/// Plage de la semaine en cours (spec 009, CA14 à CA16) : sept jours de « L » à
/// « D », une bulle `bubble-sm` de l'humeur du jour d'autant plus haute que
/// l'humeur est haute, un cercle pointillé pour un jour sans entrée. Annoncée comme
/// un seul bouton.
class BeachCard extends StatelessWidget {
  const BeachCard({super.key, required this.moods, required this.onTap});

  /// Humeur du jour, du lundi au dimanche ; `null` sans entrée.
  final List<int?> moods;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final title = TidemarkTypography.headline.copyWith(
      fontFamily: TidemarkTypography.displayFamily,
      fontWeight: FontWeight.w700,
      fontVariations: const [FontVariation.weight(700)],
      color: colors.onHero,
    );
    return Semantics(
      container: true,
      button: true,
      label:
          'Ta plage cette semaine : ${dayMoodsSentence(moods)}. Ouvre le bilan '
          'de la semaine.',
      onTap: onTap,
      excludeSemantics: true,
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: homeMaxTextScale,
        child: Material(
          color: colors.sand,
          borderRadius: BorderRadius.circular(TidemarkRadius.radiusLg),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CustomPaint(
                  painter: _SeaBandPainter(
                    sea: colors.sea,
                    foam: colors.bubbleShine,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      TidemarkSpacing.space4,
                      TidemarkSpacing.space2,
                      TidemarkSpacing.space4,
                      TidemarkSpacing.space4,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text('Ta plage cette semaine', style: title),
                        ),
                        const SizedBox(width: TidemarkSpacing.space2),
                        Text(
                          'Voir',
                          style: TidemarkTypography.label.copyWith(
                            color: colors.onHero,
                            fontWeight: FontWeight.w700,
                            fontVariations: const [FontVariation.weight(700)],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    TidemarkSpacing.space3,
                    0,
                    TidemarkSpacing.space3,
                    TidemarkSpacing.space2,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var i = 0; i < 7; i++)
                        Expanded(
                          child: _BeachDay(index: i, mood: moods[i]),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Un jour de la plage : bulle ou cercle pointillé, et son initiale.
class _BeachDay extends StatelessWidget {
  const _BeachDay({required this.index, required this.mood});

  final int index;
  final int? mood;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final mood = this.mood;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: TidemarkSize.bubbleSm + 4 * _liftPerMood,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: mood == null
                ? CustomPaint(
                    key: Key('day-empty-$index'),
                    size: const Size.square(_emptyDay),
                    painter: DashedCirclePainter(color: colors.onSand),
                  )
                : Padding(
                    padding: EdgeInsets.only(bottom: (mood - 1) * _liftPerMood),
                    child: MoodBubble(mood: mood, size: TidemarkSize.bubbleSm),
                  ),
          ),
        ),
        const SizedBox(height: TidemarkSpacing.space1),
        Text(
          weekdayInitials[index],
          style: TidemarkTypography.caption.copyWith(
            color: colors.onSand,
            fontWeight: FontWeight.w800,
            fontVariations: const [FontVariation.weight(800)],
          ),
        ),
      ],
    );
  }
}

/// Mer en haut de la plage, dont le bord ondule sur le sable, avec une ligne
/// d'écume pointillée.
class _SeaBandPainter extends CustomPainter {
  const _SeaBandPainter({required this.sea, required this.foam});

  final Color sea;
  final Color foam;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final shore = Path()
      ..moveTo(0, h - 4)
      ..cubicTo(w * 0.17, h + 2, w * 0.33, h - 14, w * 0.5, h - 8)
      ..cubicTo(w * 0.67, h - 2, w * 0.83, h - 18, w, h - 12);
    canvas.drawPath(
      Path.from(shore)
        ..lineTo(w, 0)
        ..lineTo(0, 0)
        ..close(),
      Paint()..color = sea,
    );
    final foamPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = foam.withValues(alpha: 0.8);
    for (final metric in shore.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 8) {
        canvas.drawPath(metric.extractPath(d, d + 1), foamPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_SeaBandPainter old) => old.sea != sea || old.foam != foam;
}
