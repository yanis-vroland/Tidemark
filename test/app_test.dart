import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/main.dart';
import 'package:tidemark/ui/theme/tidemark_colors.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'l\'accueil s\'affiche avec le fond de la charte ($brightness)',
      (tester) async {
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

        await tester.pumpWidget(const TidemarkApp());

        expect(find.text('Tidemark'), findsOneWidget);
        final expected = brightness == Brightness.dark
            ? TidemarkColors.dark.surface
            : TidemarkColors.light.surface;
        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
        final theme = Theme.of(tester.element(find.byType(Scaffold)));
        expect(
          scaffold.backgroundColor ?? theme.scaffoldBackgroundColor,
          expected,
        );
      },
    );
  }
}
