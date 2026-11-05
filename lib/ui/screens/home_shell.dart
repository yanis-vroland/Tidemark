import 'package:flutter/material.dart';

import '../../entries/entry_repository.dart';
import '../../model/model_downloader.dart';
import '../../review/review_narrator.dart';
import '../../review/review_writer.dart';
import '../../settings/settings_repository.dart';
import '../phone_dialer.dart';
import '../theme/tidemark_colors.dart';
import '../theme/tidemark_tokens.dart';
import '../theme/tidemark_typography.dart';
import '../widgets/my_data_section.dart';
import 'entry_form_screen.dart';
import 'entry_list_screen.dart';
import 'weekly_review_screen.dart';

/// Accueil à deux onglets (spec 009, CA19 à CA23) : « Journal » (la liste) et
/// « Semaine » (le bilan, sans retour), avec la barre de navigation et sa bulle
/// « Nouvelle entrée ». Chaque onglet garde son état (CA21) ; les écrans ouverts
/// par-dessus couvrent la barre (CA22).
class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.repository,
    required this.settings,
    required this.downloader,
    required this.clock,
    this.dialer = const UrlLauncherDialer(),
    this.narrator,
    this.data,
    this.wiped = false,
  });

  final EntryRepository repository;
  final SettingsRepository settings;
  final ModelDownloader downloader;

  /// Date et heure locales.
  final DateTime Function() clock;
  final PhoneDialer dialer;

  /// Mise en mots du bilan (spec 006) ; `null` : bilan sans texte.
  final ReviewNarrator? narrator;

  /// Export et suppression totale, dans les Réglages (spec 005).
  final DataActions? data;

  /// Une suppression totale vient de réussir : message de fin sur la liste.
  final bool wiped;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

enum _Tab { journal, week }

class _HomeShellState extends State<HomeShell> {
  var _tab = _Tab.journal;

  /// Change quand la plage est touchée : l'onglet « Semaine » repart alors de la
  /// semaine en cours (CA16) ; la barre, elle, le rend tel qu'il a été laissé
  /// (CA21).
  var _weekGeneration = 0;

  /// L'onglet « Semaine » n'est construit qu'à sa première ouverture : rien n'est
  /// calculé ni mis en mots pour un onglet jamais vu.
  var _weekBuilt = false;

  late final ReviewNarrator _narrator =
      widget.narrator ??
      ReviewNarrator(
        writer: const NoReviewWriter(),
        downloader: widget.downloader,
      );

  void _select(_Tab tab) => setState(() {
    _tab = tab;
    if (tab == _Tab.week) _weekBuilt = true;
  });

  void _openCurrentWeek() => setState(() {
    if (_weekBuilt) _weekGeneration++;
    _weekBuilt = true;
    _tab = _Tab.week;
  });

  void _openForm() => Navigator.of(context).push(
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

  @override
  Widget build(BuildContext context) {
    final tabs = {
      _Tab.journal: EntryListScreen(
        repository: widget.repository,
        settings: widget.settings,
        downloader: widget.downloader,
        dialer: widget.dialer,
        clock: widget.clock,
        data: widget.data,
        wiped: widget.wiped,
        narrator: _narrator,
        onOpenWeek: _openCurrentWeek,
      ),
      _Tab.week: _weekBuilt
          ? WeeklyReviewScreen(
              key: ValueKey(_weekGeneration),
              repository: widget.repository,
              narrator: _narrator,
              clock: widget.clock,
              showBack: false,
            )
          : const SizedBox.shrink(),
    };
    return Material(
      color: context.colors.surface,
      child: Column(
        children: [
          Expanded(
            // La barre tient compte du bas de l'écran ; les onglets non.
            child: MediaQuery.removePadding(
              context: context,
              removeBottom: true,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  for (final MapEntry(key: tab, value: screen) in tabs.entries)
                    // Onglet caché : gardé en vie (défilement, semaine
                    // affichée), sans animation, ni toucher, ni annonce.
                    Offstage(
                      offstage: tab != _tab,
                      child: TickerMode(enabled: tab == _tab, child: screen),
                    ),
                ],
              ),
            ),
          ),
          _NavBar(current: _tab, onSelect: _select, onCreate: _openForm),
        ],
      ),
    );
  }
}

/// Barre de navigation (spec 009, CA19 ; maquette `TabBar`) : « Journal », la
/// bulle `nav-bubble` « Nouvelle entrée » au centre, « Semaine ».
class _NavBar extends StatelessWidget {
  const _NavBar({
    required this.current,
    required this.onSelect,
    required this.onCreate,
  });

  final _Tab current;
  final ValueChanged<_Tab> onSelect;
  final VoidCallback onCreate;

  /// Hauteur dont la bulle dépasse au-dessus de la barre.
  static const _bubbleRise = 26.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Stack(
      children: [
        Positioned.fill(
          top: _bubbleRise,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surfaceRaised,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(TidemarkRadius.radiusXl),
              ),
              boxShadow: TidemarkShadows.shadowCard,
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            TidemarkSpacing.space4,
            0,
            TidemarkSpacing.space4,
            TidemarkSpacing.space3 + bottom,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _TabButton(
                  label: 'Journal',
                  icon: Icons.menu_book_outlined,
                  selected: current == _Tab.journal,
                  onTap: () => onSelect(_Tab.journal),
                ),
              ),
              SizedBox(width: 108, child: _CreateButton(onTap: onCreate)),
              Expanded(
                child: _TabButton(
                  label: 'Semaine',
                  icon: Icons.show_chart,
                  selected: current == _Tab.week,
                  onTap: () => onSelect(_Tab.week),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Onglet de la barre, annoncé comme un bouton, sélectionné ou non (CA19).
class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = selected ? colors.ink : colors.inkMuted;
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: selected
            ? colors.tideSoft
            : colors.surfaceRaised.withValues(alpha: 0),
        borderRadius: BorderRadius.circular(TidemarkRadius.radiusPill),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: TidemarkSpacing.space2,
                vertical: TidemarkSpacing.space1,
              ),
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                runAlignment: WrapAlignment.center,
                spacing: TidemarkSpacing.space2,
                children: [
                  Icon(icon, size: TidemarkSize.iconMd, color: color),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TidemarkTypography.label.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontVariations: const [FontVariation.weight(700)],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bulle « + » au centre de la barre, avec le libellé « Nouvelle entrée » (CA19,
/// CA20).
class _CreateButton extends StatelessWidget {
  const _CreateButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      container: true,
      button: true,
      label: 'Nouvelle entrée',
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.tide,
                shape: BoxShape.circle,
                border: Border.all(color: colors.surfaceRaised, width: 6),
                boxShadow: TidemarkShadows.shadowCard,
              ),
              child: SizedBox.square(
                dimension: TidemarkSize.navBubble,
                child: Icon(
                  Icons.add,
                  size: TidemarkSize.iconMd + 4,
                  color: colors.onTide,
                ),
              ),
            ),
            const SizedBox(height: TidemarkSpacing.space1),
            Text(
              'Nouvelle entrée',
              textAlign: TextAlign.center,
              style: TidemarkTypography.caption.copyWith(
                color: colors.ink,
                fontWeight: FontWeight.w700,
                fontVariations: const [FontVariation.weight(700)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
