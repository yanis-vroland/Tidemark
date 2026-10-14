import 'package:flutter/material.dart';

import '../../entries/day_grouping.dart';
import '../../entries/entry.dart';
import '../../entries/entry_repository.dart';
import '../theme/tidemark_colors.dart';
import '../theme/tidemark_tokens.dart';
import '../theme/tidemark_typography.dart';
import '../widgets/mood_dot.dart';

/// Détail d'une entrée et sa suppression (spec 001). Aucun moyen de la modifier
/// (RM15).
class EntryDetailScreen extends StatelessWidget {
  const EntryDetailScreen({
    super.key,
    required this.entry,
    required this.repository,
  });

  final Entry entry;
  final EntryRepository repository;

  Future<void> _confirmDelete(BuildContext context) async {
    final colors = context.colors;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: colors.surfaceRaised,
      // Défilable : à 200 % de taille de texte, la feuille dépasse l'écran (CA27).
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            TidemarkSpacing.space4,
            TidemarkSpacing.space6,
            TidemarkSpacing.space4,
            TidemarkSpacing.space4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Supprimer cette entrée ?',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: TidemarkSpacing.space3),
              Text(
                "La suppression est définitive : l'entrée ne pourra pas être "
                'récupérée.',
                style: TidemarkTypography.body.copyWith(color: colors.inkMuted),
              ),
              const SizedBox(height: TidemarkSpacing.space6),
              _DangerButton(
                label: 'Supprimer',
                onPressed: () => Navigator.of(context).pop(true),
              ),
              const SizedBox(height: TidemarkSpacing.space3),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  side: BorderSide(color: colors.line),
                ),
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Annuler'),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await repository.deleteEntry(entry.id);
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final local = entry.localCreatedAt;
    final text = entry.text;
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: TidemarkSpacing.space4,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.chevron_left),
                        label: const Text('Journal'),
                      ),
                    ),
                    const SizedBox(height: TidemarkSpacing.space4),
                    Text(
                      fullDateLabel(local),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      timeLabel(local),
                      style: TidemarkTypography.caption.copyWith(
                        color: colors.inkMuted,
                      ),
                    ),
                    const SizedBox(height: TidemarkSpacing.space6),
                    Row(
                      children: [
                        MoodDot(mood: entry.mood, size: 72),
                        const SizedBox(width: TidemarkSpacing.space4),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                moodLabel(entry.mood),
                                style: TidemarkTypography.headline,
                              ),
                              Text(
                                'Humeur ${entry.mood} sur 5',
                                style: TidemarkTypography.caption.copyWith(
                                  color: colors.inkMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (text != null) ...[
                      const SizedBox(height: TidemarkSpacing.space6),
                      Text(text, style: TidemarkTypography.body),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(TidemarkSpacing.space4),
              child: _DangerButton(
                label: 'Supprimer cette entrée',
                onPressed: () => _confirmDelete(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bouton destructif (charte : `Button`, variante destructive).
class _DangerButton extends StatelessWidget {
  const _DangerButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        foregroundColor: colors.danger,
        backgroundColor: colors.surfaceRaised,
        side: BorderSide(color: colors.danger),
        textStyle: TidemarkTypography.label.copyWith(fontSize: 16),
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}
