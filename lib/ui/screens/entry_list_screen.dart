import 'package:flutter/material.dart';

import '../../entries/day_grouping.dart';
import '../../entries/entry.dart';
import '../../entries/entry_repository.dart';
import '../../settings/settings_repository.dart';
import '../phone_dialer.dart';
import '../theme/tidemark_colors.dart';
import '../theme/tidemark_tokens.dart';
import '../theme/tidemark_typography.dart';
import '../widgets/mood_dot.dart';
import 'entry_detail_screen.dart';
import 'entry_form_screen.dart';
import 'settings_screen.dart';

/// Liste des entrées, écran d'accueil (spec 001).
class EntryListScreen extends StatefulWidget {
  const EntryListScreen({
    super.key,
    required this.repository,
    required this.settings,
    this.dialer = const UrlLauncherDialer(),
    required this.clock,
  });

  final EntryRepository repository;

  /// Réglages, ouverts par l'icône « Réglages » (spec 002).
  final SettingsRepository settings;

  /// Composeur, pour l'écran d'aide (spec 002).
  final PhoneDialer dialer;

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
      builder: (_) => EntryFormScreen(
        repository: widget.repository,
        settings: widget.settings,
        dialer: widget.dialer,
        clock: widget.clock,
      ),
    ),
  );

  void _openSettings() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => SettingsScreen(settings: widget.settings),
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
                      ? _ReadError(onOpenSettings: _openSettings)
                      : entries == null
                      ? _Loading(onOpenSettings: _openSettings)
                      : entries.isEmpty
                      ? _EmptyState(onOpenSettings: _openSettings)
                      : _EntryList(
                          onOpenSettings: _openSettings,
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
  const _EmptyState({required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: TidemarkSpacing.space4),
      children: [
        _Title(onOpenSettings: onOpenSettings),
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
    required this.onOpenSettings,
    required this.groups,
    required this.repository,
    required this.clock,
  });

  final VoidCallback onOpenSettings;
  final List<DayGroup> groups;
  final EntryRepository repository;
  final DateTime Function() clock;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: TidemarkSpacing.space4),
      children: [
        _Title(onOpenSettings: onOpenSettings),
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
