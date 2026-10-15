import 'package:flutter/material.dart';

import '../theme/tidemark_colors.dart';
import '../theme/tidemark_tokens.dart';
import '../theme/tidemark_typography.dart';

/// Mention de chargement (charte : `LoadingNote`) : indicateur en `tide`, texte
/// `label` en `ink-muted`, annoncé comme un statut. L'indicateur ne tourne pas
/// quand le téléphone demande de réduire les animations.
class LoadingNote extends StatelessWidget {
  const LoadingNote({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final reduced = MediaQuery.of(context).disableAnimations;
    return Semantics(
      liveRegion: true,
      label: text,
      excludeSemantics: true,
      child: Row(
        children: [
          SizedBox.square(
            dimension: TidemarkSize.iconButton,
            child: CircularProgressIndicator(
              value: reduced ? 0.75 : null,
              strokeWidth: TidemarkSize.ringWidth,
              color: colors.tide,
            ),
          ),
          const SizedBox(width: TidemarkSpacing.space2),
          Expanded(
            child: Text(
              text,
              style: TidemarkTypography.label.copyWith(color: colors.inkMuted),
            ),
          ),
        ],
      ),
    );
  }
}
