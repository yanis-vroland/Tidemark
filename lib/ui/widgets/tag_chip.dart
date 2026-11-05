import 'package:flutter/material.dart';

import '../../analysis/mood_analyzer.dart';
import '../theme/tidemark_colors.dart';
import '../theme/tidemark_tokens.dart';
import '../theme/tidemark_typography.dart';
import 'sticker.dart';

/// Puce d'étiquette (charte v2 : autocollant, spec 008) : `ink` sur
/// `tide-soft`, même couleur pour toutes les étiquettes (spec 004, CA26), ombre `shadow-sticker`, rotation fixe ; ni cliquable ni
/// modifiable (RM19, RM58).
class TagChip extends StatelessWidget {
  const TagChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Sticker(
      text: label,
      background: colors.tideSoft,
      foreground: colors.ink,
      style: TidemarkTypography.label,
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
