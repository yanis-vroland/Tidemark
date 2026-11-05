// Bulles d'air de la saisie (spec 008, « Mouvement », et CA9) : animation
// d'ambiance décorative, sous le contenu, qui ne tourne qu'avec `AmbientMotion`
// et sans « réduire les animations ». Dépôt factice.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/ui/screens/entry_form_screen.dart';
import 'package:tidemark/ui/widgets/air_bubbles.dart';

import '../support/fake_entry_repository.dart';
import '../support/fake_model_downloader.dart';
import '../support/fake_settings_repository.dart';
import '../support/playful_harness.dart';
import '../support/ui_harness.dart';

Widget formApp({bool ambient = false, bool reduceMotion = false}) => ambientApp(
  EntryFormScreen(
    repository: FakeEntryRepository(),
    settings: FakeSettingsRepository(),
    downloader: FakeModelDownloader(readyModel),
  ),
  ambient: ambient,
  reduceMotion: reduceMotion,
);

Finder get air => find.byType(AirBubbles);

void airTest(String description, Future<void> Function(WidgetTester) body) {
  testWidgets(description, (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    try {
      await body(tester);
    } finally {
      await tester.pumpWidget(const SizedBox());
      semantics.dispose();
    }
  });
}

void main() {
  airTest('avec `AmbientMotion`, des bulles d\'air montent sous la saisie', (
    tester,
  ) async {
    await tester.pumpWidget(formApp(ambient: true));
    await tester.pump(const Duration(milliseconds: 100));

    expect(air, findsOneWidget);
    final animation = tester.widget<AirBubbles>(air).animation;
    final before = animation.value;
    await tester.pump(const Duration(seconds: 2));
    expect(animation.value, isNot(before), reason: 'les bulles montent');
    expect(animation.status, AnimationStatus.forward);
  });

  airTest('les bulles sont décoratives : jamais annoncées, jamais touchables, '
      'peintes sous le contenu', (tester) async {
    await tester.pumpWidget(formApp(ambient: true));
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.descendant(of: air, matching: find.byType(ExcludeSemantics)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: air, matching: find.byType(IgnorePointer)),
      findsOneWidget,
    );
    // Sous le contenu : premier enfant de la pile, avant le contenu (SafeArea).
    final stack = tester.widget<Stack>(
      find.ancestor(of: air, matching: find.byType(Stack)).first,
    );
    expect(stack.children.last, isA<SafeArea>());
    expect(
      find.descendant(of: find.byWidget(stack.children.first), matching: air),
      findsOneWidget,
    );
    // Le contenu reste touchable par-dessus : choisir une humeur marche.
    expect(find.text('Choisis une humeur pour enregistrer.'), findsOneWidget);
    await pickMood(tester, 4);
    expect(find.text('Choisis une humeur pour enregistrer.'), findsNothing);
  });

  airTest('sans `AmbientMotion`, aucune bulle d\'air', (tester) async {
    await tester.pumpWidget(formApp());
    await tester.pump(const Duration(milliseconds: 100));

    expect(air, findsNothing);
  });

  airTest('avec « réduire les animations », aucune bulle d\'air, même avec '
      '`AmbientMotion`', (tester) async {
    await tester.pumpWidget(formApp(ambient: true, reduceMotion: true));
    await tester.pump(const Duration(milliseconds: 100));

    expect(air, findsNothing);
    expect(tester.hasRunningAnimations, isFalse);
  });
}
