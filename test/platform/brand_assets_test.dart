// Spec 007, CA1 et CA3 : icônes de l'app et écran de lancement natifs, tels que les
// produit tool/generate_brand.py (CA2 : tests/generate-brand.sh). Les fichiers sont
// lus à la racine du dépôt ; les couleurs viennent de docs/maquettes/000-charte/tokens.json.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/png.dart';

const res = 'android/app/src/main/res';
const iosAssets = 'ios/Runner/Assets.xcassets';

String? read(String path) {
  final file = File(path);
  return file.existsSync() ? file.readAsStringSync() : null;
}

String requireText(String path) {
  final text = read(path);
  expect(text, isNotNull, reason: '$path est absent');
  return text!;
}

/// Valeur `#rrggbb` du jeton [name] pour le thème [theme], lue dans tokens.json.
String token(String name, String theme) {
  final json = jsonDecode(
    File('docs/maquettes/000-charte/tokens.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final tokens = ((json['color'] as Map)['tokens'] as List)
      .cast<Map<String, dynamic>>();
  final entry = tokens.firstWhere((t) => t['name'] == name);
  return (entry['value'] as Map)[theme] as String;
}

/// Valeur d'une couleur Android nommée dans [file] (comparaison insensible à la casse).
String? androidColor(String file, String name) {
  final match = RegExp('<color\\s+name="$name"[^>]*>\\s*(#[0-9A-Fa-f]+)\\s*<')
      .firstMatch(read(file) ?? '');
  return match?.group(1)?.toLowerCase();
}

PngInfo requirePng(String path) {
  final png = readPng(path);
  expect(png, isNotNull, reason: '$path est absent ou n\'est pas un PNG');
  return png!;
}

/// Le PNG contient bien le logo : du `brand` en masse, du `onBrand` et du
/// `brandAccent` (la géométrie exacte dans l'icône n'est pas imposée par la spec).
void expectShowsLogo(String path) {
  final pixels = decodePixels(requirePng(path));
  expect(pixels, isNotNull, reason: '$path : PNG 8 bits RVB ou RVBA attendu');
  expect(
    countColor(pixels!, token('brand', 'light')),
    greaterThan(pixels.length ~/ 4),
    reason: '$path : la tuile brand domine',
  );
  expect(
    countColor(pixels, token('on-brand', 'light')),
    greaterThan(0),
    reason: '$path : vague et jambage en on-brand',
  );
  expect(
    countColor(pixels, token('brand-accent', 'light')),
    greaterThan(0),
    reason: '$path : point en brand-accent',
  );
}

/// Toute icône, même petite, est la tuile `brand` : plus d'un quart des pixels,
/// et le logo complet dès [fullLogoFrom] px (revue de la PR : une icône Flutter par
/// défaut passait sur ses seules dimensions).
void expectBrandIcon(String path, int pixels, {int fullLogoFrom = 60}) {
  if (pixels >= fullLogoFrom) {
    expectShowsLogo(path);
    return;
  }
  final decoded = decodePixels(requirePng(path));
  expect(decoded, isNotNull, reason: '$path : PNG 8 bits RVB ou RVBA attendu');
  expect(
    countColor(decoded!, token('brand', 'light')),
    greaterThan(decoded.length ~/ 4),
    reason: '$path : la tuile brand domine',
  );
}

/// Valeur de l'élément `<item name="android:[name]">` de [xml].
String? styleItem(String xml, String name) =>
    RegExp('name="(?:android:)?$name"[^>]*>\\s*([^<\\s]+)\\s*<')
        .firstMatch(xml)
        ?.group(1);

void main() {
  group('CA1 : icône iOS', () {
    final contents = read('$iosAssets/AppIcon.appiconset/Contents.json');
    final images = contents == null
        ? <Map<String, dynamic>>[]
        : ((jsonDecode(contents) as Map)['images'] as List)
              .cast<Map<String, dynamic>>()
              .where((i) => i['filename'] != null)
              .toList();

    test('CA1 : Contents.json déclare des icônes', () {
      expect(images, isNotEmpty);
    });

    for (final image in images) {
      final file = image['filename'] as String;
      final size = double.parse((image['size'] as String).split('x').first);
      final scale = int.parse((image['scale'] as String).replaceAll('x', ''));
      final pixels = (size * scale).round();

      test('CA1 : $file fait $pixels x $pixels px, sans canal alpha', () {
        final png = requirePng('$iosAssets/AppIcon.appiconset/$file');
        expect((png.width, png.height), (pixels, pixels));
        expect(png.colorType, 2, reason: 'RVB sans canal alpha (type 2)');
        expect(png.bitDepth, 8);
      });

      test('CA1 : $file montre la tuile brand (et le logo dès 60 px)', () {
        expectBrandIcon('$iosAssets/AppIcon.appiconset/$file', pixels);
      });
    }

    test('CA1 : l\'icône de 1024 px montre le logo, plein cadre', () {
      expectShowsLogo(
        '$iosAssets/AppIcon.appiconset/Icon-App-1024x1024@1x.png',
      );
    });
  });

  group('CA1 : icône Android', () {
    const sizes = {
      'mdpi': 48,
      'hdpi': 72,
      'xhdpi': 96,
      'xxhdpi': 144,
      'xxxhdpi': 192,
    };
    sizes.forEach((density, px) {
      test('CA1 : mipmap-$density/ic_launcher.png fait $px x $px px', () {
        final png = requirePng('$res/mipmap-$density/ic_launcher.png');
        expect((png.width, png.height), (px, px));
      });

      test('CA1 : mipmap-$density/ic_launcher.png montre la tuile brand', () {
        expectBrandIcon('$res/mipmap-$density/ic_launcher.png', px);
      });
    });

    test('CA1 : l\'icône des anciennes versions montre le logo', () {
      expectShowsLogo('$res/mipmap-xxxhdpi/ic_launcher.png');
    });

    test('CA1 : l\'icône adaptative a fond, premier plan et monochrome', () {
      final xml = requireText('$res/mipmap-anydpi-v26/ic_launcher.xml');
      expect(
        xml,
        matches(RegExp(r'<background[^>]*@color/ic_launcher_background')),
      );
      expect(
        xml,
        matches(RegExp(r'<foreground[^>]*@drawable/ic_launcher_foreground')),
      );
      expect(
        xml,
        matches(RegExp(r'<monochrome[^>]*@drawable/ic_launcher_foreground')),
      );
    });

    test('CA1 : le premier plan adaptatif est un drawable vectoriel', () {
      expect(
        requireText('$res/drawable/ic_launcher_foreground.xml'),
        contains('<vector'),
      );
    });

    for (final (folder, theme) in [
      ('values', 'light'),
      ('values-night', 'dark'),
    ]) {
      test('CA1 : $folder/colors.xml, ic_launcher_background vaut brand', () {
        expect(
          androidColor('$res/$folder/colors.xml', 'ic_launcher_background'),
          token('brand', theme).toLowerCase(),
        );
      });
    }
  });

  group('CA3 : écran de lancement iOS', () {
    const launchSizes = {
      'LaunchImage.png': 112,
      'LaunchImage@2x.png': 224,
      'LaunchImage@3x.png': 336,
    };
    launchSizes.forEach((file, px) {
      test('CA3 : $file fait $px x $px px', () {
        final png = requirePng('$iosAssets/LaunchImage.imageset/$file');
        expect((png.width, png.height), (px, px));
      });
    });

    test('CA3 : le logo des images de lancement montre le logo', () {
      expectShowsLogo('$iosAssets/LaunchImage.imageset/LaunchImage@3x.png');
    });

    test('CA3 : le storyboard déclare l\'image de 112 x 112 pt', () {
      expect(
        requireText('ios/Runner/Base.lproj/LaunchScreen.storyboard'),
        contains('<image name="LaunchImage" width="112" height="112"/>'),
      );
    });

    test(
      'CA3 : le fond du storyboard reste la couleur nommée LaunchBackground',
      () {
        expect(
          requireText('ios/Runner/Base.lproj/LaunchScreen.storyboard'),
          contains('<color key="backgroundColor" name="LaunchBackground"/>'),
        );
      },
    );
  });

  group('CA3 : écran de lancement Android', () {
    test('CA3 : launch_logo.xml existe et est un drawable', () {
      expect(requireText('$res/drawable/launch_logo.xml'), contains('<'));
    });

    for (final folder in ['drawable', 'drawable-v21']) {
      test(
        'CA3 : $folder/launch_background.xml : fond surface, logo au centre',
        () {
          final xml = requireText('$res/$folder/launch_background.xml')
              .replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');
          expect(xml, contains('@color/tidemark_surface'));
          expect(xml, contains('@drawable/launch_logo'));
        },
      );
    }

    for (final (folder, theme) in [
      ('values', 'light'),
      ('values-night', 'dark'),
    ]) {
      test(
        'CA3 : $folder/colors.xml, tidemark_surface vaut surface ($theme)',
        () {
          expect(
            androidColor('$res/$folder/colors.xml', 'tidemark_surface'),
            token('surface', theme).toLowerCase(),
          );
        },
      );
    }

    for (final folder in ['values-v31', 'values-night-v31']) {
      test(
        'CA3 : $folder/styles.xml, écran de lancement du système (Android 12)',
        () {
          final xml = requireText('$res/$folder/styles.xml');
          expect(
            xml,
            matches(
              RegExp(
                r'name="(?:android:)?windowSplashScreenBackground"[^>]*>\s*@color/tidemark_surface\s*<',
              ),
            ),
          );
          expect(
            styleItem(xml, 'windowSplashScreenAnimatedIcon'),
            '@drawable/ic_launcher_foreground',
          );
          expect(
            styleItem(xml, 'windowSplashScreenIconBackgroundColor'),
            '@color/ic_launcher_background',
          );
        },
      );
    }
  });
}
