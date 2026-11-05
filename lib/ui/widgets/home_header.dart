import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../day_moment.dart';
import '../motion/ambient_motion.dart';
import '../theme/tidemark_colors.dart';
import '../theme/tidemark_tokens.dart';
import '../theme/tidemark_typography.dart';
import 'shell_painter.dart';

/// Hauteur de la carte du check-in posée sur le bas de l'en-tête (maquette :
/// `margin-top: -36px`).
const homeHeaderOverlap = 36.0;

/// Place réservée sous le texte de l'en-tête pour les vagues, depuis le bas de la
/// scène.
const _waveRoom = 76.0;

/// En-tête `hero` de l'accueil (spec 009, CA7 à CA10) : surtitre « Ton journal »,
/// salutation, compteur de coquillages, bouton « Réglages », sur une scène
/// décorative (mer, vagues, soleil ou lune).
///
/// Avec [overlap], la scène descend de cette hauteur sous l'en-tête : la carte qui
/// suit se pose dessus.
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.moment,
    required this.onOpenSettings,
    this.count,
    this.overlap = 0,
  });

  final DayMoment moment;
  final VoidCallback onOpenSettings;

  /// Compteur de coquillages (CA9) ; `null` : pas de compteur (CA17).
  final String? count;

  final double overlap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final top = MediaQuery.paddingOf(context).top + TidemarkSpacing.space3;
    final count = this.count;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          bottom: -overlap,
          // Scène décorative, jamais annoncée (CA8).
          child: ExcludeSemantics(
            child: _HeroScene(moment: moment, celestialTop: top),
          ),
        ),
        // Texte jamais plafonné (spec 009, CA27) : à 200 %, l'en-tête grandit et
        // l'accueil défile.
        Padding(
          padding: EdgeInsets.fromLTRB(
            TidemarkSpacing.space5,
            top,
            TidemarkSpacing.space5,
            _waveRoom - overlap,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        'Ton journal',
                        style: TidemarkTypography.label.copyWith(
                          color: colors.onHeroMuted,
                          fontWeight: FontWeight.w700,
                          fontVariations: const [FontVariation.weight(700)],
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: TidemarkSpacing.space0_5),
                    Text(
                      greetingFor(moment),
                      style: TidemarkTypography.display.copyWith(
                        color: colors.onHero,
                      ),
                    ),
                    if (count != null) ...[
                      const SizedBox(height: TidemarkSpacing.space1_5),
                      _ShellCount(text: count),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: TidemarkSpacing.space2),
              _SettingsButton(onPressed: onOpenSettings),
            ],
          ),
        ),
      ],
    );
  }
}

/// Puce « N coquillages cette semaine » (CA9).
class _ShellCount extends StatelessWidget {
  const _ShellCount({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.onHero.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(TidemarkRadius.radiusPill),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          TidemarkSpacing.space2,
          5,
          TidemarkSpacing.space3,
          5,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: CustomPaint(
                size: const Size.square(TidemarkSize.iconButton),
                painter: ShellPainter(color: colors.sand),
              ),
            ),
            const SizedBox(width: TidemarkSpacing.space1_5),
            Flexible(
              child: Text(
                text,
                style: TidemarkTypography.label.copyWith(color: colors.onHero),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bouton rond « Réglages » de l'en-tête (CA7).
class _SettingsButton extends StatelessWidget {
  const _SettingsButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Annoncé « Réglages » : l'infobulle seule ne donne pas de libellé.
    return Semantics(
      container: true,
      button: true,
      label: 'Réglages',
      onTap: onPressed,
      excludeSemantics: true,
      child: IconButton(
        onPressed: onPressed,
        tooltip: 'Réglages',
        color: colors.onHero,
        style: IconButton.styleFrom(
          backgroundColor: colors.onHero.withValues(alpha: 0.15),
        ),
        constraints: const BoxConstraints.tightFor(
          width: TidemarkSize.tapMin,
          height: TidemarkSize.tapMin,
        ),
        icon: const Icon(Icons.tune, size: TidemarkSize.iconMd),
      ),
    );
  }
}

/// Périodes de la scène (maquette : `tm-drift`, `tm-drift-slow`, `tm-rock`).
const _driftPeriod = Duration(seconds: 9);
const _slowDriftPeriod = Duration(seconds: 15);
const _rockPeriod = Duration(seconds: 2);

/// Scène de l'en-tête : vagues qui dérivent et, le soir, voilier qui tangue, sous
/// [AmbientMotion] seulement (spec 008, mouvement).
class _HeroScene extends StatefulWidget {
  const _HeroScene({required this.moment, required this.celestialTop});

  final DayMoment moment;

  /// Haut du texte de l'en-tête : le soleil ou la lune se placent dessous.
  final double celestialTop;

  @override
  State<_HeroScene> createState() => _HeroSceneState();
}

class _HeroSceneState extends State<_HeroScene> with TickerProviderStateMixin {
  AnimationController? _drift;
  AnimationController? _slowDrift;
  AnimationController? _rock;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _drift = syncAmbientController(
      context: context,
      vsync: this,
      current: _drift,
      period: _driftPeriod,
    );
    _slowDrift = syncAmbientController(
      context: context,
      vsync: this,
      current: _slowDrift,
      period: _slowDriftPeriod,
    );
    // Le voilier n'existe que le soir : pas de contrôleur le reste du jour.
    _rock = _syncRock();
  }

  AnimationController? _syncRock() {
    if (widget.moment == DayMoment.evening) {
      return syncAmbientController(
        context: context,
        vsync: this,
        current: _rock,
        period: _rockPeriod,
        reverse: true,
      );
    }
    _rock?.dispose();
    return null;
  }

  @override
  void didUpdateWidget(_HeroScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.moment != widget.moment) _rock = _syncRock();
  }

  @override
  void dispose() {
    _drift?.dispose();
    _slowDrift?.dispose();
    _rock?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _HeroScenePainter(
      colors: context.colors,
      moment: widget.moment,
      celestialTop: widget.celestialTop,
      drift: _drift,
      slowDrift: _slowDrift,
      rock: _rock,
    ),
  );
}

class _HeroScenePainter extends CustomPainter {
  _HeroScenePainter({
    required this.colors,
    required this.moment,
    required this.celestialTop,
    this.drift,
    this.slowDrift,
    this.rock,
  }) : super(repaint: Listenable.merge([?drift, ?slowDrift, ?rock]));

  final TidemarkColors colors;
  final DayMoment moment;
  final double celestialTop;
  final Animation<double>? drift;
  final Animation<double>? slowDrift;
  final Animation<double>? rock;

  /// Longueur d'onde des vagues (maquette : 131 points).
  static const _wavelength = 131.0;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.drawRect(Offset.zero & size, Paint()..color = colors.hero);

    // Soleil ou lune, à gauche du bouton « Réglages ».
    final sky = Offset(w - 110, celestialTop + 56);
    if (moment == DayMoment.evening) {
      canvas.drawCircle(sky, 26, Paint()..color = colors.moon);
      canvas.drawCircle(
        sky + const Offset(12, -8),
        24,
        Paint()..color = colors.hero,
      );
      final star = Paint()..color = colors.onHero.withValues(alpha: 0.7);
      for (final (dx, dy, r) in [
        (-66.0, -40.0, 1.6),
        (-42.0, 30.0, 1.2),
        (38.0, 44.0, 1.4),
        (-92.0, 4.0, 1.0),
      ]) {
        canvas.drawCircle(sky + Offset(dx, dy), r, star);
      }
    } else {
      canvas.drawCircle(
        sky,
        30,
        Paint()..color = colors.sun.withValues(alpha: 0.25),
      );
      canvas.drawCircle(sky, 22, Paint()..color = colors.sun);
    }

    // Mouette.
    final gull = Offset(w * 0.62, celestialTop + 8);
    canvas.drawPath(
      Path()
        ..moveTo(gull.dx, gull.dy)
        ..relativeQuadraticBezierTo(5, -5, 10, 0)
        ..relativeQuadraticBezierTo(5, -5, 10, 0),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = colors.onHero.withValues(alpha: 0.75),
    );

    _wave(canvas, size, h - 76, slowDrift?.value ?? 0, colors.heroWave1);
    if (moment == DayMoment.evening) _boat(canvas, Offset(w - 70, h - 82));
    _wave(canvas, size, h - 58, drift?.value ?? 0, colors.heroWave2);

    // Rivage `surface` en bas de la scène.
    canvas.drawPath(
      Path()
        ..moveTo(0, h - 24)
        ..cubicTo(w * 0.2, h - 36, w * 0.38, h - 12, w * 0.56, h - 24)
        ..cubicTo(w * 0.7, h - 34, w * 0.84, h - 30, w, h - 26)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close(),
      Paint()..color = colors.surface,
    );
  }

  /// Vague de crête [top], décalée de [phase] longueur d'onde vers la gauche.
  void _wave(Canvas canvas, Size size, double top, double phase, Color color) {
    final shift = phase * _wavelength;
    final path = Path()..moveTo(-_wavelength, size.height);
    for (var x = -_wavelength; x <= size.width + _wavelength; x += 4) {
      final y = top + 6 + 6 * math.cos(2 * math.pi * (x + shift) / _wavelength);
      path.lineTo(x, y);
    }
    path
      ..lineTo(size.width + _wavelength, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  /// Voilier du soir, posé en [base] (milieu de la coque).
  void _boat(Canvas canvas, Offset base) {
    final t = Curves.easeInOut.transform(rock?.value ?? 0);
    canvas.save();
    canvas.translate(base.dx, base.dy - 3 * t);
    canvas.rotate(-4 * math.pi / 180 * t);
    canvas.drawPath(
      Path()
        ..moveTo(-20, 0)
        ..lineTo(20, 0)
        ..lineTo(14, 10)
        ..lineTo(-14, 10)
        ..close(),
      Paint()..color = colors.moon,
    );
    canvas.drawPath(
      Path()
        ..moveTo(1, -2)
        ..lineTo(1, -30)
        ..lineTo(20, -4)
        ..close(),
      Paint()..color = colors.onHero,
    );
    canvas.drawPath(
      Path()
        ..moveTo(-1, -2)
        ..lineTo(-1, -24)
        ..lineTo(-14, -4)
        ..close(),
      Paint()..color = colors.mood5,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HeroScenePainter old) =>
      old.colors != colors ||
      old.moment != moment ||
      old.celestialTop != celestialTop ||
      old.drift != drift ||
      old.slowDrift != slowDrift ||
      old.rock != rock;
}
