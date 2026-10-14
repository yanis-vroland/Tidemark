import 'package:flutter/material.dart';

import '../theme/tidemark_colors.dart';
import '../theme/tidemark_tokens.dart';
import '../theme/tidemark_typography.dart';

/// Bandeau d'erreur (charte : `ErrorBanner`) : ce qui s'est passé, puis quoi faire.
/// Annoncé par le lecteur d'écran dès qu'il apparaît.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceRaised,
          border: Border.all(color: colors.danger),
          borderRadius: BorderRadius.circular(TidemarkRadius.radiusSm),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: TidemarkSpacing.space4,
            vertical: TidemarkSpacing.space3,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TidemarkTypography.headline.copyWith(
                  color: colors.danger,
                ),
              ),
              const SizedBox(height: TidemarkSpacing.space1),
              Text(message),
            ],
          ),
        ),
      ),
    );
  }
}
