import 'package:flutter/material.dart';

import '../../entries/day_grouping.dart';
import '../../entries/entry.dart';
import '../../entries/entry_repository.dart';
import '../../model/model_downloader.dart';
import '../theme/tidemark_colors.dart';
import '../theme/tidemark_tokens.dart';
import '../theme/tidemark_typography.dart';
import '../widgets/entry_tags_section.dart';
import '../widgets/mood_dot.dart';

/// Détail d'une entrée et sa suppression (spec 001). Aucun moyen de la modifier
/// (RM15).
class EntryDetailScreen extends StatelessWidget {
  const EntryDetailScreen({
    super.key,
    required this.entry,
    required this.repository,
    this.downloader,
    this.clock,
  });

  final Entry entry;
  final EntryRepository repository;

  /// Modèle local, pour l'état de l'analyse d'une entrée « en attente » (spec 004,
  /// CA23) ; sans lui, cet état n'est pas affiché.
  final ModelDownloader? downloader;

  /// Date et heure locales, pour n'afficher l'année que si elle diffère de l'année
  /// en cours (maquette) ; [DateTime.now] par défaut.
  final DateTime Function()? clock;

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
    try {
      await repository.deleteEntry(entry.id);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("L'entrée n'a pas été supprimée. Réessaie."),
          ),
        );
      }
      return;
    }
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
                      local.year == (clock ?? DateTime.now)().year
                          ? weekdayAndDate(local)
                          : fullDateLabel(local),
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
                        MoodDot(mood: entry.mood, size: TidemarkSize.moodDotLg),
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
                    // L'entrée relue à chaque changement : ses étiquettes
                    // apparaissent dès que l'analyse se termine (CA18).
                    StreamBuilder<List<Entry>>(
                      stream: repository.watchEntries(),
                      builder: (context, snapshot) => EntryTagsSection(
                        entry:
                            snapshot.data
                                ?.where((e) => e.id == entry.id)
                                .firstOrNull ??
                            entry,
                        downloader: downloader,
                      ),
                    ),
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
        foregroundColor: colors.danger,
        backgroundColor: colors.surfaceRaised,
        side: BorderSide(color: colors.danger),
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}
