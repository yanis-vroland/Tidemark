import 'package:flutter/material.dart';

import '../theme/tidemark_colors.dart';
import '../theme/tidemark_tokens.dart';

/// Barre de progression du téléchargement du modèle (spec 003) : `tide` sur
/// `tide-soft`, annoncée « Téléchargement du modèle, 28 % » (CA28).
class ModelProgressBar extends StatelessWidget {
  const ModelProgressBar({super.key, required this.percent});

  /// Pourcentage entier, de 0 à 100.
  final int percent;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      label: 'Téléchargement du modèle, $percent %',
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(TidemarkRadius.radiusPill),
        child: LinearProgressIndicator(
          value: percent / 100,
          minHeight: TidemarkSize.progressHeight,
          color: colors.tide,
          backgroundColor: colors.tideSoft,
        ),
      ),
    );
  }
}

/// Pourcentage entier reçu, arrondi à l'inférieur (CA9).
int percentOf(int received, int total) =>
    total <= 0 ? 0 : (received * 100 ~/ total).clamp(0, 100);
