import 'package:flutter/material.dart';

import '../../entries/day_grouping.dart';
import '../../entries/entry.dart';
import '../../entries/entry_repository.dart';
import '../../model/model_downloader.dart';
import '../../review/local_week.dart';
import '../../review/review_narrator.dart';
import '../../review/review_writer.dart';
import '../../settings/settings_repository.dart';
import '../phone_dialer.dart';
import '../theme/tidemark_colors.dart';
import '../theme/tidemark_tokens.dart';
import '../theme/tidemark_typography.dart';
import '../analysis_scope.dart';
import '../widgets/entry_tags_section.dart' show analysingText;
import '../widgets/loading_note.dart';
import '../widgets/mood_dot.dart';
import '../widgets/my_data_section.dart';
import '../widgets/tag_chip.dart';
import 'entry_detail_screen.dart';
import 'entry_form_screen.dart';
import 'settings_screen.dart';
import 'weekly_review_screen.dart';

/// Liste des entrées, écran d'accueil (spec 001).
class EntryListScreen extends StatefulWidget {
  const EntryListScreen({
    super.key,
    required this.repository,
    required this.settings,
    required this.downloader,
    this.dialer = const UrlLauncherDialer(),
    required this.clock,
    this.data,
    this.wiped = false,
    this.narrator,
  });

  /// Export et suppression totale, passés aux Réglages (spec 005).
  final DataActions? data;

  /// Une suppression totale vient de réussir : message de fin au-dessus de la
  /// liste vide (CA18).
  final bool wiped;

  final EntryRepository repository;

  /// Réglages, ouverts par l'icône « Réglages » (spec 002).
  final SettingsRepository settings;

  /// Modèle local : proposition après la première entrée « en attente » (spec 003).
  final ModelDownloader downloader;

  /// Composeur, pour l'écran d'aide (spec 002).
  final PhoneDialer dialer;

  /// Date et heure locales, pour les intertitres « Aujourd'hui » et « Hier ».
  final DateTime Function() clock;

  /// Mise en mots du bilan de la semaine (spec 006), partagée par toute l'app ;
  /// `null` : bilan sans rédacteur (modèle absent).
  final ReviewNarrator? narrator;

  @override
  State<EntryListScreen> createState() => _EntryListScreenState();
}

class _EntryListScreenState extends State<EntryListScreen> {
  late final Stream<List<Entry>> _entries = widget.repository.watchEntries();

  /// Message de fin de la suppression totale : affiché jusqu'à la première
  /// entrée, jamais de nouveau ensuite (CA18, CA19).
  late bool _wiped = widget.wiped;

  /// Sans rédacteur fourni, le bilan s'affiche sans texte (modèle absent).
  late final ReviewNarrator _narrator =
      widget.narrator ??
      ReviewNarrator(
        writer: const NoReviewWriter(),
        downloader: widget.downloader,
      );

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
      builder: (_) => EntryFormScreen(
        repository: widget.repository,
        settings: widget.settings,
        downloader: widget.downloader,
        dialer: widget.dialer,
        clock: widget.clock,
      ),
    ),
  );

  void _openSettings() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => SettingsScreen(
        settings: widget.settings,
        downloader: widget.downloader,
        data: widget.data,
      ),
    ),
  );

  void _openReview() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => WeeklyReviewScreen(
        repository: widget.repository,
        narrator: _narrator,
        clock: widget.clock,
      ),
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
            if (entries != null && entries.isNotEmpty) _wiped = false;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: snapshot.hasError
                      ? _ReadError(onOpenSettings: _openSettings)
                      : entries == null
                      ? _Loading(onOpenSettings: _openSettings)
                      : entries.isEmpty
                      ? _EmptyState(
                          onOpenSettings: _openSettings,
                          wiped: _wiped,
                        )
                      : _EntryList(
                          onOpenSettings: _openSettings,
                          onOpenReview: _openReview,
                          groups: groupByDay(entries, widget.clock()),
                          repository: widget.repository,
                          downloader: widget.downloader,
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

/// Titre de la liste et icône « Réglages » (spec 002, CA17), dans tous les états.
class _Title extends StatelessWidget {
  const _Title({required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(
      top: TidemarkSpacing.space8,
      bottom: TidemarkSpacing.space2,
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            'Ton journal',
            style: Theme.of(context).textTheme.displaySmall,
          ),
        ),
        // Annoncé « Réglages » : l'infobulle seule ne donne pas de libellé.
        Semantics(
          container: true,
          button: true,
          label: 'Réglages',
          onTap: onOpenSettings,
          excludeSemantics: true,
          child: IconButton(
            onPressed: onOpenSettings,
            tooltip: 'Réglages',
            color: context.colors.tide,
            constraints: const BoxConstraints.tightFor(
              width: TidemarkSize.tapMin,
              height: TidemarkSize.tapMin,
            ),
            icon: const Icon(
              Icons.settings_outlined,
              size: TidemarkSize.iconMd,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Chargement : le titre seulement, la lecture de la base est brève.
class _Loading extends StatelessWidget {
  const _Loading({required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.symmetric(horizontal: TidemarkSpacing.space4),
    children: [_Title(onOpenSettings: onOpenSettings)],
  );
}

/// Lecture impossible : ce qui s'est passé, sans rien effacer.
class _ReadError extends StatelessWidget {
  const _ReadError({required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: TidemarkSpacing.space4),
      children: [
        _Title(onOpenSettings: onOpenSettings),
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
  const _EmptyState({required this.onOpenSettings, this.wiped = false});

  final VoidCallback onOpenSettings;

  /// Message de fin d'une suppression totale au-dessus de l'état vide (CA18).
  final bool wiped;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.colors;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: TidemarkSpacing.space4),
      children: [
        _Title(onOpenSettings: onOpenSettings),
        if (wiped) ...[
          const SizedBox(height: TidemarkSpacing.space2),
          // Annoncé dès son apparition (CA33).
          Semantics(
            liveRegion: true,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.tideSoft,
                borderRadius: BorderRadius.circular(TidemarkRadius.radiusMd),
              ),
              child: Padding(
                padding: const EdgeInsets.all(TidemarkSpacing.space4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Toutes tes données ont été supprimées',
                      style: TidemarkTypography.headline.copyWith(
                        color: colors.ink,
                      ),
                    ),
                    const SizedBox(height: TidemarkSpacing.space1),
                    Text(
                      'Ton journal repart de zéro, sur ce téléphone.',
                      style: TidemarkTypography.body.copyWith(
                        color: colors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: TidemarkSpacing.space8),
        Text('Ta première entrée apparaîtra ici', style: text.titleLarge),
        const SizedBox(height: TidemarkSpacing.space2),
        Text(
          'Note ton humeur en quelques secondes. Tout reste sur ton téléphone.',
          style: text.bodyLarge?.copyWith(color: colors.inkMuted),
        ),
      ],
    );
  }
}

class _EntryList extends StatelessWidget {
  const _EntryList({
    required this.onOpenSettings,
    required this.onOpenReview,
    required this.groups,
    required this.repository,
    required this.downloader,
    required this.clock,
  });

  final VoidCallback onOpenSettings;

  /// Ouvre le bilan de la semaine (spec 006).
  final VoidCallback onOpenReview;
  final List<DayGroup> groups;
  final EntryRepository repository;
  final ModelDownloader downloader;
  final DateTime Function() clock;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: TidemarkSpacing.space4),
      children: [
        _Title(onOpenSettings: onOpenSettings),
        const SizedBox(height: TidemarkSpacing.space2),
        _ReviewCard(week: LocalWeek.containing(clock()), onTap: onOpenReview),
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
                downloader: downloader,
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
    required this.downloader,
    required this.clock,
  });

  final Entry entry;
  final EntryRepository repository;
  final ModelDownloader downloader;
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
          '${text == null ? '' : ', ${_excerpt(text)}'}'
          '${entry.tags.isEmpty ? '' : ', étiquettes : ${entry.tags.map((t) => t.label).join(', ')}'}',
      excludeSemantics: true,
      onTap: () => _open(context),
      child: _cardBody(context, colors, text),
    );
  }

  void _open(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => EntryDetailScreen(
        entry: entry,
        repository: repository,
        downloader: downloader,
        clock: clock,
      ),
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
              if (AnalysisScope.maybeOf(context)?.currentEntryId ==
                  entry.id) ...[
                const SizedBox(height: TidemarkSpacing.space3),
                const LoadingNote(text: analysingText),
              ] else if (entry.tags.isNotEmpty) ...[
                const SizedBox(height: TidemarkSpacing.space3),
                TagChips(tags: entry.tags),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Carte « Bilan de la semaine », en tête de la liste (spec 006, CA1).
class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.week, required this.onTap});

  final LocalWeek week;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dates = weekCardLabel(week);
    return Semantics(
      container: true,
      button: true,
      label:
          'Bilan de la semaine, ${dates[0].toLowerCase()}${dates.substring(1)}',
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(TidemarkRadius.radiusMd),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(TidemarkSpacing.space4),
            child: Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.tideSoft,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox.square(
                    dimension: TidemarkSize.moodDotSm,
                    child: Icon(
                      Icons.bar_chart,
                      size: TidemarkSize.iconMd,
                      color: colors.tide,
                    ),
                  ),
                ),
                const SizedBox(width: TidemarkSpacing.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bilan de la semaine',
                        style: TidemarkTypography.headline,
                      ),
                      Text(
                        dates,
                        style: TidemarkTypography.caption.copyWith(
                          color: colors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: TidemarkSize.iconMd,
                  color: colors.tide,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
