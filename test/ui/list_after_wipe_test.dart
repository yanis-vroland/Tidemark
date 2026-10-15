// Liste des entrées après une suppression totale (spec 005 ; CA18, CA33 à CA35) :
// état vide habituel, avec le message de fin au-dessus.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/main.dart';
import 'package:tidemark/ui/theme/tidemark_colors.dart';

import '../support/fake_entry_repository.dart';
import '../support/fake_model_downloader.dart';
import '../support/fake_settings_repository.dart';
import '../support/ui_harness.dart';
import '../support/wipe_harness.dart';

const doneTitle = 'Toutes tes données ont été supprimées';
const doneBody = 'Ton journal repart de zéro, sur ce téléphone.';
const emptyTitle = 'Ta première entrée apparaîtra ici';
const emptyBody =
    'Note ton humeur en quelques secondes. Tout reste sur ton téléphone.';

Widget app({required bool wiped}) => TidemarkApp(
  repository: FakeEntryRepository(),
  settings: FakeSettingsRepository(),
  downloader: FakeModelDownloader(readyModel),
  wiped: wiped,
);

void listTest(
  String description,
  Future<void> Function(WidgetTester tester) body, {
  bool tall = false,
}) {
  testWidgets(description, (tester) async {
    if (tall) {
      useTallScreen(tester);
    } else {
      usePhoneScreen(tester);
    }
    final semantics = tester.ensureSemantics();
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    try {
      await body(tester);
    } finally {
      semantics.dispose();
    }
  });
}

Future<void> show(WidgetTester tester, {bool wiped = true}) async {
  await tester.pumpWidget(app(wiped: wiped));
  await settle(tester);
}

/// Un fond de [color] derrière le texte [text] (carte du message de fin).
Finder cardBehind(String text, Color color) => find.ancestor(
  of: find.text(text),
  matching: find.byWidgetPredicate((widget) {
    if (widget is ColoredBox) return widget.color == color;
    if (widget is DecoratedBox) {
      final decoration = widget.decoration;
      return decoration is BoxDecoration && decoration.color == color;
    }
    return false;
  }),
);

void main() {
  group('CA18 : message de fin', () {
    listTest('CA18 : « Toutes tes données ont été supprimées » et « Ton '
        'journal repart de zéro, sur ce téléphone. » au-dessus de l\'état vide '
        'habituel', (tester) async {
      await show(tester);

      expect(find.text(doneTitle), findsOneWidget);
      expect(find.text(doneBody), findsOneWidget);
      expect(find.text(emptyTitle), findsOneWidget);
      expect(find.text(emptyBody), findsOneWidget);
      expect(find.text('Nouvelle entrée'), findsOneWidget);
      final tops = [
        tester.getTopLeft(find.text('Ton journal')).dy,
        tester.getTopLeft(find.text(doneTitle)).dy,
        tester.getTopLeft(find.text(doneBody)).dy,
        tester.getTopLeft(find.text(emptyTitle)).dy,
      ];
      expect(tops, [...tops]..sort());
      expect(tops.toSet(), hasLength(4));
    });

    listTest('CA18 : sans suppression, aucun message de fin', (tester) async {
      await show(tester, wiped: false);

      expect(find.text(doneTitle), findsNothing);
      expect(find.text(doneBody), findsNothing);
      expect(find.text(emptyTitle), findsOneWidget);
    });
  });

  group('CA33 : lecteur d\'écran', () {
    listTest('CA33 : le message de fin est annoncé dès son apparition', (
      tester,
    ) async {
      await show(tester);

      expect(isAnnounced(tester, doneTitle), isTrue);
      expect(isAnnounced(tester, doneBody), isTrue);
    });

    listTest('CA33 : sans suppression, rien n\'est annoncé comme message de '
        'fin', (tester) async {
      await show(tester, wiped: false);

      expect(isAnnounced(tester, doneTitle), isFalse);
    });
  });

  group('CA34 : texte du système à 200 %', () {
    listTest(
      'CA34 : la liste défile, rien ne déborde, le message est entier et '
      '« Nouvelle entrée » est atteignable',
      (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2.0;
        await show(tester);

        for (final fragment in [doneTitle, doneBody, emptyTitle, emptyBody]) {
          await scrollTo(tester, find.text(fragment));
          expect(
            paragraphOf(tester, fragment).truncated,
            isFalse,
            reason: fragment,
          );
        }
        await scrollTo(tester, find.text('Nouvelle entrée'));
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('CA35 : thème sombre', () {
    listTest('CA35 : le message de fin est sur le fond tide-soft du thème '
        'sombre', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await show(tester);

      expect(
        Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
        Brightness.dark,
      );
      expect(cardBehind(doneTitle, TidemarkColors.dark.tideSoft), findsWidgets);
      expect(
        cardBehind(doneTitle, TidemarkColors.light.tideSoft),
        findsNothing,
      );
    });

    listTest('CA35 : thème clair, le message est sur le fond tide-soft '
        'clair', (tester) async {
      await show(tester);

      expect(
        cardBehind(doneTitle, TidemarkColors.light.tideSoft),
        findsWidgets,
      );
    });
  });
}
