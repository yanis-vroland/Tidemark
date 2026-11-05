import 'package:flutter/material.dart';

import '../../entries/entry.dart';
import '../theme/tidemark_colors.dart';
import '../theme/tidemark_tokens.dart';
import '../theme/tidemark_typography.dart';
import 'home_header.dart' show homeMaxTextScale;
import 'mood_bubble.dart';

/// Carte du check-in de l'accueil (spec 009, CA11 à CA13) : cinq bulles
/// `bubble-check`, chacune avec son libellé (RM3) dessous ; toucher une bulle
/// ouvre la saisie avec cette humeur.
class CheckInCard extends StatelessWidget {
  const CheckInCard({super.key, required this.title, required this.onPick});

  /// « Comment va ta marée aujourd'hui ? » ou « … ce soir ? ».
  final String title;

  /// Humeur touchée, de 1 à 5.
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final card = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(TidemarkRadius.radiusXl),
        boxShadow: TidemarkShadows.shadowCard,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          TidemarkSpacing.space2,
          TidemarkSpacing.space4,
          TidemarkSpacing.space2,
          TidemarkSpacing.space2,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  style: TidemarkTypography.title.copyWith(color: colors.ink),
                ),
              ),
            ),
            const SizedBox(height: TidemarkSpacing.space2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var mood = 1; mood <= 5; mood++)
                  Expanded(
                    child: _CheckInBubble(
                      mood: mood,
                      onTap: () => onPick(mood),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: homeMaxTextScale,
      child: card,
    );
  }
}

/// Bulle du check-in, annoncée « Noter Bien, humeur 4 sur 5 » (CA12).
class _CheckInBubble extends StatelessWidget {
  const _CheckInBubble({required this.mood, required this.onTap});

  final int mood;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final label = moodLabel(mood);
    return Semantics(
      container: true,
      button: true,
      label: 'Noter $label, humeur $mood sur 5',
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(TidemarkRadius.radiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            children: [
              MoodBubble(mood: mood, size: TidemarkSize.bubbleCheck),
              const SizedBox(height: TidemarkSpacing.space1),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TidemarkTypography.caption.copyWith(
                  color: colors.inkMuted,
                  fontWeight: FontWeight.w600,
                  fontVariations: const [FontVariation.weight(600)],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
