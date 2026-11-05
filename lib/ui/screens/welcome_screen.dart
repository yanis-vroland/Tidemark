import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../motion/ambient_motion.dart';
import '../theme/tidemark_colors.dart';
import '../theme/tidemark_tokens.dart';
import '../theme/tidemark_typography.dart';
import '../widgets/mood_bubble.dart';
import '../widgets/sticker.dart';
import '../widgets/tidemark_logo.dart';

/// Écran de bienvenue du premier lancement (spec 009, CA1, CA2) : ce que fait
/// l'app en trois étapes, et que rien ne quitte le téléphone.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.onStart});

  /// « C'est parti » : la bienvenue est passée.
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final body = TidemarkTypography.body.copyWith(color: colors.ink);
    final strong = TextStyle(
      fontWeight: FontWeight.w700,
      fontVariations: const [FontVariation.weight(700)],
    );
    final steps = [
      ('Choisis une bulle', ', ajoute un mot si tu veux.', colors.mood4Soft),
      ('Ramasse un coquillage', ' à chaque entrée.', colors.mood3Soft),
      ('Regarde ta semaine', ' monter et descendre.', colors.mood2Soft),
    ];
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _WelcomeSky(),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    TidemarkSpacing.space6,
                    TidemarkSpacing.space4,
                    TidemarkSpacing.space6,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 20,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          "Comment va ta marée aujourd'hui ?",
                          style: TidemarkTypography.title.copyWith(
                            color: colors.ink,
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: TidemarkSpacing.space3,
                        children: [
                          for (final (i, (lead, rest, tint)) in steps.indexed)
                            Row(
                              children: [
                                ExcludeSemantics(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: tint,
                                      shape: BoxShape.circle,
                                    ),
                                    child: SizedBox.square(
                                      dimension: 40,
                                      child: Center(
                                        child: Text(
                                          '${i + 1}',
                                          style: TidemarkTypography.headline
                                              .copyWith(
                                                fontFamily: TidemarkTypography
                                                    .displayFamily,
                                                fontWeight: FontWeight.w800,
                                                fontVariations: const [
                                                  FontVariation.weight(800),
                                                ],
                                                color: colors.onMood,
                                              ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: TidemarkSpacing.space3),
                                Expanded(
                                  child: Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(text: lead, style: strong),
                                        TextSpan(text: rest),
                                      ],
                                    ),
                                    style: body,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.lock_outline,
                            size: TidemarkSize.iconSm,
                            color: colors.inkMuted,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Rien ne quitte ton téléphone.',
                              style: TidemarkTypography.label.copyWith(
                                color: colors.inkMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    TidemarkSpacing.space6,
                    TidemarkSpacing.space6,
                    TidemarkSpacing.space6,
                    TidemarkSpacing.space8 +
                        MediaQuery.paddingOf(context).bottom,
                  ),
                  child: PressShadow(
                    child: FilledButton(
                      onPressed: onStart,
                      child: const Text("C'est parti"),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Ciel de la bienvenue (maquette) : logo et nom, soleil, mer et trois bulles
/// qui flottent ; décoratif.
class _WelcomeSky extends StatefulWidget {
  const _WelcomeSky();

  @override
  State<_WelcomeSky> createState() => _WelcomeSkyState();
}

class _WelcomeSkyState extends State<_WelcomeSky>
    with SingleTickerProviderStateMixin {
  AnimationController? _float;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _float = syncAmbientController(
      context: context,
      vsync: this,
      current: _float,
      period: const Duration(seconds: 2),
      reverse: true,
    );
  }

  @override
  void dispose() {
    _float?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final top = MediaQuery.paddingOf(context).top;
    final float = _float;
    Widget bubble(int mood, double size, double phase) {
      final child = MoodBubble(mood: mood, size: size);
      if (float == null) return child;
      return AnimatedBuilder(
        animation: float,
        builder: (context, child) {
          final t = Curves.easeInOut.transform((float.value + phase) % 1.0);
          return Transform.translate(offset: Offset(0, -8 * t), child: child);
        },
        child: child,
      );
    }

    return SizedBox(
      height: 280 + top,
      child: Stack(
        children: [
          Positioned.fill(
            child: ExcludeSemantics(
              child: CustomPaint(
                painter: _SkyPainter(colors: colors, top: top),
              ),
            ),
          ),
          Positioned(
            left: 40,
            top: top + 110,
            child: ExcludeSemantics(child: bubble(2, 64, 0.2)),
          ),
          Positioned(
            left: 150,
            top: top + 136,
            child: ExcludeSemantics(child: bubble(5, 96, 0.6)),
          ),
          Positioned(
            right: 35,
            top: top + 122,
            child: ExcludeSemantics(child: bubble(3, 72, 0)),
          ),
          Positioned(
            left: TidemarkSpacing.space6,
            right: TidemarkSpacing.space6,
            top: top + TidemarkSpacing.space6,
            child: Row(
              children: [
                const ExcludeSemantics(child: TidemarkLogo(size: 44)),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    'Tidemark',
                    style: TidemarkTypography.title.copyWith(
                      fontWeight: FontWeight.w800,
                      fontVariations: const [FontVariation.weight(800)],
                      color: colors.onSky,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SkyPainter extends CustomPainter {
  const _SkyPainter({required this.colors, required this.top});

  final TidemarkColors colors;
  final double top;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.drawRect(Offset.zero & size, Paint()..color = colors.sky);
    final sun = Offset(w - 83, top + 80);
    canvas.drawCircle(
      sun,
      62,
      Paint()..color = colors.sun.withValues(alpha: 0.25),
    );
    canvas.drawCircle(sun, 44, Paint()..color = colors.sun);
    final gull = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = colors.onSky.withValues(alpha: 0.5);
    for (final (x, y, s) in [(70.0, 90.0, 6.0), (104.0, 112.0, 4.0)]) {
      canvas.drawPath(
        Path()
          ..moveTo(x, top + y)
          ..relativeQuadraticBezierTo(s, -s, 2 * s, 0)
          ..relativeQuadraticBezierTo(s, -s, 2 * s, 0),
        gull,
      );
    }
    void wave(double crest, Color color) {
      final path = Path()..moveTo(0, h);
      for (var x = 0.0; x <= w; x += 4) {
        path.lineTo(x, crest + 7 - 7 * math.cos(math.pi * x / 65.5));
      }
      path
        ..lineTo(w, h)
        ..close();
      canvas.drawPath(path, Paint()..color = color);
    }

    wave(h - 180, colors.heroWave2);
    wave(h - 130, colors.hero);
    canvas.drawPath(
      Path()
        ..moveTo(0, h - 50)
        ..cubicTo(w * 0.23, h - 64, w * 0.41, h - 36, w * 0.61, h - 50)
        ..cubicTo(w * 0.78, h - 60, w * 0.9, h - 54, w, h - 52)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close(),
      Paint()..color = colors.surface,
    );
  }

  @override
  bool shouldRepaint(_SkyPainter old) => old.colors != colors || old.top != top;
}
