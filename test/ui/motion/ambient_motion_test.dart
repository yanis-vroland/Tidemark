// Mouvement d'ambiance (spec 008, CA8 à CA10) : `AmbientMotion`, coupure par le
// réglage du téléphone, activation par `main` seulement.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/main.dart';
import 'package:tidemark/ui/motion/ambient_motion.dart';
import 'package:tidemark/ui/widgets/mood_bubble.dart';

import '../../support/fake_entry_repository.dart';
import '../../support/fake_model_downloader.dart';
import '../../support/fake_settings_repository.dart';
import '../../support/playful_harness.dart';
import '../../support/ui_harness.dart';

/// Valeur de `AmbientMotion.of` vue d'un enfant, dans [tree].
Future<bool> readOf(
  WidgetTester tester, {
  required bool? enabled,
  bool reduceMotion = false,
}) async {
  late bool seen;
  Widget probe = Builder(
    builder: (context) {
      seen = AmbientMotion.of(context);
      return const SizedBox();
    },
  );
  if (enabled != null) {
    probe = AmbientMotion(enabled: enabled, child: probe);
  }
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: probe,
    ),
  );
  return seen;
}

Widget bubbleScreen({
  required bool ambient,
  bool reduceMotion = false,
  Key? boundary,
}) => ambientApp(
  Center(
    child: RepaintBoundary(
      key: boundary,
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: MoodBubble(mood: 4, size: 150),
      ),
    ),
  ),
  ambient: ambient,
  reduceMotion: reduceMotion,
);

void main() {
  group('AmbientMotion.of', () {
    testWidgets('CA9 : sans AmbientMotion au-dessus, faux', (tester) async {
      expect(await readOf(tester, enabled: null), isFalse);
    });

    testWidgets('CA9 : AmbientMotion(enabled: false), faux', (tester) async {
      expect(await readOf(tester, enabled: false), isFalse);
    });

    testWidgets('CA8 : AmbientMotion(enabled: true), vrai', (tester) async {
      expect(await readOf(tester, enabled: true), isTrue);
    });

    testWidgets(
      'CA9 : AmbientMotion(enabled: true) mais le téléphone demande de '
      'réduire les animations, faux',
      (tester) async {
        expect(
          await readOf(tester, enabled: true, reduceMotion: true),
          isFalse,
        );
      },
    );

    testWidgets('CA9 : un changement de réglage est suivi à la reconstruction '
        'suivante', (tester) async {
      late bool seen;
      Widget tree({required bool enabled, required bool reduce}) => MediaQuery(
        data: MediaQueryData(disableAnimations: reduce),
        child: AmbientMotion(
          enabled: enabled,
          child: Builder(
            builder: (context) {
              seen = AmbientMotion.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      await tester.pumpWidget(tree(enabled: true, reduce: false));
      expect(seen, isTrue);
      await tester.pumpWidget(tree(enabled: true, reduce: true));
      expect(seen, isFalse);
      await tester.pumpWidget(tree(enabled: true, reduce: false));
      expect(seen, isTrue);
      await tester.pumpWidget(tree(enabled: false, reduce: false));
      expect(seen, isFalse);
    });
  });

  group('bulle animée', () {
    testWidgets('CA8 : sous AmbientMotion activé, des animations tournent', (
      tester,
    ) async {
      usePhoneScreen(tester);
      await tester.pumpWidget(bubbleScreen(ambient: true));
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.hasRunningAnimations, isTrue);
    });

    testWidgets('CA9 : sans AmbientMotion activé, aucune animation ne tourne', (
      tester,
    ) async {
      usePhoneScreen(tester);
      await tester.pumpWidget(bubbleScreen(ambient: false));
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('CA9 : si le téléphone demande de réduire les animations, '
        'aucune animation ne tourne', (tester) async {
      usePhoneScreen(tester);
      await tester.pumpWidget(bubbleScreen(ambient: true, reduceMotion: true));
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('CA8 : la bulle bouge : deux instants du cycle donnent deux '
        'images différentes', (tester) async {
      usePhoneScreen(tester);
      final key = GlobalKey();
      await tester.pumpWidget(bubbleScreen(ambient: true, boundary: key));
      await tester.pump(const Duration(milliseconds: 100));
      final first = await capture(tester, key);
      await tester.pump(const Duration(milliseconds: 1600));
      final second = await capture(tester, key);

      expect(second.bytes, isNot(first.bytes));
    });

    testWidgets(
      'CA9 : animations coupées, la bulle est immobile, à sa position '
      'de repos',
      (tester) async {
        usePhoneScreen(tester);
        final key = GlobalKey();
        await tester.pumpWidget(
          bubbleScreen(ambient: true, reduceMotion: true, boundary: key),
        );
        await tester.pump(const Duration(milliseconds: 100));
        final first = await capture(tester, key);
        await tester.pump(const Duration(milliseconds: 1600));
        final second = await capture(tester, key);
        await tester.pump(const Duration(milliseconds: 2100));
        final third = await capture(tester, key);

        expect(second.bytes, first.bytes);
        expect(third.bytes, first.bytes);
      },
    );

    testWidgets('CA9 : la position de repos est la même avec ou sans '
        'AmbientMotion', (tester) async {
      usePhoneScreen(tester);
      final key = GlobalKey();
      await tester.pumpWidget(bubbleScreen(ambient: false, boundary: key));
      await tester.pump(const Duration(milliseconds: 100));
      final withoutAmbient = await capture(tester, key);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        bubbleScreen(ambient: true, reduceMotion: true, boundary: key),
      );
      await tester.pump(const Duration(milliseconds: 100));
      final reduced = await capture(tester, key);

      expect(reduced.bytes, withoutAmbient.bytes);
    });

    testWidgets('cas limite : animations coupées en cours d\'usage, elles '
        's\'arrêtent à la reconstruction suivante', (tester) async {
      usePhoneScreen(tester);
      await tester.pumpWidget(bubbleScreen(ambient: true));
      await tester.pump(const Duration(milliseconds: 700));
      expect(tester.hasRunningAnimations, isTrue);

      await tester.pumpWidget(bubbleScreen(ambient: true, reduceMotion: true));
      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.hasRunningAnimations, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('CA8 : la bulle d\'une carte de la liste, avec animations '
        'd\'ambiance, anime', (tester) async {
      usePhoneScreen(tester);
      final repo = FakeEntryRepository(clock: () => fixedNow)
        ..seed(mood: 4, text: 'Balade.', createdAt: fixedNow);
      await tester.pumpWidget(fullApp(repo, ambientMotion: true));
      await settle(tester);

      expect(find.byType(MoodBubble), findsWidgets);
      expect(tester.hasRunningAnimations, isTrue);
    });
  });

  group('activation par main (CA10)', () {
    testWidgets('CA10 : TidemarkApp seul n\'active pas AmbientMotion', (
      tester,
    ) async {
      usePhoneScreen(tester);
      final repo = FakeEntryRepository(clock: () => fixedNow)
        ..seed(mood: 4, text: 'Balade.', createdAt: fixedNow);
      await tester.pumpWidget(fullApp(repo));
      await settle(tester);

      final motions = tester.widgetList<AmbientMotion>(
        find.byType(AmbientMotion),
      );
      expect(motions.where((m) => m.enabled), isEmpty);
      expect(find.byType(MoodBubble), findsWidgets);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('CA10 : TidemarkApp(ambientMotion: true) l\'active', (
      tester,
    ) async {
      usePhoneScreen(tester);
      final repo = FakeEntryRepository(clock: () => fixedNow)
        ..seed(mood: 4, text: 'Balade.', createdAt: fixedNow);
      await tester.pumpWidget(fullApp(repo, ambientMotion: true));
      await settle(tester);

      final motions = tester.widgetList<AmbientMotion>(
        find.byType(AmbientMotion),
      );
      expect(motions.where((m) => m.enabled), isNotEmpty);
      expect(tester.hasRunningAnimations, isTrue);
    });

    Future<Journal> journal() async => Journal(
      entries: FakeEntryRepository(clock: () => fixedNow)
        ..seed(mood: 3, createdAt: fixedNow),
      settings: FakeSettingsRepository(),
      downloader: FakeModelDownloader(readyModel),
    );

    testWidgets('CA10 : startApp sans option n\'active pas AmbientMotion', (
      tester,
    ) async {
      usePhoneScreen(tester);
      final app = await tester.runAsync(() => startApp(open: journal));
      await tester.pumpWidget(app!);
      await settle(tester);

      final motions = tester.widgetList<AmbientMotion>(
        find.byType(AmbientMotion),
      );
      expect(motions.where((m) => m.enabled), isEmpty);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('CA10 : startApp(ambientMotion: true) l\'active', (
      tester,
    ) async {
      usePhoneScreen(tester);
      final app = await tester.runAsync(
        () => startApp(open: journal, ambientMotion: true),
      );
      await tester.pumpWidget(app!);
      await settle(tester);

      final motions = tester.widgetList<AmbientMotion>(
        find.byType(AmbientMotion),
      );
      expect(motions.where((m) => m.enabled), isNotEmpty);
    });

    test('CA10 : startApp et TidemarkApp ont ambientMotion = false par '
        'défaut', () {
      final source = File('lib/main.dart').readAsStringSync();
      expect(
        RegExp(r'(bool\s+|this\.)ambientMotion\s*=\s*false')
            .allMatches(source)
            .length,
        greaterThanOrEqualTo(2),
        reason: 'startApp et TidemarkApp',
      );
    });

    test('CA10 : main() passe ambientMotion: true à chaque startApp', () {
      final source = File('lib/main.dart').readAsStringSync();
      final start = source.indexOf('Future<void> main()');
      expect(start, isNonNegative);
      final end = source.indexOf(
        'Stream<AppLifecycleState> appLifecycleStates',
      );
      final body = source.substring(start, end);

      final calls = RegExp(r'startApp\(').allMatches(body).length;
      final enabled = RegExp(r'ambientMotion:\s*true').allMatches(body).length;
      expect(calls, 2, reason: 'ouverture et redémarrage après suppression');
      expect(enabled, calls);
    });
  });
}
