// CA29 : le fond de l'écran de lancement natif est la couleur `surface` de la charte,
// en clair et en sombre. Le mécanisme n'est pas imposé par la spec : ces tests lisent
// la couleur résolue, que le fond soit écrit en dur dans le fichier, référencé par
// `@color/...` (Android) ou par une couleur nommée du catalogue d'assets (iOS).
import 'dart:convert';
import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/ui/theme/tidemark_colors.dart';

typedef Rgb = ({int r, int g, int b});

Rgb rgbOf(Color c) =>
    (r: (c.r * 255).round(), g: (c.g * 255).round(), b: (c.b * 255).round());

String hex(Rgb c) =>
    ('#${c.r.toRadixString(16).padLeft(2, '0')}'
            '${c.g.toRadixString(16).padLeft(2, '0')}'
            '${c.b.toRadixString(16).padLeft(2, '0')}')
        .toUpperCase();

Rgb parseHex(String value) {
  final digits = value.substring(1);
  final rgb = digits.substring(digits.length - 6); // ignore l'alpha éventuel
  return (
    r: int.parse(rgb.substring(0, 2), radix: 16),
    g: int.parse(rgb.substring(2, 4), radix: 16),
    b: int.parse(rgb.substring(4, 6), radix: 16),
  );
}

String? read(String path) {
  final file = File(path);
  return file.existsSync() ? file.readAsStringSync() : null;
}

const androidRes = 'android/app/src/main/res';

/// Couleur nommée [name] dans `values/colors.xml`, surchargée par
/// `values-night/colors.xml` en mode sombre.
Rgb? androidNamedColor(String name, {required bool dark}) {
  final pattern = RegExp(
    '<color\\s+name="$name"[^>]*>\\s*(#[0-9A-Fa-f]+)\\s*<',
  );
  final folders = dark ? ['values-night', 'values'] : ['values'];
  for (final folder in folders) {
    final match = pattern.firstMatch(
      read('$androidRes/$folder/colors.xml') ?? '',
    );
    if (match != null) return parseHex(match.group(1)!);
  }
  return null;
}

/// Couleur de fond d'un fichier `launch_background.xml`, résolue pour le mode voulu.
/// En sombre, un dossier `drawable-night*` prime s'il existe.
Rgb? androidLaunchColor(String drawableFolder, {required bool dark}) {
  final candidates = [
    if (dark) '$drawableFolder-night',
    if (dark && drawableFolder == 'drawable-v21') 'drawable-night-v21',
    drawableFolder,
  ];
  for (final folder in candidates) {
    final xml = read('$androidRes/$folder/launch_background.xml');
    if (xml == null) continue;
    final withoutComments = xml.replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');
    final reference = RegExp(r'android:(?:drawable|color)="([^"]+)"')
        .firstMatch(withoutComments)
        ?.group(1);
    if (reference == null) return null;
    if (reference.startsWith('#')) return parseHex(reference);
    if (reference.startsWith('@color/')) {
      return androidNamedColor(reference.substring(7), dark: dark);
    }
    return null; // « ?android:colorBackground », « @android:color/white »…
  }
  return null;
}

/// Composante de couleur : « 0xF3 » (hexadécimal), « 0.953 » (sur 0..1) ou « 243 »
/// (sur 0..255). [unitScale] impose l'échelle 0..1 (storyboard : red="1").
int component(Object? value, {bool unitScale = false}) {
  final text = '$value';
  if (text.startsWith('0x')) return int.parse(text.substring(2), radix: 16);
  final number = double.parse(text);
  return unitScale || text.contains('.')
      ? (number * 255).round()
      : number.round();
}

/// Couleur de fond de LaunchScreen.storyboard, résolue pour le mode voulu.
Rgb? iosLaunchColor({required bool dark}) {
  final storyboard = read('ios/Runner/Base.lproj/LaunchScreen.storyboard');
  if (storyboard == null) return null;
  final match = RegExp(r'<color key="backgroundColor"([^>]*)/>')
      .firstMatch(storyboard);
  if (match == null) return null;
  final attributes = match.group(1)!;
  String? attribute(String name) =>
      RegExp('$name="([^"]*)"').firstMatch(attributes)?.group(1);

  final colorName = attribute('name');
  if (colorName == null) {
    if (dark) return null; // une couleur en dur ne change pas avec le mode
    return (
      r: component(attribute('red'), unitScale: true),
      g: component(attribute('green'), unitScale: true),
      b: component(attribute('blue'), unitScale: true),
    );
  }
  final contents = read(
    'ios/Runner/Assets.xcassets/$colorName.colorset/Contents.json',
  );
  if (contents == null) return null;
  final colors =
      (jsonDecode(contents) as Map<String, dynamic>)['colors'] as List;
  for (final item in colors.cast<Map<String, dynamic>>()) {
    final appearances = (item['appearances'] as List?) ?? const [];
    final isDark = appearances.any(
      (a) => a['appearance'] == 'luminosity' && a['value'] == 'dark',
    );
    if (isDark != dark || appearances.length > 1) continue;
    final components = item['color']['components'] as Map<String, dynamic>;
    return (
      r: component(components['red']),
      g: component(components['green']),
      b: component(components['blue']),
    );
  }
  return null;
}

void expectSurface(Rgb? actual, TidemarkColors expected, String where) {
  expect(
    actual,
    isNotNull,
    reason: '$where : fond introuvable ou non résolu vers une couleur',
  );
  expect(
    hex(actual!),
    hex(rgbOf(expected.surface)),
    reason: '$where : le fond doit être la couleur surface de la charte',
  );
}

void main() {
  group('CA29 : écran de lancement Android', () {
    for (final folder in ['drawable', 'drawable-v21']) {
      test('CA29 : $folder/launch_background.xml, fond surface en clair', () {
        expectSurface(
          androidLaunchColor(folder, dark: false),
          TidemarkColors.light,
          '$folder (clair)',
        );
      });

      test('CA29 : $folder/launch_background.xml, fond surface en sombre', () {
        expectSurface(
          androidLaunchColor(folder, dark: true),
          TidemarkColors.dark,
          '$folder (sombre)',
        );
      });
    }
  });

  group('CA29 : écran de lancement iOS', () {
    test('CA29 : LaunchScreen.storyboard, fond surface en clair', () {
      expectSurface(
        iosLaunchColor(dark: false),
        TidemarkColors.light,
        'LaunchScreen.storyboard (clair)',
      );
    });

    test('CA29 : LaunchScreen.storyboard, fond surface en sombre', () {
      expectSurface(
        iosLaunchColor(dark: true),
        TidemarkColors.dark,
        'LaunchScreen.storyboard (sombre)',
      );
    });
  });
}
