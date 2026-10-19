// Spec 007 : widget TidemarkLogo (CA4 pour la taille, CA5, CA6). Les couleurs
// peintes sont lues sur les pixels rendus, sans golden : le test ne dépend ni de
// la façon de dessiner ni de l'anti-crénelage.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/ui/theme/tidemark_colors.dart';
import 'package:tidemark/ui/theme/tidemark_theme.dart';
import 'package:tidemark/ui/widgets/tidemark_logo.dart';

Widget host(Widget child, Brightness brightness) => MaterialApp(
  theme: buildTidemarkTheme(brightness),
  home: Align(alignment: Alignment.topLeft, child: child),
);

/// Pixel (x, y) du logo, en coordonnées de la boîte de 48, rendu à l'échelle [scale].
Future<ui.Color> pixelAt(
  WidgetTester tester,
  GlobalKey key,
  double x,
  double y,
  double scale,
) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = (await image.toByteData())!;
    return (data: data.buffer.asUint8List(), width: image.width);
  });
  final px = (x * scale).floor();
  final py = (y * scale).floor();
  final i = (py * bytes!.width + px) * 4;
  final Uint8List d = bytes.data;
  return ui.Color.fromARGB(d[i + 3], d[i], d[i + 1], d[i + 2]);
}

void main() {
  testWidgets('CA4 : le logo est rendu à la taille demandée, carré', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(const TidemarkLogo(size: 64), Brightness.light),
    );
    expect(tester.getSize(find.byType(TidemarkLogo)), const Size(64, 64));
  });

  testWidgets('CA4 : la taille suit le paramètre size', (tester) async {
    await tester.pumpWidget(
      host(const TidemarkLogo(size: 24), Brightness.light),
    );
    expect(tester.getSize(find.byType(TidemarkLogo)), const Size(24, 24));
  });

  testWidgets(
    'CA5 : le logo n\'ajoute aucun nœud annoncé par le lecteur d\'écran',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        host(const TidemarkLogo(size: 64), Brightness.light),
      );

      final annotated = <String>[];
      void visit(SemanticsNode node) {
        final data = node.getSemanticsData();
        if (data.label.isNotEmpty ||
            data.value.isNotEmpty ||
            data.hint.isNotEmpty ||
            data.tooltip.isNotEmpty) {
          annotated.add(data.label);
        }
        node.visitChildren((child) {
          visit(child);
          return true;
        });
      }

      // L'arbre sémantique est porté par la vue, pas par le propriétaire racine.
      visit(
        tester
            .binding
            .renderViews
            .first
            .owner!
            .semanticsOwner!
            .rootSemanticsNode!,
      );
      expect(annotated, isEmpty);
      expect(find.bySemanticsLabel(RegExp('.+')), findsNothing);
      expect(find.bySemanticsLabel('Tidemark'), findsNothing);
      semantics.dispose();
    },
  );

  for (final brightness in Brightness.values) {
    final palette = brightness == Brightness.light
        ? TidemarkColors.light
        : TidemarkColors.dark;
    testWidgets('CA6 : les couleurs peintes sont brand, onBrand et brandAccent '
        '(thème ${brightness.name})', (tester) async {
      final key = GlobalKey();
      const scale = 4.0; // 192 px pour une boîte de 48
      await tester.pumpWidget(
        host(
          RepaintBoundary(
            key: key,
            child: const TidemarkLogo(size: 48 * scale),
          ),
          brightness,
        ),
      );
      // Tuile : à l'écart du symbole.
      expect(await pixelAt(tester, key, 5, 24, scale), palette.brand);
      // Vague (départ) et jambage : onBrand.
      expect(await pixelAt(tester, key, 10, 16, scale), palette.onBrand);
      expect(await pixelAt(tester, key, 24, 30, scale), palette.onBrand);
      // Point de la laisse.
      expect(await pixelAt(tester, key, 31.5, 37, scale), palette.brandAccent);
    });
  }

  testWidgets('Thème sombre : la tuile reste brand, sans contour, et ses coins '
      'sont arrondis (rayon 11)', (tester) async {
    final key = GlobalKey();
    const scale = 4.0;
    await tester.pumpWidget(
      host(
        RepaintBoundary(
          key: key,
          child: const TidemarkLogo(size: 48 * scale),
        ),
        Brightness.dark,
      ),
    );
    // Le coin extrême est hors de la tuile : transparent.
    expect((await pixelAt(tester, key, 0.5, 0.5, scale)).a, 0);
    // Juste à l'intérieur du bord droit, au milieu : brand, pas de contour.
    expect(
      await pixelAt(tester, key, 46, 24, scale),
      TidemarkColors.dark.brand,
    );
  });

  test('Géométrie : les constantes reprennent la spec « Le logo »', () {
    expect(TidemarkLogo.tileRadius, 11);
    expect(TidemarkLogo.stroke, 3.2);
    expect(TidemarkLogo.waveStart, const Offset(10, 16));
    expect(TidemarkLogo.waveHalfWidth, 7);
    expect(TidemarkLogo.waveDepth, 3.2);
    expect(TidemarkLogo.waveHalves, 4);
    expect(TidemarkLogo.stemTop, const Offset(24, 22));
    expect(TidemarkLogo.stemBottom, const Offset(24, 37));
    expect(TidemarkLogo.dotCenter, const Offset(31.5, 37));
    expect(TidemarkLogo.dotRadius, 2.6);
  });
}
