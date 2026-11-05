import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tidemark_tokens.dart';
import '../theme/tidemark_typography.dart';

/// Rotation fixe d'un autocollant, tirée de son texte : entre −2,4° et +2,4°,
/// toujours la même pour un même texte (spec 008, « Autocollant »).
double stickerAngle(String text) {
  final seed = text.codeUnits.fold<int>(0, (sum, unit) => sum * 31 + unit);
  final step = seed.abs() % 7 - 3;
  return step * 0.8 * math.pi / 180;
}

/// Autocollant (spec 008) : fond plein, `radius-pill`, `shadow-sticker`, légère
/// rotation fixe. Décoratif ou non selon le parent : il n'ajoute aucune
/// sémantique propre.
class Sticker extends StatelessWidget {
  const Sticker({
    super.key,
    required this.text,
    required this.background,
    required this.foreground,
    this.style,
    this.angle,
  });

  final String text;
  final Color background;
  final Color foreground;

  /// Style du texte ; `sticker` par défaut.
  final TextStyle? style;

  /// Rotation en radians ; [stickerAngle] du texte par défaut.
  final double? angle;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: angle ?? stickerAngle(text),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(TidemarkRadius.radiusPill),
        boxShadow: TidemarkShadows.shadowSticker,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TidemarkSpacing.space3,
          vertical: TidemarkSpacing.space1,
        ),
        child: Text(
          text,
          style: (style ?? TidemarkTypography.sticker).copyWith(
            color: foreground,
          ),
        ),
      ),
    ),
  );
}

/// Ombre `shadow-press` sous un bouton plein (spec 008, CA17).
class PressShadow extends StatelessWidget {
  const PressShadow({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(TidemarkRadius.radiusPill),
      boxShadow: TidemarkShadows.shadowPress,
    ),
    child: child,
  );
}
