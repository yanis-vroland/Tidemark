// Outils communs aux tests de la refonte ludique (spec 008) : application de test avec
// ou sans animations d'ambiance, lecture des pixels d'une bulle, fonds peints.
//
// Fichier séparé de ui_harness.dart pour que les tests existants continuent de
// compiler tant que `AmbientMotion` n'existe pas.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/main.dart';
import 'package:tidemark/ui/motion/ambient_motion.dart';
import 'package:tidemark/ui/theme/tidemark_theme.dart';
import 'package:tidemark/ui/widgets/mood_bubble.dart';

import 'fake_entry_repository.dart';
import 'fake_model_downloader.dart';
import 'fake_settings_repository.dart';
import 'ui_harness.dart';

/// Comme `testApp`, avec `AmbientMotion(enabled: ambient)` au-dessus de l'écran et,
/// au besoin, la demande du téléphone de réduire les animations ([reduceMotion]).
/// [ambient] vaut faux par défaut : les tests qui utilisent `settle` restent
/// déterministes.
Widget ambientApp(
  Widget home, {
  double textScale = 1.0,
  bool ambient = false,
  bool reduceMotion = false,
}) {
  return MaterialApp(
    theme: buildTidemarkTheme(Brightness.light),
    darkTheme: buildTidemarkTheme(Brightness.dark),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
        disableAnimations: reduceMotion,
      ),
      child: AmbientMotion(enabled: ambient, child: child!),
    ),
    home: home,
  );
}

/// Thème sombre du système, rétabli en fin de test.
void useDarkPlatform(WidgetTester tester) {
  tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
}

/// Les `MoodBubble` à l'écran, dans l'ordre de l'arbre.
List<MoodBubble> bubbles(WidgetTester tester) =>
    tester.widgetList<MoodBubble>(find.byType(MoodBubble)).toList();

/// Fond peint de l'écran (Scaffold) qui contient [anchor].
Color scaffoldColor(WidgetTester tester, Finder anchor) {
  final scaffold = find.ancestor(of: anchor, matching: find.byType(Scaffold));
  expect(scaffold, findsOneWidget, reason: 'écran affiché');
  return tester
      .widget<Material>(
        find.descendant(of: scaffold, matching: find.byType(Material)).first,
      )
      .color!;
}

/// Couleur de fond de l'ancêtre coloré le plus proche de [target] (Material,
/// DecoratedBox, ColoredBox), transparent exclu. `null` si aucun.
Color? backgroundBehind(WidgetTester tester, Finder target) {
  Color? found;
  tester.element(target.first).visitAncestorElements((element) {
    final widget = element.widget;
    Color? color;
    if (widget is Material) {
      color = widget.color;
    } else if (widget is DecoratedBox && widget.decoration is BoxDecoration) {
      color = (widget.decoration as BoxDecoration).color;
    } else if (widget is ColoredBox) {
      color = widget.color;
    }
    if (color != null && color.a > 0) {
      found = color;
      return false;
    }
    return true;
  });
  return found;
}

/// Couleur du texte [finder] telle qu'elle est peinte.
Color? paintedTextColor(WidgetTester tester, Finder finder) =>
    tester.renderObject<RenderParagraph>(finder).text.style?.color;

/// Corps de l'application entière sur [repo], avec ou sans animations d'ambiance.
Widget fullApp(
  FakeEntryRepository repo, {
  bool ambientMotion = false,
  DateTime? now,
}) => TidemarkApp(
  repository: repo,
  settings: FakeSettingsRepository(),
  clock: () => now ?? fixedNow,
  downloader: FakeModelDownloader(readyModel),
  ambientMotion: ambientMotion,
);

/// Pixels d'un widget encadré par un `RepaintBoundary` de clé [key].
class Pixels {
  Pixels(this.width, this.height, this.data);

  final int width;
  final int height;
  final ByteData data;

  /// Octets RGBA bruts, pour comparer deux captures.
  Uint8List get bytes => data.buffer.asUint8List();

  /// Couleur du pixel (x, y) : `[r, g, b, a]`.
  List<int> at(int x, int y) {
    final i = (y * width + x) * 4;
    return [
      data.getUint8(i),
      data.getUint8(i + 1),
      data.getUint8(i + 2),
      data.getUint8(i + 3),
    ];
  }
}

Future<Pixels> capture(WidgetTester tester, GlobalKey key) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
  final image = (await tester.runAsync<ui.Image>(() => boundary.toImage()))!;
  final data = (await tester.runAsync<ByteData?>(() => image.toByteData()))!;
  return Pixels(image.width, image.height, data);
}

/// [pixel] est opaque et à moins de [tolerance] par canal de [color].
bool isColor(List<int> pixel, Color color, {int tolerance = 3}) {
  final expected = [
    (color.r * 255).round(),
    (color.g * 255).round(),
    (color.b * 255).round(),
  ];
  if (pixel[3] != 255) return false;
  for (var c = 0; c < 3; c++) {
    if ((pixel[c] - expected[c]).abs() > tolerance) return false;
  }
  return true;
}

/// Nombre de pixels de [color] dans la capture.
int countColor(Pixels pixels, Color color) {
  var n = 0;
  for (var y = 0; y < pixels.height; y++) {
    for (var x = 0; x < pixels.width; x++) {
      if (isColor(pixels.at(x, y), color)) n++;
    }
  }
  return n;
}

/// Ordonnée du pixel de [color] le plus haut, `null` s'il n'y en a aucun.
int? topmost(Pixels pixels, Color color) {
  for (var y = 0; y < pixels.height; y++) {
    for (var x = 0; x < pixels.width; x++) {
      if (isColor(pixels.at(x, y), color)) return y;
    }
  }
  return null;
}
