// En-tête de l'accueil (spec 009, CA7 à CA10) : titre, salutation, bouton
// « Réglages », scène décorative, compteur de coquillages, recalcul au retour au
// premier plan. Dépôt factice ; horloge : mercredi 14 octobre 2026.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/ui/screens/settings_screen.dart';
import 'package:tidemark/ui/theme/tidemark_colors.dart';

import '../support/fake_entry_repository.dart';
import '../support/home_harness.dart';
import '../support/playful_harness.dart';
import '../support/ui_harness.dart';

const light = TidemarkColors.light;
const dark = TidemarkColors.dark;

/// Retour de l'app au premier plan, après être passée en arrière-plan.
Future<void> backgroundThenResume(WidgetTester tester) async {
  final binding = tester.binding;
  for (final state in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    binding.handleAppLifecycleStateChanged(state);
  }
  await settle(tester);
}

/// Ordonnée du haut du titre du check-in : sous elle, plus rien de l'en-tête.
double checkInTop(WidgetTester tester) =>
    tester.getTopLeft(find.textContaining('Comment va ta marée')).dy;

void main() {
  group('titre, salutation et Réglages (CA7)', () {
    homeTest('CA7 : « Ton journal » est annoncé comme un titre d\'écran', (
      tester,
    ) async {
      await showHome(tester, HomeEnv(weekJournal({1: 4})));

      expect(find.text('Ton journal'), findsOneWidget);
      expect(
        tester.getSemantics(find.text('Ton journal')).flagsCollection.isHeader,
        isTrue,
      );
    });

    homeTest('CA7 : le soir, la salutation est « Bonsoir »', (tester) async {
      await showHome(tester, HomeEnv(weekJournal({1: 4})));

      expect(find.text('Bonsoir'), findsOneWidget);
      expect(find.text('Bonjour'), findsNothing);
    });

    homeTest('CA7 : le jour, la salutation est « Bonjour »', (tester) async {
      await showHome(tester, HomeEnv(weekJournal({1: 4}), now: morningNow));

      expect(find.text('Bonjour'), findsOneWidget);
      expect(find.text('Bonsoir'), findsNothing);
    });

    for (final (hour, minute, expected) in [
      (4, 59, 'Bonsoir'),
      (5, 0, 'Bonjour'),
      (17, 59, 'Bonjour'),
      (18, 0, 'Bonsoir'),
    ]) {
      homeTest('CA7 : à $hour:${minute.toString().padLeft(2, '0')} '
          '(heure de l\'horloge), « $expected »', (tester) async {
        final env = HomeEnv(
          weekJournal({1: 4}),
          now: DateTime(2026, 10, 14, hour, minute),
        );
        await showHome(tester, env);

        expect(find.text(expected), findsOneWidget);
      });
    }

    homeTest('CA7 : « Ton journal » en surtitre, au-dessus de la salutation', (
      tester,
    ) async {
      await showHome(tester, HomeEnv(weekJournal({1: 4})));

      expect(
        tester.getTopLeft(find.text('Ton journal')).dy,
        lessThan(tester.getTopLeft(find.text('Bonsoir')).dy),
      );
    });

    homeTest('CA7 : le bouton « Réglages » est en haut à droite et ouvre les '
        'Réglages', (tester) async {
      await showHome(tester, HomeEnv(weekJournal({1: 4})));

      final button = find.bySemanticsLabel('Réglages');
      expect(button, findsWidgets);
      final center = tester.getCenter(button.first);
      expect(center.dx, greaterThan(393 / 2));
      expect(center.dy, lessThan(200));
      expect(isButtonNode(tester, button.first), isTrue);

      await tester.tap(button.first);
      await settle(tester);

      expect(find.byType(SettingsScreen), findsOneWidget);
    });

    homeTest('CA7 : titre, salutation et « Réglages » sont là pendant la '
        'lecture', (tester) async {
      final repo = weekJournal({1: 4})..neverEmit = true;
      await showHome(tester, HomeEnv(repo));

      expect(find.text('Ton journal'), findsOneWidget);
      expect(find.text('Bonsoir'), findsOneWidget);
      expect(find.bySemanticsLabel('Réglages'), findsWidgets);
    });

    homeTest('CA7 : titre, salutation et « Réglages » sont là en cas d\'erreur '
        'de lecture', (tester) async {
      final repo = weekJournal({1: 4})..watchError = StateError('illisible');
      await showHome(tester, HomeEnv(repo));

      expect(find.text('Ton journal'), findsOneWidget);
      expect(find.text('Bonsoir'), findsOneWidget);
      expect(find.bySemanticsLabel('Réglages'), findsWidgets);
    });

    homeTest('CA7 : titre, salutation et « Réglages » sont là sur le journal '
        'vide', (tester) async {
      await showHome(tester, HomeEnv(FakeEntryRepository()));

      expect(find.text('Ton journal'), findsOneWidget);
      expect(find.text('Bonsoir'), findsOneWidget);
      expect(find.bySemanticsLabel('Réglages'), findsWidgets);
    });
  });

  group('scène décorative (CA8)', () {
    homeTest('CA8 : le soir, une lune (et ses étoiles) mais pas de soleil', (
      tester,
    ) async {
      final key = GlobalKey();
      await showHome(tester, HomeEnv(weekJournal({1: 4})), boundary: key);

      final pixels = await capture(tester, key);
      final limit = checkInTop(tester).round();
      expect(countColorAbove(pixels, light.moon, limit), greaterThan(30));
      expect(countColorAbove(pixels, light.sun, limit), 0);
    });

    homeTest('CA8 : le jour, un soleil mais pas de lune', (tester) async {
      final key = GlobalKey();
      final env = HomeEnv(weekJournal({1: 4}), now: morningNow);
      await showHome(tester, env, boundary: key);

      final pixels = await capture(tester, key);
      final limit = checkInTop(tester).round();
      expect(countColorAbove(pixels, light.sun, limit), greaterThan(30));
      expect(countColorAbove(pixels, light.moon, limit), 0);
    });

    for (final moment in ['soir', 'jour']) {
      homeTest('CA8 : le $moment, l\'en-tête est sur hero, avec les vagues '
          'hero-wave-1 et hero-wave-2', (tester) async {
        final key = GlobalKey();
        final env = HomeEnv(
          weekJournal({1: 4}),
          now: moment == 'soir' ? eveningNow : morningNow,
        );
        await showHome(tester, env, boundary: key);

        final pixels = await capture(tester, key);
        final limit = checkInTop(tester).round();
        expect(countColorAbove(pixels, light.hero, limit), greaterThan(2000));
        expect(
          countColorAbove(pixels, light.heroWave1, limit),
          greaterThan(200),
        );
        expect(
          countColorAbove(pixels, light.heroWave2, limit),
          greaterThan(200),
        );
      });
    }

    homeTest('CA8 : la scène n\'est pas annoncée : aucun libellé de lune, '
        'd\'étoile, de mouette, de voilier, de soleil ni de vague', (
      tester,
    ) async {
      for (final now in [eveningNow, morningNow]) {
        await showHome(tester, HomeEnv(weekJournal({1: 4}), now: now));

        final labels = semanticLabels(tester).join(' | ').toLowerCase();
        for (final word in [
          'lune',
          'étoile',
          'mouette',
          'voilier',
          'soleil',
          'vague',
          'bateau',
        ]) {
          expect(labels, isNot(contains(word)), reason: word);
        }
        await tester.pumpWidget(const SizedBox());
      }
    });

    homeTest('CA8 : avec AmbientMotion actif, les vagues se déplacent', (
      tester,
    ) async {
      final key = GlobalKey();
      final env = HomeEnv(weekJournal({1: 4}));
      await tester.pumpWidget(env.app(ambient: true, boundary: key));
      await settle(tester);
      final limit = checkInTop(tester).round();
      final before = bytesAbove(await capture(tester, key), limit);

      await tester.pump(const Duration(seconds: 3));
      final after = bytesAbove(await capture(tester, key), limit);

      expect(after, isNot(before), reason: 'l\'en-tête est resté figé');
    });

    homeTest('CA8 : sans AmbientMotion actif, l\'en-tête est immobile', (
      tester,
    ) async {
      final key = GlobalKey();
      final env = HomeEnv(weekJournal({1: 4}));
      await tester.pumpWidget(env.app(boundary: key));
      await settle(tester);
      final limit = checkInTop(tester).round();
      final before = bytesAbove(await capture(tester, key), limit);

      await tester.pump(const Duration(seconds: 3));
      final after = bytesAbove(await capture(tester, key), limit);

      expect(after, before);
    });

    homeTest('CA8 : quand le téléphone demande de réduire les animations, '
        'l\'en-tête est immobile', (tester) async {
      final key = GlobalKey();
      final env = HomeEnv(weekJournal({1: 4}));
      await tester.pumpWidget(
        env.app(ambient: true, reduceMotion: true, boundary: key),
      );
      await settle(tester);
      final limit = checkInTop(tester).round();
      final before = bytesAbove(await capture(tester, key), limit);

      await tester.pump(const Duration(seconds: 3));
      final after = bytesAbove(await capture(tester, key), limit);

      expect(after, before);
    });
  });

  group('compteur de coquillages (CA9)', () {
    homeTest('CA9 : « Aucun coquillage cette semaine » quand seules des '
        'entrées d\'autres semaines existent', (tester) async {
      final repo = FakeEntryRepository(clock: () => eveningNow)
        ..seed(mood: 3, createdAt: DateTime(2026, 10, 9, 12))
        ..seed(mood: 4, createdAt: DateTime(2026, 10, 19, 0, 5));
      await showHome(tester, HomeEnv(repo));

      expect(find.text('Aucun coquillage cette semaine'), findsOneWidget);
    });

    homeTest('CA9 : « 1 coquillage cette semaine »', (tester) async {
      await showHome(tester, HomeEnv(weekJournal({2: 3})));

      expect(find.text('1 coquillage cette semaine'), findsOneWidget);
    });

    homeTest('CA9 : « N coquillages cette semaine », toutes les entrées '
        'comptées, plusieurs le même jour comprises', (tester) async {
      final repo = FakeEntryRepository(clock: () => eveningNow)
        ..seed(mood: 3, createdAt: octoberDay(1, 8))
        ..seed(mood: 4, createdAt: octoberDay(1, 20))
        ..seed(mood: 1, createdAt: octoberDay(2))
        ..seed(mood: 5, createdAt: octoberDay(3))
        ..seed(mood: 2, createdAt: DateTime(2026, 10, 5, 9));
      await showHome(tester, HomeEnv(repo));

      expect(find.text('4 coquillages cette semaine'), findsOneWidget);
    });

    homeTest('CA9 : une entrée en détresse ou non analysée compte comme les '
        'autres', (tester) async {
      final repo = FakeEntryRepository(clock: () => eveningNow)
        ..seed(mood: 1, text: 'envie de mourir', createdAt: octoberDay(1))
        ..seed(mood: 3, createdAt: octoberDay(2))
        ..seed(mood: 4, text: 'Belle journée', createdAt: octoberDay(3));
      await showHome(tester, HomeEnv(repo));

      expect(find.text('3 coquillages cette semaine'), findsOneWidget);
    });

    homeTest('CA9 : le compteur suit l\'ajout d\'une entrée', (tester) async {
      final repo = weekJournal({1: 4});
      await showHome(tester, HomeEnv(repo));
      expect(find.text('1 coquillage cette semaine'), findsOneWidget);

      await tester.runAsync(() => repo.addEntry(mood: 3));
      await settle(tester);

      expect(find.text('2 coquillages cette semaine'), findsOneWidget);
    });

    homeTest('CA9 : la semaine suit l\'horloge : le lundi suivant, le compteur '
        'repart à zéro', (tester) async {
      final env = HomeEnv(
        weekJournal({1: 4, 2: 3}),
        now: DateTime(2026, 10, 19, 9),
      );
      await showHome(tester, env);

      expect(find.text('Aucun coquillage cette semaine'), findsOneWidget);
    });

    homeTest('CA9 : pas de compteur sur le journal vide', (tester) async {
      await showHome(tester, HomeEnv(FakeEntryRepository()));

      expect(find.textContaining('coquillage'), findsNothing);
    });
  });

  group('retour au premier plan (CA10)', () {
    homeTest('CA10 : après le soir, au retour du matin, la salutation et le '
        'titre du check-in sont recalculés', (tester) async {
      final env = HomeEnv(weekJournal({1: 4}));
      await showHome(tester, env);
      expect(find.text('Bonsoir'), findsOneWidget);
      expect(find.text(checkInEvening), findsOneWidget);

      env.now = DateTime(2026, 10, 15, 7, 30);
      await backgroundThenResume(tester);

      expect(find.text('Bonjour'), findsOneWidget);
      expect(find.text('Bonsoir'), findsNothing);
      expect(find.text(checkInDay), findsOneWidget);
      expect(find.text(checkInEvening), findsNothing);
    });

    homeTest('CA10 : la scène suit : la lune cède la place au soleil', (
      tester,
    ) async {
      final key = GlobalKey();
      final env = HomeEnv(weekJournal({1: 4}));
      await showHome(tester, env, boundary: key);
      final limit = checkInTop(tester).round();
      expect(
        countColorAbove(await capture(tester, key), light.moon, limit),
        greaterThan(30),
      );

      env.now = DateTime(2026, 10, 15, 7, 30);
      await backgroundThenResume(tester);

      final pixels = await capture(tester, key);
      final newLimit = checkInTop(tester).round();
      expect(countColorAbove(pixels, light.sun, newLimit), greaterThan(30));
      expect(countColorAbove(pixels, light.moon, newLimit), 0);
    });

    homeTest('CA10 : d\'une semaine à l\'autre, le compteur est recalculé', (
      tester,
    ) async {
      final env = HomeEnv(weekJournal({1: 4, 2: 3}));
      await showHome(tester, env);
      expect(find.text('2 coquillages cette semaine'), findsOneWidget);

      env.now = DateTime(2026, 10, 19, 9);
      await backgroundThenResume(tester);

      expect(find.text('Aucun coquillage cette semaine'), findsOneWidget);
    });

    homeTest('CA10 : sans changement d\'horloge, rien ne change', (
      tester,
    ) async {
      final env = HomeEnv(weekJournal({1: 4, 2: 3}));
      await showHome(tester, env);

      await backgroundThenResume(tester);

      expect(find.text('Bonsoir'), findsOneWidget);
      expect(find.text('2 coquillages cette semaine'), findsOneWidget);
    });
  });

  group('texte à 200 % et thème sombre (CA27, CA28)', () {
    homeTest('CA27 : l\'en-tête à 200 % ne déborde pas et rien n\'y est '
        'tronqué', (tester) async {
      final env = HomeEnv(weekJournal({1: 4, 2: 3}));
      await showHome(tester, env, textScale: 2.0);

      expect(tester.takeException(), isNull);
      for (final text in [
        'Ton journal',
        'Bonsoir',
        '2 coquillages cette semaine',
      ]) {
        final rect = tester.getRect(find.text(text));
        expect(rect.left, greaterThanOrEqualTo(0), reason: text);
        expect(rect.right, lessThanOrEqualTo(393), reason: text);
      }
    }, tall: false);

    homeTest('CA28 : thème sombre, l\'en-tête est sur le hero sombre et la '
        'page sur la surface sombre', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final key = GlobalKey();
      await showHome(tester, HomeEnv(weekJournal({1: 4})), boundary: key);

      final pixels = await capture(tester, key);
      final limit = checkInTop(tester).round();
      expect(countColorAbove(pixels, dark.hero, limit), greaterThan(2000));
      expect(countColorAbove(pixels, dark.heroWave1, limit), greaterThan(200));
      expect(countColorAbove(pixels, light.hero, limit), 0);
      expect(countColor(pixels, dark.surface), greaterThan(2000));
      expect(countColor(pixels, light.surface), 0);
    });
  });
}
