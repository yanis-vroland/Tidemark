import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/ui/theme/tidemark_colors.dart';
import 'package:tidemark/ui/theme/tidemark_theme.dart';
import 'package:tidemark/ui/theme/tidemark_typography.dart';

void main() {
  group('couleurs des pastilles d\'humeur', () {
    for (final colors in [TidemarkColors.light, TidemarkColors.dark]) {
      test('chaque humeur a sa couleur, dans l\'ordre', () {
        expect(
          [for (var mood = 1; mood <= 5; mood++) colors.moodColor(mood)],
          [
            colors.mood1,
            colors.mood2,
            colors.mood3,
            colors.mood4,
            colors.mood5,
          ],
        );
      });

      test('le chiffre est en on-mood-1 sur l\'humeur 1 seulement', () {
        expect(colors.onMoodColor(1), colors.onMood1);
        for (var mood = 2; mood <= 5; mood++) {
          expect(colors.onMoodColor(mood), colors.onMood);
        }
      });

      test('une humeur hors de 1 à 5 est refusée', () {
        expect(() => colors.moodColor(0), throwsRangeError);
        expect(() => colors.moodColor(6), throwsRangeError);
      });
    }
  });

  testWidgets('un texte sans style prend le style body de la charte', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTidemarkTheme(Brightness.light),
        home: const Scaffold(body: Text('Entrée')),
      ),
    );

    final style = DefaultTextStyle.of(tester.element(find.text('Entrée')))
        .style;
    expect(style.fontFamily, TidemarkTypography.body.fontFamily);
    expect(style.fontSize, TidemarkTypography.body.fontSize);
    expect(style.fontVariations, TidemarkTypography.body.fontVariations);
    expect(style.color, TidemarkColors.light.ink);
  });
}
