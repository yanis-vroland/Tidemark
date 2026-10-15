import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/main.dart';
import 'package:tidemark/ui/theme/tidemark_colors.dart';

import 'support/fake_entry_repository.dart';
import 'support/fake_model_downloader.dart';
import 'support/fake_settings_repository.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'l\'accueil est la liste, avec le fond de la charte ($brightness)',
      (tester) async {
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

        await tester.pumpWidget(
          TidemarkApp(
            repository: FakeEntryRepository(),
            settings: FakeSettingsRepository(),
            clock: () => DateTime(2026, 10, 14, 21, 40),
            downloader: FakeModelDownloader(readyModel),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Ton journal'), findsOneWidget);
        expect(find.text('Ta première entrée apparaîtra ici'), findsOneWidget);
        expect(find.text('Nouvelle entrée'), findsOneWidget);
        final expected = brightness == Brightness.dark
            ? TidemarkColors.dark.surface
            : TidemarkColors.light.surface;
        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
        final theme = Theme.of(tester.element(find.byType(Scaffold).first));
        expect(
          scaffold.backgroundColor ?? theme.scaffoldBackgroundColor,
          expected,
        );
      },
    );
  }
}
