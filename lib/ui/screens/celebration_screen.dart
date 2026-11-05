import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../entries/entry.dart';
import '../../entries/entry_repository.dart';
import '../../entries/week_summary.dart';
import '../../model/model_downloader.dart';
import '../../model/model_state.dart';
import '../../review/local_week.dart';
import '../../settings/settings_repository.dart';
import '../motion/ambient_motion.dart';
import '../theme/tidemark_colors.dart';
import '../theme/tidemark_tokens.dart';
import '../theme/tidemark_typography.dart';
import '../widgets/shell_painter.dart';
import '../widgets/sticker.dart';
import 'model_download_screen.dart';

/// Titre de la célébration complète (spec 010, CA12).
const celebrationTitle = 'Coquillage ramassé';

/// Titre et phrase de la célébration douce (CA13).
const softCelebrationTitle = 'Entrée enregistrée';
const softCelebrationLine = 'Elle rejoint ta plage.';

/// Phrase quand les entrées de la semaine ne peuvent pas être lues (CA17).
const fallbackCelebrationLine = 'Il rejoint ta plage.';

/// Nombre de coquillages montrés dans la rangée avant « +N » (CA12).
const maxShellsInRow = 7;

/// Phrase de la célébration complète pour la [rank]-ième entrée de la semaine.
String shellRankLine(int rank) => rank == 1
    ? 'Ton 1er de la semaine. Il ouvre ta plage.'
    : 'Ton ${rank}e de la semaine. Il rejoint ta plage, à côté des autres.';

/// Durée de l'apparition du coquillage (CA12).
const _popDuration = Duration(milliseconds: 700);

/// Période de montée d'une bulle d'air (maquette `Enregistre`).
const _airPeriod = Duration(seconds: 8);

/// Coquillage ramassé (spec 010, CA12 à CA20) : remplace la saisie après un
/// enregistrement réussi sans détresse. Complète pour une humeur de 3 à 5, douce
/// pour 1 et 2 (jamais de fête pour un jour difficile). « Continuer » et le geste de
/// retour ouvrent la proposition du modèle si elle doit s'ouvrir (RM31), sinon
/// ramènent à l'accueil.
class CelebrationScreen extends StatefulWidget {
  const CelebrationScreen({
    super.key,
    required this.entry,
    required this.repository,
    required this.settings,
    required this.downloader,
  });

  /// L'entrée qui vient d'être enregistrée.
  final Entry entry;
  final EntryRepository repository;
  final SettingsRepository settings;
  final ModelDownloader downloader;

  /// Célébration complète : humeur de 3 à 5 (CA12) ; sinon douce (CA13).
  bool get festive => entry.mood >= 3;

  @override
  State<CelebrationScreen> createState() => _CelebrationScreenState();
}

class _CelebrationScreenState extends State<CelebrationScreen>
    with TickerProviderStateMixin {
  /// Humeurs de la semaine de l'entrée, de la plus ancienne à la plus récente ;
  /// lues une fois (célébration complète seulement).
  Future<List<int>>? _week;

  /// Apparition du coquillage, animation finie (célébration complète).
  AnimationController? _pop;

  /// Bulles d'air, en ambiance seulement (spec 008, « Mouvement »).
  AnimationController? _air;

  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.festive) _week = _readWeek();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.festive) return;
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final pop = _pop ??= AnimationController(
      vsync: this,
      duration: _popDuration,
    );
    if (reduce) {
      // Réduire les animations : le coquillage est là d'emblée (CA19).
      pop.value = 1;
    } else if (pop.isDismissed) {
      pop.forward();
    }
    _air = syncAmbientController(
      context: context,
      vsync: this,
      current: _air,
      period: _airPeriod,
    );
  }

  @override
  void dispose() {
    _pop?.dispose();
    _air?.dispose();
    super.dispose();
  }

  /// Humeurs des entrées de la semaine locale de l'entrée, elle comprise. Seule
  /// la fenêtre de la semaine est lue (issue #51), puis chaque entrée est rangée
  /// dans son jour local de saisie.
  Future<List<int>> _readWeek() async {
    final entry = widget.entry;
    final week = LocalWeek.containing(entry.localCreatedAt);
    final window = week.utcWindow;
    final read = await widget.repository.entriesBetween(
      window.fromUtc,
      window.toUtc,
    );
    final inWeek = [
      for (final e in read)
        if (week.containsDay(e.localCreatedAt)) e,
    ];
    if (!inWeek.any((e) => e.id == entry.id)) inWeek.add(entry);
    inWeek.sort((a, b) {
      final byTime = a.createdAt.compareTo(b.createdAt);
      return byTime != 0 ? byTime : a.id.compareTo(b.id);
    });
    return [for (final e in inWeek) e.mood];
  }

  Future<void> _continue() async {
    if (_leaving) return;
    _leaving = true;
    final offer = await _shouldOfferModel();
    if (!mounted) return;
    final navigator = Navigator.of(context);
    if (offer) {
      await navigator.pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ModelDownloadScreen(downloader: widget.downloader),
        ),
      );
    } else {
      navigator.pop();
    }
  }

  /// La proposition du modèle s'ouvre d'elle-même une seule fois : après une
  /// entrée « en attente », modèle absent (spec 003, RM31), une fois la célébration
  /// quittée (spec 010, CA16). Une erreur de lecture du réglage ne la montre pas :
  /// elle reste accessible par les Réglages.
  Future<bool> _shouldOfferModel() async {
    if (widget.entry.analysisStatus != AnalysisStatus.pending) return false;
    // Modèle absent et sans échec récent : sinon l'écran s'ouvrirait sur l'échec.
    final model = widget.downloader.current;
    if (model is! ModelAbsent || model.failure != null) return false;
    try {
      if (await widget.settings.readModelOfferShown()) return false;
      await widget.settings.setModelOfferShown();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final festive = widget.festive;
    final mood = widget.entry.mood;
    final textTheme = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final air = _air;
    return PopScope(
      // Le geste de retour fait comme « Continuer » (CA16).
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _continue();
      },
      child: Scaffold(
        backgroundColor: colors.hero,
        body: Stack(
          children: [
            // Décor : mer, sable et, en ambiance, bulles d'air ; jamais annoncé.
            Positioned.fill(
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: CustomPaint(
                    painter: _ShorePainter(
                      colors: colors,
                      air: festive ? air : null,
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        TidemarkSpacing.space6,
                        TidemarkSpacing.space8 * 2,
                        TidemarkSpacing.space6,
                        TidemarkSpacing.space6,
                      ),
                      child: Column(
                        children: [
                          if (festive)
                            _PoppingShell(
                              animation: _pop!,
                              color: colors.moodColor(mood),
                              colors: colors,
                            )
                          else
                            ExcludeSemantics(
                              child: CustomPaint(
                                size: _softShellSize,
                                painter: ShellPainter(
                                  color: colors.moodColor(mood),
                                ),
                              ),
                            ),
                          const SizedBox(height: TidemarkSpacing.space6),
                          Semantics(
                            header: true,
                            child: Text(
                              festive ? celebrationTitle : softCelebrationTitle,
                              textAlign: TextAlign.center,
                              style: TidemarkTypography.display.copyWith(
                                color: colors.onHero,
                              ),
                            ),
                          ),
                          const SizedBox(height: TidemarkSpacing.space2),
                          if (festive)
                            FutureBuilder<List<int>>(
                              future: _week,
                              builder: (context, snapshot) => _WeekLine(
                                moods: snapshot.data,
                                failed: snapshot.hasError,
                                colors: colors,
                              ),
                            )
                          else
                            _Line(softCelebrationLine, colors: colors),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      TidemarkSpacing.space6,
                      TidemarkSpacing.space3,
                      TidemarkSpacing.space6,
                      TidemarkSpacing.space6,
                    ),
                    child: PressShadow(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          // Bouton clair sur la mer claire, `tide` sur la mer
                          // sombre (maquette `Enregistre`).
                          backgroundColor: dark
                              ? colors.tide
                              : colors.surfaceRaised,
                          foregroundColor: dark ? colors.onTide : colors.ink,
                          textStyle: textTheme.labelLarge?.merge(
                            TidemarkTypography.button,
                          ),
                        ),
                        onPressed: _continue,
                        child: const Text('Continuer'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.text, {required this.colors});

  final String text;
  final TidemarkColors colors;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: TextAlign.center,
    style: TidemarkTypography.headline.copyWith(
      color: colors.onHeroMuted,
      fontWeight: FontWeight.w400,
      fontVariations: const [FontVariation.weight(400)],
    ),
  );
}

/// Phrase du rang et rangée de la semaine (CA12, CA17, CA18).
class _WeekLine extends StatelessWidget {
  const _WeekLine({
    required this.moods,
    required this.failed,
    required this.colors,
  });

  /// `null` tant que la lecture n'est pas finie.
  final List<int>? moods;
  final bool failed;
  final TidemarkColors colors;

  @override
  Widget build(BuildContext context) {
    if (failed) return _Line(fallbackCelebrationLine, colors: colors);
    final moods = this.moods;
    if (moods == null) return const SizedBox.shrink();
    final shown = moods.length > maxShellsInRow
        ? moods.sublist(moods.length - maxShellsInRow)
        : moods;
    final more = moods.length - shown.length;
    return Column(
      children: [
        _Line(shellRankLine(moods.length), colors: colors),
        const SizedBox(height: TidemarkSpacing.space6),
        Semantics(
          // Une seule annonce pour toute la rangée, « +N » compris (CA18), au
          // libellé du compteur de l'accueil (spec 009).
          label: shellCountLabel(moods.length),
          excludeSemantics: true,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.onHero.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(TidemarkRadius.radiusLg),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: TidemarkSpacing.space4,
                vertical: TidemarkSpacing.space3,
              ),
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: TidemarkSpacing.space2,
                runSpacing: TidemarkSpacing.space2,
                children: [
                  for (final mood in shown)
                    CustomPaint(
                      size: _rowShellSize,
                      painter: ShellPainter(color: colors.moodColor(mood)),
                    ),
                  if (more > 0)
                    Text(
                      '+$more',
                      style: TidemarkTypography.sticker.copyWith(
                        color: colors.onHero,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

const _bigShellSize = Size(170, 154);
const _softShellSize = Size(120, 108);
const _rowShellSize = Size(30, 27);

/// Le grand coquillage, qui apparaît en 0,7 s (CA12) : grossit en tournant, dépasse
/// un peu sa taille, puis se pose. Immobile une fois posé.
class _PoppingShell extends StatelessWidget {
  const _PoppingShell({
    required this.animation,
    required this.color,
    required this.colors,
  });

  final Animation<double> animation;
  final Color color;
  final TidemarkColors colors;

  @override
  Widget build(BuildContext context) {
    final shell = CustomPaint(
      size: _bigShellSize,
      painter: ShellPainter(color: color, colors: colors),
    );
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: animation,
        child: shell,
        builder: (context, child) {
          final t = animation.value;
          if (t >= 1) return child!;
          final double scale, turn, opacity;
          if (t < 0.6) {
            final k = Curves.easeOut.transform(t / 0.6);
            scale = lerpDouble(0.4, 1.08, k)!;
            turn = lerpDouble(-20, 4, k)!;
            opacity = k;
          } else {
            final k = Curves.easeInOut.transform((t - 0.6) / 0.4);
            scale = lerpDouble(1.08, 1, k)!;
            turn = lerpDouble(4, 0, k)!;
            opacity = 1;
          }
          return Opacity(
            opacity: opacity,
            child: Transform.rotate(
              angle: turn * math.pi / 180,
              child: Transform.scale(scale: scale, child: child),
            ),
          );
        },
      ),
    );
  }
}

/// Bulles d'air de la célébration : abscisse en part de la largeur, diamètre, et
/// décalage dans le cycle. Elles montent sur les bords, à l'écart des coquillages.
const _airBubbles = [
  (0.06, 12.0, 0.0),
  (0.17, 18.0, 0.2),
  (0.10, 9.0, 0.55),
  (0.84, 16.0, 0.1),
  (0.92, 11.0, 0.4),
  (0.79, 8.0, 0.75),
];

/// Bas de l'écran : la mer, le sable, et les bulles d'air qui montent quand [air]
/// tourne (CA12) ; rien ne bouge sans lui (CA13, CA19).
class _ShorePainter extends CustomPainter {
  _ShorePainter({required this.colors, required this.air})
    : super(repaint: air);

  final TidemarkColors colors;
  final Animation<double>? air;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final base = h - 300;
    final sea = Path()..moveTo(0, base + 40);
    for (var i = 0; i < 6; i++) {
      final x0 = w * i / 6;
      final x1 = w * (i + 1) / 6;
      sea.quadraticBezierTo(
        (x0 + x1) / 2,
        base + (i.isEven ? 28 : 52),
        x1,
        base + 40,
      );
    }
    sea
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(sea, Paint()..color = colors.heroWave1);
    final sand = Path()
      ..moveTo(0, base + 150)
      ..cubicTo(w * 0.2, base + 130, w * 0.4, base + 168, w * 0.61, base + 148)
      ..cubicTo(w * 0.8, base + 136, w * 0.9, base + 142, w, base + 146)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(sand, Paint()..color = colors.sand);

    final air = this.air;
    if (air == null) return;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final start = h - 120;
    for (final (x, d, offset) in _airBubbles) {
      final t = (air.value + offset) % 1;
      final y = start - t * (start + d);
      final alpha = t < 0.15 ? t / 0.15 : 1 - (t - 0.15) / 0.85;
      ring.color = colors.onHero.withValues(alpha: 0.4 * alpha);
      canvas.drawCircle(Offset(x * w, y), d / 2, ring);
    }
  }

  @override
  bool shouldRepaint(_ShorePainter old) =>
      old.colors != colors || old.air != air;
}
