import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../entries/entry.dart';
import '../../entries/entry_repository.dart';
import '../../entries/week_summary.dart';
import '../../review/local_week.dart';
import '../../review/review_narrator.dart';
import '../../review/weekly_review.dart';
import '../../review/weekly_review_calculator.dart';
import '../theme/tidemark_colors.dart';
import '../theme/tidemark_tokens.dart';
import '../theme/tidemark_typography.dart';
import '../widgets/error_banner.dart';
import '../widgets/loading_note.dart';
import '../widgets/mood_bubble.dart';
import '../widgets/week_tide.dart';

/// Bilan de la semaine (spec 006), sur la semaine en cours : onglet « Semaine » de
/// `HomeShell` (spec 009), ou écran ouvert par-dessus la liste seule.
class WeeklyReviewScreen extends StatefulWidget {
  const WeeklyReviewScreen({
    super.key,
    required this.repository,
    required this.narrator,
    required this.clock,
    this.showBack = true,
  });

  /// Retour « Journal » en tête (spec 006, CA4) : écran ouvert par-dessus la liste.
  /// Faux dans l'onglet « Semaine », où la barre de navigation le remplace et où
  /// les chiffres clés sont des autocollants (spec 009, CA23, CA25).
  final bool showBack;

  final EntryRepository repository;

  /// Mise en mots et mémoire des textes (RM54), partagée par toute l'app.
  final ReviewNarrator narrator;

  /// Date et heure locales : semaine en cours.
  final DateTime Function() clock;

  @override
  State<WeeklyReviewScreen> createState() => _WeeklyReviewScreenState();
}

/// Ce qui déclenche une nouvelle mise en mots : la semaine, ses faits, sa
/// sensibilité (CA17, CA34).
typedef _NarrationKey = ({LocalWeek week, ReviewFacts facts, bool sensitive});

class _WeeklyReviewScreenState extends State<WeeklyReviewScreen> {
  static const _calculator = WeeklyReviewCalculator();

  late Stream<List<Entry>> _entries = widget.repository.watchEntries();
  late final LocalWeek _current = LocalWeek.containing(widget.clock());
  late LocalWeek _week = _current;

  _NarrationKey? _narrationKey;
  Narration? _narration;

  /// Numéro de la dernière requête au rédacteur : seule sa réponse s'applique,
  /// même si une requête plus ancienne portait la même clé (aller-retour).
  int _request = 0;

  /// Vrai tant que la requête [_request] attend sa réponse.
  bool _writing = false;

  @override
  void dispose() {
    // La personne quitte l'écran : la génération est abandonnée, rien n'est
    // gardé (spec 006, « Cas limites »).
    if (_writing) widget.narrator.cancel();
    super.dispose();
  }

  void _retry() => setState(() => _entries = widget.repository.watchEntries());

  void _showWeek(LocalWeek week) => setState(() => _week = week);

  /// Met à jour la mise en mots pour [review] ; appelé pendant la construction,
  /// sans `setState` : seul le résultat du rédacteur, plus tard, en demande un.
  Narration _narrationFor(ComputedWeek review) {
    final key = (
      week: review.week,
      facts: review.facts,
      sensitive: review.isSensitive,
    );
    final current = _narration;
    if (key == _narrationKey && current != null) return current;
    _stopNarration();
    _narrationKey = key;
    final now = widget.narrator.immediate(review);
    _narration = now;
    if (now is NarrationWriting) {
      final request = ++_request;
      _writing = true;
      widget.narrator.narrate(review).then((result) {
        if (!mounted || request != _request) return;
        setState(() {
          _writing = false;
          _narration = result;
        });
      });
    }
    return now;
  }

  /// Abandonne la mise en mots en cours, s'il y en a une ; sa réponse, si elle
  /// arrive, est ignorée.
  void _stopNarration() {
    if (_writing) widget.narrator.cancel();
    _writing = false;
    _request++;
    _narration = null;
    _narrationKey = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<Entry>>(
        stream: _entries,
        builder: (context, snapshot) {
          final entries = snapshot.data;
          final oldest = entries == null || entries.isEmpty
              ? _current
              : entries
                    .map(weekOfEntry)
                    .reduce((a, b) => a.compareTo(b) <= 0 ? a : b);
          return ListView(
            padding: EdgeInsets.only(
              bottom:
                  TidemarkSpacing.space6 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              _Header(
                week: _week,
                current: _current,
                currentYear: widget.clock().year,
                showBack: widget.showBack,
                moods: snapshot.hasError || entries == null
                    ? null
                    : dayMoodsOfWeek(entries, _week),
                onPrevious: _week.compareTo(oldest) > 0
                    ? () => _showWeek(_week.previous)
                    : null,
                onNext: _week.compareTo(_current) < 0
                    ? () => _showWeek(_week.next)
                    : null,
              ),
              const SizedBox(height: TidemarkSpacing.space4),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: TidemarkSpacing.space4,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _body(context, snapshot, entries),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _body(
    BuildContext context,
    AsyncSnapshot<List<Entry>> snapshot,
    List<Entry>? entries,
  ) {
    if (snapshot.hasError) {
      _stopNarration();
      return [
        const ErrorBanner(
          title: "Ton bilan n'a pas pu être calculé",
          message:
              "Tes entrées sont toujours sur le téléphone. Rien n'a été effacé. "
              'Réessaie.',
        ),
        const SizedBox(height: TidemarkSpacing.space4),
        FilledButton(onPressed: _retry, child: const Text('Réessayer')),
      ];
    }
    if (entries == null) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: TidemarkSpacing.space4),
          child: LoadingNote(text: 'Calcul du bilan sur ton téléphone…'),
        ),
      ];
    }
    final review = _calculator.compute(
      week: _week,
      entries: entries,
      tagsByEntry: {for (final e in entries) e.id: e.tags},
    );
    switch (review) {
      case InsufficientWeek(:final entryCount):
        _stopNarration();
        return [_InsufficientCard(entryCount: entryCount)];
      case ComputedWeek():
        return _computed(review, _narrationFor(review));
    }
  }

  List<Widget> _computed(ComputedWeek review, Narration narration) {
    const gap = SizedBox(height: TidemarkSpacing.space4);
    final comparison = review.comparison;
    if (!widget.showBack) {
      // Onglet « Semaine » : les chiffres clés en autocollants, en tête (spec 009,
      // CA25), puis les sections de la spec 006.
      return [
        _StatStickers(review: review),
        gap,
        _NarrationCard(narration: narration),
        if (comparison != null) ...[
          gap,
          _ComparisonCard(review: review, comparison: comparison),
        ],
        gap,
        _Distribution(moodCounts: review.moodCounts),
        gap,
        _NotedDays(notedDays: review.notedDays, withTitle: false),
        gap,
        _TopTags(topTags: review.topTags),
      ];
    }
    return [
      _NarrationCard(narration: narration),
      gap,
      _KeyFigures(review: review),
      if (comparison != null) ...[
        gap,
        _ComparisonCard(review: review, comparison: comparison),
      ],
      gap,
      _Distribution(moodCounts: review.moodCounts),
      gap,
      _NotedDays(notedDays: review.notedDays),
      gap,
      _TopTags(topTags: review.topTags),
    ];
  }
}

/// « 1 entrée », « 3 entrées » (0 au singulier, comme 1).
String _entries(int count) => '$count ${count > 1 ? 'entrées' : 'entrée'}';

/// « 1 jour », « 5 jours ».
String _days(int count) => '$count ${count > 1 ? 'jours' : 'jour'}';

const _weekdayNames = [
  'lundi',
  'mardi',
  'mercredi',
  'jeudi',
  'vendredi',
  'samedi',
  'dimanche',
];

const _weekdayLetters = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

/// En-tête `sky` : retour, titre, semaine affichée et flèches (spec 006, CA4, CA5,
/// CA31), puis la marée de la semaine (spec 009, CA24).
class _Header extends StatelessWidget {
  const _Header({
    required this.week,
    required this.current,
    required this.currentYear,
    required this.showBack,
    required this.moods,
    required this.onPrevious,
    required this.onNext,
  });

  final LocalWeek week;
  final LocalWeek current;

  /// Année du jour (CA4), pas celle du dimanche de la semaine en cours.
  final int currentYear;

  /// Retour « Journal » (absent dans l'onglet, spec 009, CA23).
  final bool showBack;

  /// Humeur du jour de la semaine affichée ; `null` pendant la lecture ou en cas
  /// d'erreur.
  final List<int?>? moods;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final caption = weekCaption(week, current: current);
    final range = weekRangeLabel(week, currentYear: currentYear);
    return ColoredBox(
      color: colors.sky,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 120,
            child: ExcludeSemantics(
              child: CustomPaint(
                painter: _SkyPainter(
                  sun: colors.sun,
                  gull: colors.onSky.withValues(alpha: 0.5),
                  top: MediaQuery.paddingOf(context).top,
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  TidemarkSpacing.space4,
                  MediaQuery.paddingOf(context).top + TidemarkSpacing.space4,
                  TidemarkSpacing.space4,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (showBack) ...[
                      // Le titre est annoncé en premier, avant le retour (CA31).
                      Semantics(
                        sortKey: const OrdinalSortKey(1),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => Navigator.of(context).maybePop(),
                            icon: const Icon(
                              Icons.chevron_left,
                              size: TidemarkSize.iconMd,
                            ),
                            label: const Text('Journal'),
                          ),
                        ),
                      ),
                      const SizedBox(height: TidemarkSpacing.space4),
                    ],
                    Semantics(
                      sortKey: const OrdinalSortKey(0),
                      header: true,
                      child: Text(
                        'Ta semaine',
                        style: TidemarkTypography.display.copyWith(
                          color: colors.onSky,
                        ),
                      ),
                    ),
                    const SizedBox(height: TidemarkSpacing.space2),
                    Semantics(
                      sortKey: const OrdinalSortKey(2),
                      explicitChildNodes: true,
                      child: Row(
                        children: [
                          _WeekArrow(
                            label: 'Semaine précédente',
                            icon: Icons.chevron_left,
                            onPressed: onPrevious,
                          ),
                          const SizedBox(width: TidemarkSpacing.space2),
                          Expanded(
                            // Un changement de semaine annonce les nouvelles
                            // dates (CA31).
                            child: Semantics(
                              liveRegion: true,
                              container: true,
                              child: Column(
                                children: [
                                  Text(
                                    range,
                                    textAlign: TextAlign.center,
                                    style: TidemarkTypography.headline.copyWith(
                                      color: colors.onSky,
                                    ),
                                  ),
                                  if (caption != null)
                                    Text(
                                      caption,
                                      textAlign: TextAlign.center,
                                      style: TidemarkTypography.caption
                                          .copyWith(color: colors.onSky),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: TidemarkSpacing.space2),
                          _WeekArrow(
                            label: 'Semaine suivante',
                            icon: Icons.chevron_right,
                            onPressed: onNext,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: TidemarkSpacing.space2),
              Semantics(
                sortKey: const OrdinalSortKey(3),
                child: WeekTide(moods: moods),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Soleil et mouettes du ciel de l'en-tête (maquette), décoratifs.
class _SkyPainter extends CustomPainter {
  const _SkyPainter({required this.sun, required this.gull, required this.top});

  final Color sun;
  final Color gull;

  /// Hauteur de la barre d'état, au-dessus du dessin.
  final double top;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
      Offset(size.width - 53, top + 34),
      22,
      Paint()..color = sun,
    );
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = gull;
    for (final (x, y, s) in [
      (size.width - 150.0, top + 24.0, 5.0),
      (size.width - 122.0, top + 40.0, 4.0),
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(x, y)
          ..relativeQuadraticBezierTo(s, -s, 2 * s, 0)
          ..relativeQuadraticBezierTo(s, -s, 2 * s, 0),
        stroke,
      );
    }
  }

  @override
  bool shouldRepaint(_SkyPainter old) =>
      old.sun != sun || old.gull != gull || old.top != top;
}

/// Flèche de semaine : `tide`, ou `line` désactivée (maquette).
class _WeekArrow extends StatelessWidget {
  const _WeekArrow({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      container: true,
      button: true,
      enabled: onPressed != null,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: IconButton(
        onPressed: onPressed,
        tooltip: label,
        color: colors.tide,
        disabledColor: colors.line,
        constraints: const BoxConstraints.tightFor(
          width: TidemarkSize.tapMin,
          height: TidemarkSize.tapMin,
        ),
        icon: Icon(icon, size: TidemarkSize.iconMd),
      ),
    );
  }
}

/// Carte posée sur `surface` (charte : `surface-raised`, `radius-md`).
class _Card extends StatelessWidget {
  const _Card({required this.child, this.gap = TidemarkSpacing.space2});

  final List<Widget> child;
  final double gap;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.colors.surfaceRaised,
      borderRadius: BorderRadius.circular(TidemarkRadius.radiusLg),
    ),
    child: Padding(
      padding: const EdgeInsets.all(TidemarkSpacing.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: gap,
        children: child,
      ),
    ),
  );
}

/// Titre d'une section du bilan.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(text, style: TidemarkTypography.headline),
  );
}

/// Moins de 3 entrées (CA6).
class _InsufficientCard extends StatelessWidget {
  const _InsufficientCard({required this.entryCount});

  final int entryCount;

  @override
  Widget build(BuildContext context) {
    final count = switch (entryCount) {
      0 => "celle-ci n'en compte aucune.",
      _ => 'celle-ci en compte $entryCount.',
    };
    return _Card(
      child: [
        Text(
          'Pas encore de bilan pour cette semaine',
          style: TidemarkTypography.headline,
        ),
        Text(
          'Le bilan demande au moins 3 entrées dans la semaine ; $count',
          style: TidemarkTypography.body.copyWith(
            color: context.colors.inkMuted,
          ),
        ),
      ],
    );
  }
}

/// Texte du bilan, ou ce qui en tient lieu (CA18 à CA20, CA22, CA27).
class _NarrationCard extends StatelessWidget {
  const _NarrationCard({required this.narration});

  final Narration narration;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final muted = TidemarkTypography.body.copyWith(color: colors.inkMuted);
    final caption = TidemarkTypography.caption.copyWith(color: colors.inkMuted);
    return _Card(
      child: switch (narration) {
        NarrationWriting() => [
          const LoadingNote(text: 'Mise en mots sur ton téléphone…'),
          Text('Les chiffres ci-dessous sont déjà complets.', style: caption),
        ],
        NarrationText(:final text) => [
          Text(text, style: TidemarkTypography.body),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.lock_outline,
                size: TidemarkSize.iconSm,
                color: colors.inkMuted,
              ),
              const SizedBox(width: TidemarkSpacing.space1),
              Expanded(
                child: Text(
                  'Mis en mots sur ton téléphone, à partir des chiffres '
                  'ci-dessous',
                  style: caption,
                ),
              ),
            ],
          ),
        ],
        NarrationWithheld() => [
          Text(
            "Pas de texte pour cette semaine : le bilan s'en tient aux "
            'chiffres.',
            style: muted,
          ),
        ],
        NarrationModelMissing() => [
          Text(
            "Pas de texte : le modèle local n'est pas sur ce téléphone. Les "
            'chiffres sont calculés sans lui.',
            style: muted,
          ),
        ],
      },
    );
  }
}

/// Entrées et humeur moyenne (CA8, CA9, CA11).
class _KeyFigures extends StatelessWidget {
  const _KeyFigures({required this.review});

  final ComputedWeek review;

  @override
  Widget build(BuildContext context) {
    final days = review.notedDays.length;
    final average = formatTenths(review.averageMoodTenths);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _Figure(
              title: 'Entrées',
              value: '${review.entryCount}',
              note: 'sur ${_days(days)}',
              semantics: 'Entrées : ${review.entryCount} sur ${_days(days)}',
            ),
          ),
          const SizedBox(width: TidemarkSpacing.space3),
          Expanded(
            child: _Figure(
              title: 'Humeur moyenne',
              value: average,
              note: 'sur 5',
              semantics: 'Humeur moyenne : $average sur 5',
            ),
          ),
        ],
      ),
    );
  }
}

/// Chiffre clé, lu d'un bloc (CA31).
class _Figure extends StatelessWidget {
  const _Figure({
    required this.title,
    required this.value,
    required this.note,
    required this.semantics,
  });

  final String title;
  final String value;
  final String note;
  final String semantics;

  @override
  Widget build(BuildContext context) {
    final caption = TidemarkTypography.caption.copyWith(
      color: context.colors.inkMuted,
    );
    return Semantics(
      container: true,
      label: semantics,
      excludeSemantics: true,
      child: _Card(
        gap: TidemarkSpacing.space1,
        child: [
          Text(title, style: caption),
          Text(value, style: TidemarkTypography.title),
          Text(note, style: caption),
        ],
      ),
    );
  }
}

/// Chiffres clés de l'onglet « Semaine » en autocollants (spec 009, CA25) :
/// humeur moyenne, jours notés, entrées, valeurs de `WeeklyReviewCalculator`.
class _StatStickers extends StatelessWidget {
  const _StatStickers({required this.review});

  final ComputedWeek review;

  /// Rotations fixes, de gauche à droite (maquette) : décroissantes, pour que les
  /// libellés se lisent dans l'ordre, de gauche à droite.
  static const _angles = [1.5, -0.5, -2.0];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final days = review.notedDays.length;
    final average = formatTenths(review.averageMoodTenths);
    final stickers = [
      _StatSticker(
        value: Text(average),
        label: 'Humeur moyenne',
        semantics: 'Humeur moyenne : $average sur 5',
        background: colors.mood2Soft,
        angle: _angles[0],
      ),
      _StatSticker(
        value: Text.rich(
          TextSpan(
            text: '$days',
            children: [
              TextSpan(
                text: '/7',
                style: TidemarkTypography.headline.copyWith(
                  fontWeight: FontWeight.w800,
                  fontVariations: const [FontVariation.weight(800)],
                ),
              ),
            ],
          ),
        ),
        label: 'Jours notés',
        semantics: 'Jours notés : ${_days(days)} sur 7',
        background: colors.mood3Soft,
        angle: _angles[1],
      ),
      _StatSticker(
        value: Text('${review.entryCount}'),
        label: 'Entrées',
        semantics: 'Entrées : ${review.entryCount} sur ${_days(days)}',
        background: colors.mood5Soft,
        angle: _angles[2],
      ),
    ];
    // Côte à côte si chaque chiffre et chaque mot des libellés tiennent dans un
    // tiers de la largeur, à la taille de texte choisie ; sinon un autocollant
    // par ligne, pour que rien ne se coupe ni ne rétrécisse (CA27).
    final scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        final inner =
            (constraints.maxWidth - 2 * gap) / 3 - 2 * TidemarkSpacing.space3;
        final widest = [
          for (final v in [average, '$days/7', '${review.entryCount}'])
            _textWidth(v, TidemarkTypography.stat, scaler),
          for (final label in ['Humeur moyenne', 'Jours notés', 'Entrées'])
            for (final word in label.split(' '))
              _textWidth(word, _StatSticker.labelStyle, scaler),
        ].reduce(math.max);
        if (widest > inner) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: TidemarkSpacing.space3,
            children: stickers,
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: gap,
            children: [for (final s in stickers) Expanded(child: s)],
          ),
        );
      },
    );
  }

  /// Largeur de [text] en [style], à l'échelle [scaler].
  static double _textWidth(String text, TextStyle style, TextScaler scaler) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }
}

/// Autocollant d'un chiffre clé (spec 008, « Autocollant ») : fond `mood-n-soft`,
/// texte `on-mood`, légère rotation fixe, lu d'un bloc (CA31).
class _StatSticker extends StatelessWidget {
  const _StatSticker({
    required this.value,
    required this.label,
    required this.semantics,
    required this.background,
    required this.angle,
  });

  final Widget value;
  final String label;
  final String semantics;
  final Color background;

  /// Rotation, en degrés.
  final double angle;

  /// Style du libellé, sans couleur.
  static final labelStyle = TidemarkTypography.caption.copyWith(
    fontWeight: FontWeight.w600,
    fontVariations: const [FontVariation.weight(600)],
  );

  @override
  Widget build(BuildContext context) {
    final ink = context.colors.onMood;
    return Semantics(
      container: true,
      label: semantics,
      excludeSemantics: true,
      child: Transform.rotate(
        angle: angle * math.pi / 180,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(TidemarkRadius.radiusLg),
            boxShadow: TidemarkShadows.shadowSticker,
          ),
          child: Padding(
            padding: const EdgeInsets.all(TidemarkSpacing.space3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                // Jamais rétréci : la mise en page passe en colonne avant
                // (CA27).
                DefaultTextStyle(
                  style: TidemarkTypography.stat.copyWith(color: ink),
                  child: value,
                ),
                Text(label, style: labelStyle.copyWith(color: ink)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Évolution par rapport à la semaine précédente (CA14).
class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard({required this.review, required this.comparison});

  final ComputedWeek review;
  final WeekComparison comparison;

  @override
  Widget build(BuildContext context) {
    final diff = review.averageMoodTenths - comparison.averageMoodTenths;
    final evolution = diff > 0
        ? 'En hausse de ${formatTenths(diff)}.'
        : diff < 0
        ? 'En baisse de ${formatTenths(-diff)}.'
        : 'Stable.';
    return _Card(
      child: [
        const _SectionTitle('Par rapport à la semaine précédente'),
        Text(
          'Humeur moyenne : ${formatTenths(review.averageMoodTenths)}, contre '
          '${formatTenths(comparison.averageMoodTenths)}. $evolution',
          style: TidemarkTypography.body,
        ),
        Text(
          'Entrées : ${review.entryCount}, contre ${comparison.entryCount}.',
          style: TidemarkTypography.body,
        ),
      ],
    );
  }
}

/// Répartition des humeurs (CA10, CA31, CA33) : annoncée en une phrase, barres
/// ignorées par le lecteur d'écran.
class _Distribution extends StatelessWidget {
  const _Distribution({required this.moodCounts});

  final List<int> moodCounts;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final max = moodCounts.fold(1, (m, c) => c > m ? c : m);
    final sentence =
        'Répartition des humeurs : '
        '${[for (var i = 0; i < 5; i++) '${moodLabel(i + 1)}, ${_entries(moodCounts[i])}'].join(' ; ')}.';
    return _Card(
      gap: TidemarkSpacing.space3,
      child: [
        const _SectionTitle('Répartition des humeurs'),
        Semantics(
          container: true,
          label: sentence,
          excludeSemantics: true,
          child: Column(
            spacing: TidemarkSpacing.space2,
            children: [
              for (var mood = 1; mood <= 5; mood++)
                Row(
                  children: [
                    MoodBubble(mood: mood, size: TidemarkSize.bubbleSm),
                    const SizedBox(width: TidemarkSpacing.space3),
                    // Le libellé passe à la ligne à 200 % (CA32).
                    Expanded(
                      flex: 2,
                      child: Text(
                        moodLabel(mood),
                        style: TidemarkTypography.label,
                      ),
                    ),
                    const SizedBox(width: TidemarkSpacing.space3),
                    Expanded(
                      flex: 3,
                      child: _Bar(
                        fraction: moodCounts[mood - 1] / max,
                        color: colors.moodColor(mood),
                        track: colors.surface,
                      ),
                    ),
                    const SizedBox(width: TidemarkSpacing.space3),
                    Text(
                      '${moodCounts[mood - 1]}',
                      style: TidemarkTypography.label,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Barre proportionnelle au plus grand nombre (CA10).
class _Bar extends StatelessWidget {
  const _Bar({
    required this.fraction,
    required this.color,
    required this.track,
  });

  final double fraction;
  final Color color;
  final Color track;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(TidemarkRadius.radiusPill);
    return SizedBox(
      height: TidemarkSize.barThickness,
      child: DecoratedBox(
        decoration: BoxDecoration(color: track, borderRadius: radius),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: fraction,
            heightFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(color: color, borderRadius: radius),
            ),
          ),
        ),
      ),
    );
  }
}

/// Jours notés (CA11, CA31).
class _NotedDays extends StatelessWidget {
  const _NotedDays({required this.notedDays, this.withTitle = true});

  final List<int> notedDays;

  /// Titre « Jours notés » et « N jours sur 7 » ; faux dans l'onglet, où
  /// l'autocollant « Jours notés » les donne déjà (spec 009, CA25).
  final bool withTitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sentence =
        'Jours notés : ${[for (final d in notedDays) _weekdayNames[d - 1]].join(', ')}.';
    return _Card(
      gap: TidemarkSpacing.space3,
      child: [
        if (withTitle)
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: TidemarkSpacing.space2,
            children: [
              const _SectionTitle('Jours notés'),
              Text(
                '${_days(notedDays.length)} sur 7',
                style: TidemarkTypography.caption.copyWith(
                  color: colors.inkMuted,
                ),
              ),
            ],
          ),
        Semantics(
          container: true,
          label: sentence,
          excludeSemantics: true,
          child: Row(
            spacing: TidemarkSpacing.space1,
            children: [
              for (var day = 1; day <= 7; day++)
                Expanded(
                  child: _DayCell(
                    letter: _weekdayLetters[day - 1],
                    noted: notedDays.contains(day),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Case d'un jour : `tide-soft` si noté, bordure pointillée `line` sinon.
class _DayCell extends StatelessWidget {
  const _DayCell({required this.letter, required this.noted});

  final String letter;
  final bool noted;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Text(
      letter,
      style: TidemarkTypography.label.copyWith(
        color: noted ? colors.ink : colors.inkMuted,
        fontWeight: noted ? FontWeight.w600 : null,
      ),
    );
    final radius = BorderRadius.circular(TidemarkRadius.radiusSm);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: TidemarkSize.dayCell),
      child: noted
          ? DecoratedBox(
              decoration: BoxDecoration(
                color: colors.tideSoft,
                borderRadius: radius,
              ),
              child: Center(child: text),
            )
          : CustomPaint(
              painter: _DashedBorder(color: colors.line, radius: radius),
              child: Center(child: text),
            ),
    );
  }
}

/// Bordure pointillée d'une case de jour non noté (maquette).
class _DashedBorder extends CustomPainter {
  const _DashedBorder({required this.color, required this.radius});

  final Color color;
  final BorderRadius radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()
      ..addRRect(radius.toRRect(Offset.zero & size).deflate(0.5));
    const dash = TidemarkSpacing.space1;
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 2 * dash) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) =>
      old.color != color || old.radius != radius;
}

/// Étiquettes fréquentes (CA12, CA13, CA31).
class _TopTags extends StatelessWidget {
  const _TopTags({required this.topTags});

  final List<TagCount> topTags;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return _Card(
      gap: TidemarkSpacing.space3,
      child: [
        const _SectionTitle('Étiquettes fréquentes'),
        if (topTags.isEmpty)
          Text(
            'Aucune étiquette cette semaine.',
            style: TidemarkTypography.body.copyWith(color: colors.inkMuted),
          )
        else
          Wrap(
            spacing: TidemarkSpacing.space2,
            runSpacing: TidemarkSpacing.space2,
            children: [for (final t in topTags) _CountChip(tagCount: t)],
          ),
        Text(
          'Analysé sur ton téléphone',
          style: TidemarkTypography.caption.copyWith(color: colors.inkMuted),
        ),
      ],
    );
  }
}

/// Puce « fatigue · 3 », annoncée « fatigue, 3 entrées » (charte : `TagChip`).
class _CountChip extends StatelessWidget {
  const _CountChip({required this.tagCount});

  final TagCount tagCount;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final label = tagCount.tag.label;
    return Semantics(
      container: true,
      label: '$label, ${_entries(tagCount.count)}',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.tideSoft,
          borderRadius: BorderRadius.circular(TidemarkRadius.radiusPill),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: TidemarkSpacing.space3,
            vertical: TidemarkSpacing.space1,
          ),
          child: Text.rich(
            TextSpan(
              text: '$label ',
              children: [
                TextSpan(
                  text: '· ${tagCount.count}',
                  style: TextStyle(color: colors.inkMuted),
                ),
              ],
            ),
            style: TidemarkTypography.label.copyWith(color: colors.ink),
          ),
        ),
      ),
    );
  }
}
