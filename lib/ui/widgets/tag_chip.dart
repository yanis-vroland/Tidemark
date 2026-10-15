import 'package:flutter/material.dart';

import '../../analysis/mood_analyzer.dart';
import '../theme/tidemark_colors.dart';
import '../theme/tidemark_tokens.dart';
import '../theme/tidemark_typography.dart';

/// Puce d'étiquette (charte : `TagChip`) : `label` en `ink` sur `tide-soft`, même
/// couleur pour toutes les émotions, ni cliquable ni modifiable (RM19, CA26).
class TagChip extends StatelessWidget {
  const TagChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.tideSoft,
        borderRadius: BorderRadius.circular(TidemarkRadius.radiusPill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TidemarkSpacing.space3,
          vertical: TidemarkSpacing.space1,
        ),
        child: Text(
          label,
          style: TidemarkTypography.label.copyWith(color: colors.ink),
        ),
      ),
    );
  }
}

/// Rangée de puces, qui passe à la ligne (CA29).
class TagChips extends StatelessWidget {
  const TagChips({super.key, required this.tags});

  final List<Tag> tags;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: TidemarkSpacing.space2,
    runSpacing: TidemarkSpacing.space2,
    children: [for (final tag in tags) TagChip(label: tag.label)],
  );
}
