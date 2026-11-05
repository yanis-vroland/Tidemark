import 'package:flutter/material.dart';

import '../../entries/day_grouping.dart';
import '../../entries/entry.dart';
import '../../entries/entry_repository.dart';
import '../../entries/week_summary.dart';
import '../../model/model_downloader.dart';
import '../../review/local_week.dart';
import '../../review/review_narrator.dart';
import '../../review/review_writer.dart';
import '../../settings/settings_repository.dart';
import '../day_moment.dart';
import '../phone_dialer.dart';
import '../theme/tidemark_colors.dart';
import '../theme/tidemark_theme.dart';
import '../theme/tidemark_tokens.dart';
import '../theme/tidemark_typography.dart';
import '../analysis_scope.dart';
import '../widgets/beach_card.dart';
import '../widgets/check_in_card.dart';
import '../widgets/entry_tags_section.dart' show analysingText;
import '../widgets/home_header.dart';
import '../widgets/loading_note.dart';
import '../widgets/mood_bubble.dart';
import '../widgets/my_data_section.dart';
import '../widgets/tag_chip.dart';
import '../widgets/tidemark_logo.dart';
import 'entry_detail_screen.dart';
import 'entry_form_screen.dart';
import 'settings_screen.dart';
import 'weekly_review_screen.dart';

/// Accueil du journal (specs 001 et 009) : en-tête, check-in, plage de la semaine
/// et entrées regroupées par jour. Dans l'app, il est l'onglet « Journal » de
/// `HomeShell`, dont la barre porte « Nouvelle entrée ».
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
    this.onOpenWeek,
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

  /// Date et heure locales : intertitres « Aujourd'hui » et « Hier », salutation,
  /// semaine en cours.
  final DateTime Function() clock;

  /// Mise en mots du bilan de la semaine (spec 006), partagée par toute l'app ;
  /// `null` : bilan sans rédacteur (modèle absent).
  final ReviewNarrator? narrator;

  /// Ouvre l'onglet « Semaine » quand la plage est touchée (spec 009, CA16) ;
  /// `null` : le bilan s'ouvre par-dessus la liste.
  final VoidCallback? onOpenWeek;

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

  /// Au retour au premier plan, « Aujourd'hui » et « Hier », la salutation et la
  /// semaine en cours sont recalculés : l'app a pu rester ouverte après minuit
  /// (spec 009, CA10).
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

  void _openForm({int? mood}) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => EntryFormScreen(
        repository: widget.repository,
        settings: widget.settings,
        downloader: widget.downloader,
        dialer: widget.dialer,
        clock: widget.clock,
        initialMood: mood,
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

  void _openWeek() {
    final onOpenWeek = widget.onOpenWeek;
    if (onOpenWeek != null) {
      onOpenWeek();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WeeklyReviewScreen(
          repository: widget.repository,
          narrator: _narrator,
          clock: widget.clock,
        ),
      ),
    );
  }

  /// Intertitre d'un jour, au-dessus de ses entrées (spec 001, CA2, CA3, CA6).
  Widget _dayLabel(String label) => Padding(
    padding: const EdgeInsets.fromLTRB(
      TidemarkSpacing.space4,
      TidemarkSpacing.space3,
      TidemarkSpacing.space4,
      TidemarkSpacing.space2,
    ),
    child: Semantics(
      header: true,
      child: Text(
        label,
        style: TidemarkTypography.label.copyWith(
          fontWeight: FontWeight.w600,
          color: context.colors.inkMuted,
        ),
      ),
    ),
  );

  Widget _entryTile(Entry entry) => Padding(
    padding: const EdgeInsets.fromLTRB(
      TidemarkSpacing.space4,
      0,
      TidemarkSpacing.space4,
      TidemarkSpacing.space2,
    ),
    child: _EntryCard(
      entry: entry,
      repository: widget.repository,
      downloader: widget.downloader,
      clock: widget.clock,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<Entry>>(
        stream: _entries,
        builder: (context, snapshot) {
          final entries = snapshot.data;
          if (entries != null && entries.isNotEmpty) _wiped = false;
          final now = widget.clock();
          final moment = dayMomentOf(now);
          final week = LocalWeek.containing(now);
          final loaded = !snapshot.hasError && entries != null;
          final hasEntries = loaded && entries.isNotEmpty;
          // Liste aplatie : intertitre de jour (String) ou entrée (Entry),
          // construite à la demande en défilant.
          final items = <Object>[
            if (hasEntries)
              for (final group in groupByDay(entries, now)) ...[
                group.label,
                ...group.entries,
              ],
          ];
          return CustomScrollView(
            slivers: [
              // En-tête, check-in et plage dans un même bloc : la scène de
              // l'en-tête descend sous le check-in, qui doit se peindre
              // par-dessus (un viewport peint ses slivers du dernier au
              // premier).
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    HomeHeader(
                      moment: moment,
                      onOpenSettings: _openSettings,
                      count: hasEntries
                          ? shellCountLabel(entriesInWeek(entries, week))
                          : null,
                      overlap: loaded ? homeHeaderOverlap : 0,
                    ),
                    if (snapshot.hasError)
                      const _ReadError()
                    else if (entries != null) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: TidemarkSpacing.space4,
                        ),
                        child: CheckInCard(
                          title: checkInTitleFor(moment),
                          onPick: (mood) => _openForm(mood: mood),
                        ),
                      ),
                      if (entries.isEmpty)
                        _EmptyState(wiped: _wiped)
                      else
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            TidemarkSpacing.space4,
                            TidemarkSpacing.space3,
                            TidemarkSpacing.space4,
                            0,
                          ),
                          child: BeachCard(
                            moods: dayMoodsOfWeek(entries, week),
                            onTap: _openWeek,
                          ),
                        ),
                    ],
                  ],
                ),
              ),
              SliverList.builder(
                itemCount: items.length,
                itemBuilder: (context, index) => switch (items[index]) {
                  final Entry entry => _entryTile(entry),
                  final label => _dayLabel(label as String),
                },
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height:
                      TidemarkSpacing.space6 +
                      MediaQuery.paddingOf(context).bottom,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Lecture impossible : ce qui s'est passé, sans rien effacer.
class _ReadError extends StatelessWidget {
  const _ReadError();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TidemarkSpacing.space4,
        TidemarkSpacing.space6,
        TidemarkSpacing.space4,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Ton journal n'a pas pu être lu",
            style: TidemarkTypography.headline.copyWith(color: colors.danger),
          ),
          const SizedBox(height: TidemarkSpacing.space1),
          const Text(
            "Tes entrées sont toujours sur le téléphone. Ferme l'app, puis rouvre-la.",
          ),
        ],
      ),
    );
  }
}

/// Journal vide, sous le check-in (spec 001, CA1 ; spec 007, CA4 ; spec 009, CA18).
class _EmptyState extends StatelessWidget {
  const _EmptyState({this.wiped = false});

  /// Message de fin d'une suppression totale au-dessus de l'état vide (CA18).
  final bool wiped;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: TidemarkSpacing.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (wiped) ...[
            const SizedBox(height: TidemarkSpacing.space4),
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
          // Logo décoratif, seulement tant que le journal est vide (spec 007, CA4).
          const Align(
            alignment: AlignmentDirectional.centerStart,
            child: TidemarkLogo(size: TidemarkSize.logoMd),
          ),
          const SizedBox(height: TidemarkSpacing.space4),
          Text('Ta première entrée apparaîtra ici', style: text.titleLarge),
          const SizedBox(height: TidemarkSpacing.space2),
          Text(
            'Note ton humeur en quelques secondes. Tout reste sur ton téléphone.',
            style: text.bodyLarge?.copyWith(color: colors.inkMuted),
          ),
        ],
      ),
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

  /// Thème clair des cartes, construit une fois pour toutes (spec 008, CA12).
  ///
  /// Figé pour toute la vie de l'app : `buildTidemarkTheme` ne dépend que de la
  /// luminosité, ici toujours claire. Si le thème venait à dépendre d'autre
  /// chose (taille de texte, réglage), il faudrait le reconstruire.
  static final _lightTheme = buildTidemarkTheme(Brightness.light);

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
    // Fond `mood-n-soft`, clair dans les deux thèmes : le contenu de la carte
    // prend les jetons du thème clair, texte en `on-mood` (spec 008, CA12).
    return Theme(
      data: _lightTheme,
      child: Builder(
        builder: (context) => _softCard(context, context.colors, text),
      ),
    );
  }

  Widget _softCard(BuildContext context, TidemarkColors colors, String? text) {
    return Material(
      color: colors.moodSoftColor(entry.mood),
      borderRadius: BorderRadius.circular(TidemarkRadius.radiusLg),
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
                  MoodBubble(mood: entry.mood, size: TidemarkSize.bubbleMd),
                  const SizedBox(width: TidemarkSpacing.space3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          moodLabel(entry.mood),
                          style: TidemarkTypography.headline.copyWith(
                            color: colors.onMood,
                          ),
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
                  style: TidemarkTypography.body.copyWith(color: colors.onMood),
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
