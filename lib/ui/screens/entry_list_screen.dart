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
class EntryListScreen extends StatefulWidget {
  const EntryListScreen({
    super.key,
    required this.repository,
    required this.clock,
  });

  final EntryRepository repository;

  /// Date et heure locales, pour les intertitres « Aujourd'hui » et « Hier ».
  final DateTime Function() clock;

  @override
  State<EntryListScreen> createState() => _EntryListScreenState();
}

class _EntryListScreenState extends State<EntryListScreen> {
  late final Stream<List<Entry>> _entries = widget.repository.watchEntries();

  /// Au retour au premier plan, « Aujourd'hui » et « Hier » sont recalculés : l'app
  /// a pu rester ouverte après minuit.
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: () => setState(() {}));
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _openForm(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          EntryFormScreen(repository: widget.repository, clock: widget.clock),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<List<Entry>>(
          stream: _entries,
          builder: (context, snapshot) {
            final entries = snapshot.data;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: snapshot.hasError
                      ? const _ReadError()
                      : entries == null
                      ? const _Loading()
                      : entries.isEmpty
                      ? const _EmptyState()
                      : _EntryList(
                          groups: groupByDay(entries, widget.clock()),
                          repository: widget.repository,
                          clock: widget.clock,
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

/// Chargement : le titre seulement, la lecture de la base est brève.
class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.symmetric(horizontal: TidemarkSpacing.space4),
    children: const [_Title()],
  );
}

/// Lecture impossible : ce qui s'est passé, sans rien effacer.
class _ReadError extends StatelessWidget {
  const _ReadError();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: TidemarkSpacing.space4),
      children: [
        const _Title(),
        const SizedBox(height: TidemarkSpacing.space6),
        Text(
          "Ton journal n'a pas pu être lu",
          style: TidemarkTypography.headline.copyWith(color: colors.danger),
        ),
        const SizedBox(height: TidemarkSpacing.space1),
        const Text(
          "Tes entrées sont toujours sur le téléphone. Ferme l'app, puis rouvre-la.",
        ),
      ],
    );
  }
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
        const SizedBox(height: TidemarkSpacing.space8),
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
  const _EntryList({
    required this.groups,
    required this.repository,
    required this.clock,
  });

  final List<DayGroup> groups;
  final EntryRepository repository;
  final DateTime Function() clock;

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
              child: _EntryCard(
                entry: entry,
                repository: repository,
                clock: clock,
              ),
            ),
        ],
      ],
    );
  }
}

/// Début d'un texte pour l'annonce d'une carte : l'écran n'en montre que deux
/// lignes, le lecteur d'écran n'en lit que le début (CA36).
String _excerpt(String text) {
  const max = 120;
  final chars = text.characters;
  return chars.length <= max
      ? text
      : '${chars.take(max).toString().trimRight()}…';
}

/// Carte d'entrée (charte : `EntryCard`).
class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.entry,
    required this.repository,
    required this.clock,
  });

  final Entry entry;
  final EntryRepository repository;
  final DateTime Function() clock;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = entry.text;
    final time = timeLabel(entry.localCreatedAt);
    // Annonce complète de la carte, chiffre compris (la pastille est muette).
    return Semantics(
      button: true,
      label:
          '${moodLabel(entry.mood)}, humeur ${entry.mood} sur 5, $time'
          '${text == null ? '' : ', ${_excerpt(text)}'}',
      excludeSemantics: true,
      onTap: () => _open(context),
      child: _cardBody(context, colors, text),
    );
  }

  void _open(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          EntryDetailScreen(entry: entry, repository: repository, clock: clock),
    ),
  );

  Widget _cardBody(BuildContext context, TidemarkColors colors, String? text) {
    return Material(
      color: colors.surfaceRaised,
      borderRadius: BorderRadius.circular(TidemarkRadius.radiusMd),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(context),
        child: Padding(
          padding: const EdgeInsets.all(TidemarkSpacing.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  MoodDot(mood: entry.mood, size: TidemarkSize.moodDotSm),
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
