import 'package:flutter/material.dart';

import '../../entries/day_grouping.dart';
import '../../entries/entry.dart';
import '../../entries/entry_repository.dart';
import '../theme/tidemark_colors.dart';
import '../theme/tidemark_tokens.dart';
import '../theme/tidemark_typography.dart';
import '../widgets/mood_dot.dart';
import 'entry_detail_screen.dart';
import 'entry_form_screen.dart';

/// Liste des entrées, écran d'accueil (spec 001).
class EntryListScreen extends StatelessWidget {
  const EntryListScreen({
    super.key,
    required this.repository,
    required this.clock,
  });

  final EntryRepository repository;

  /// Date et heure locales, pour les intertitres « Aujourd'hui » et « Hier ».
  final DateTime Function() clock;

  void _openForm(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => EntryFormScreen(repository: repository, clock: clock),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<List<Entry>>(
          stream: repository.watchEntries(),
          builder: (context, snapshot) {
            final entries = snapshot.data;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: entries == null
                      ? const SizedBox.shrink()
                      : entries.isEmpty
                      ? const _EmptyState()
                      : _EntryList(
                          groups: groupByDay(entries, clock()),
                          repository: repository,
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    TidemarkSpacing.space4,
                    TidemarkSpacing.space3,
                    TidemarkSpacing.space4,
                    TidemarkSpacing.space4,
                  ),
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      textStyle: TidemarkTypography.label.copyWith(
                        fontSize: 16,
                      ),
                    ),
                    onPressed: () => _openForm(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Nouvelle entrée'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(
      top: TidemarkSpacing.space8,
      bottom: TidemarkSpacing.space2,
    ),
    child: Text('Ton journal', style: Theme.of(context).textTheme.displaySmall),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: TidemarkSpacing.space4),
      children: [
        const _Title(),
        const SizedBox(height: TidemarkSpacing.space8 * 3),
        Text('Ta première entrée apparaîtra ici', style: text.titleLarge),
        const SizedBox(height: TidemarkSpacing.space2),
        Text(
          'Note ton humeur en quelques secondes. Tout reste sur ton téléphone.',
          style: text.bodyLarge?.copyWith(color: context.colors.inkMuted),
        ),
      ],
    );
  }
}

class _EntryList extends StatelessWidget {
  const _EntryList({required this.groups, required this.repository});

  final List<DayGroup> groups;
  final EntryRepository repository;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: TidemarkSpacing.space4),
      children: [
        const _Title(),
        for (final group in groups) ...[
          Padding(
            padding: const EdgeInsets.only(
              top: TidemarkSpacing.space4,
              bottom: TidemarkSpacing.space2,
            ),
            child: Semantics(
              header: true,
              child: Text(
                group.label,
                style: TidemarkTypography.label.copyWith(
                  fontWeight: FontWeight.w600,
                  color: context.colors.inkMuted,
                ),
              ),
            ),
          ),
          for (final entry in group.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: TidemarkSpacing.space2),
              child: _EntryCard(entry: entry, repository: repository),
            ),
        ],
      ],
    );
  }
}

/// Carte d'entrée (charte : `EntryCard`).
class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry, required this.repository});

  final Entry entry;
  final EntryRepository repository;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = entry.text;
    return Material(
      color: colors.surfaceRaised,
      borderRadius: BorderRadius.circular(TidemarkRadius.radiusMd),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                EntryDetailScreen(entry: entry, repository: repository),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(TidemarkSpacing.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  MoodDot(mood: entry.mood, size: 40),
                  const SizedBox(width: TidemarkSpacing.space3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          moodLabel(entry.mood),
                          style: TidemarkTypography.headline,
                        ),
                        Text(
                          timeLabel(entry.localCreatedAt),
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
                const SizedBox(height: TidemarkSpacing.space2),
                Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TidemarkTypography.body,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
