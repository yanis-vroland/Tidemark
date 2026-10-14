import 'package:flutter/material.dart';

import '../theme/tidemark_colors.dart';
import '../theme/tidemark_typography.dart';

/// Pastille d'une humeur, avec son chiffre (charte : `MoodSelector`, `EntryCard`).
/// Purement visuelle : le libellé de l'humeur est toujours donné à côté ou dans la
/// sémantique du parent. Le chiffre ne suit pas la taille de texte du système, pour
/// rester dans la pastille.
class MoodDot extends StatelessWidget {
  const MoodDot({super.key, required this.mood, required this.size});

  final int mood;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.moodColor(mood),
          shape: BoxShape.circle,
        ),
        child: SizedBox.square(
          dimension: size,
          child: Center(
            child: MediaQuery.withNoTextScaling(
              child: Text(
                '$mood',
                style: TidemarkTypography.moodNumeral.copyWith(
                  fontSize: size * 0.45,
                  height: 1,
                  color: colors.onMoodColor(mood),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
