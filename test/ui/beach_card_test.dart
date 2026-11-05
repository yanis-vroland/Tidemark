// Plage de la semaine, carte de l'accueil (spec 009, CA14 à CA18, CA27, CA28) : sept
// jours de « L » à « D », bulle `bubble-sm` d'autant plus haute que l'humeur du jour
// est haute, cercle pointillé `day-empty-<i>` sans entrée, annonce d'un seul bouton,
// ouverture de l'onglet « Semaine ». Dépôt factice ; horloge : mercredi 14 octobre
// 2026 (semaine du 12 au 18).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/ui/screens/entry_list_screen.dart';
import 'package:tidemark/ui/screens/weekly_review_screen.dart';
import 'package:tidemark/ui/theme/tidemark_colors.dart';
import 'package:tidemark/ui/widgets/mood_bubble.dart';
import 'package:tidemark/ui/widgets/tidemark_logo.dart';

import '../support/distress_harness.dart' show expectNoTruncatedText;
import '../support/fake_entry_repository.dart';
import '../support/fake_model_downloader.dart';
import '../support/fake_settings_repository.dart';
import '../support/home_harness.dart';
import '../support/playful_harness.dart';
import '../support/ui_harness.dart';

const light = TidemarkColors.light;
const dark = TidemarkColors.dark;
const bubbleSm = 36.0;

Finder get smallBubbles => bubbleFinder(bubbleSm);

Finder dayEmpty(int index) => find.byKey(Key('day-empty-$index'));

/// Lettres de jours de la plage, de gauche à droite.
List<String> initialsOnScreen(WidgetTester tester) {
  final found = <({double x, String letter})>[];
  for (final element in find.byType(Text).evaluate()) {
    final text = (element.widget as Text).data;
    if (text == null || !dayInitials.contains(text) || text.length != 1) {
      continue;
    }
    final box = element.renderObject! as RenderBox;
    found.add((x: box.localToGlobal(Offset.zero).dx, letter: text));
  }
  found.sort((a, b) => a.x.compareTo(b.x));
  return [for (final f in found) f.letter];
}

/// Bulle de la plage de l'humeur [mood] (la première, dans l'ordre de l'arbre).
Finder smallBubbleOf(int mood) => find.byWidgetPredicate(
  (w) => w is MoodBubble && w.size == bubbleSm && w.mood == mood,
);

void main() {
  group('la carte (CA14)', () {
    homeTest('CA14 : « Ta plage cette semaine » est sous le check-in et avant '
        'le premier jour de la liste', (tester) async {
      await showHome(tester, HomeEnv(weekJournal({1: 4, 3: 2})));

      expect(find.text(beachTitle), findsOneWidget);
      final checkIn = tester.getTopLeft(find.text(checkInEvening)).dy;
      final beach = tester.getTopLeft(find.text(beachTitle)).dy;
      final firstDay = tester.getTopLeft(find.text("Aujourd'hui")).dy;
      expect(beach, greaterThan(checkIn));
      expect(beach, lessThan(firstDay));
    });

    homeTest('CA14 : les sept jours, de « L » à « D »', (tester) async {
      await showHome(tester, HomeEnv(weekJournal({1: 4})));

      expect(initialsOnScreen(tester), dayInitials);
    });

    homeTest('CA14 : un jour noté a une bulle de 36 points de l\'humeur du '
        'jour, dans la colonne de ce jour', (tester) async {
      await showHome(tester, HomeEnv(weekJournal({1: 4, 3: 2, 6: 5})));

      final moods = [for (final b in bubblesOfSize(tester, bubbleSm)) b.mood];
      expect(moods..sort(), [2, 4, 5]);
      final letters = find.byType(Text).evaluate().where((e) {
        final d = (e.widget as Text).data;
        return d != null && d.length == 1 && dayInitials.contains(d);
      }).toList();
      double columnX(int day) {
        final sorted = [
          for (final e in letters)
            (e.renderObject! as RenderBox).localToGlobal(
              (e.renderObject! as RenderBox).size.center(Offset.zero),
            ),
        ]..sort((a, b) => a.dx.compareTo(b.dx));
        return sorted[day].dx;
      }

      for (final (day, mood) in [(0, 4), (2, 2), (5, 5)]) {
        expect(
          tester.getCenter(smallBubbleOf(mood)).dx,
          closeTo(columnX(day), 8),
          reason: 'humeur $mood, jour $day',
        );
      }
    });

    homeTest('CA14 : plus l\'humeur est haute, plus la bulle est haute : 8 '
        'points par cran au-dessus de 1', (tester) async {
      await showHome(tester, HomeEnv(weekJournal({1: 1, 2: 3, 3: 5, 4: 4})));

      final bottom = {
        for (final m in [1, 3, 4, 5])
          m: tester.getBottomLeft(smallBubbleOf(m)).dy,
      };
      expect(bottom[1]! - bottom[3]!, closeTo(16, 0.5));
      expect(bottom[1]! - bottom[4]!, closeTo(24, 0.5));
      expect(bottom[1]! - bottom[5]!, closeTo(32, 0.5));
    });

    homeTest('CA14 : un jour sans entrée, passé ou à venir, a un cercle '
        'pointillé ; un jour noté n\'en a pas', (tester) async {
      await showHome(tester, HomeEnv(weekJournal({1: 4, 3: 2})));

      for (final i in [1, 3, 4, 5, 6]) {
        expect(dayEmpty(i), findsOneWidget, reason: 'jour $i sans entrée');
      }
      for (final i in [0, 2]) {
        expect(dayEmpty(i), findsNothing, reason: 'jour $i noté');
      }
      expect(smallBubbles, findsNWidgets(2));
    });

    homeTest('CA14 : une semaine sans aucune entrée en cours : sept cercles '
        'pointillés (le journal a des entrées d\'une autre semaine)', (
      tester,
    ) async {
      final repo = FakeEntryRepository(clock: () => eveningNow)
        ..seed(mood: 3, createdAt: DateTime(2026, 10, 7, 12));
      await showHome(tester, HomeEnv(repo));

      expect(find.text(beachTitle), findsOneWidget);
      for (var i = 0; i < 7; i++) {
        expect(dayEmpty(i), findsOneWidget, reason: 'jour $i');
      }
      expect(smallBubbles, findsNothing);
    });

    homeTest('CA14 : une semaine complète : sept bulles, aucun cercle', (
      tester,
    ) async {
      await showHome(
        tester,
        HomeEnv(weekJournal({1: 1, 2: 2, 3: 3, 4: 4, 5: 5, 6: 4, 7: 3})),
      );

      expect(smallBubbles, findsNWidgets(7));
      for (var i = 0; i < 7; i++) {
        expect(dayEmpty(i), findsNothing);
      }
    });

    homeTest('CA14 : plusieurs entrées le même jour : la bulle montre '
        'l\'humeur de la dernière', (tester) async {
      final repo = FakeEntryRepository(clock: () => eveningNow)
        ..seed(mood: 1, createdAt: octoberDay(2, 8))
        ..seed(mood: 5, createdAt: octoberDay(2, 20))
        ..seed(mood: 3, createdAt: octoberDay(2, 14));
      await showHome(tester, HomeEnv(repo));

      final moods = [for (final b in bubblesOfSize(tester, bubbleSm)) b.mood];
      expect(moods, [5]);
      expect(dayEmpty(1), findsNothing);
    });

    homeTest('CA14 : les entrées d\'une autre semaine ne dessinent rien', (
      tester,
    ) async {
      final repo = FakeEntryRepository(clock: () => eveningNow)
        ..seed(mood: 5, createdAt: DateTime(2026, 10, 11, 23, 59))
        ..seed(mood: 1, createdAt: DateTime(2026, 10, 19, 0, 0))
        ..seed(mood: 3, createdAt: octoberDay(4));
      await showHome(tester, HomeEnv(repo));

      expect([for (final b in bubblesOfSize(tester, bubbleSm)) b.mood], [3]);
      expect(dayEmpty(3), findsNothing);
      expect(dayEmpty(0), findsOneWidget);
      expect(dayEmpty(6), findsOneWidget);
    });

    homeTest('CA14 : une entrée en détresse ou non analysée est dessinée '
        'comme les autres', (tester) async {
      final repo = FakeEntryRepository(clock: () => eveningNow)
        ..seed(mood: 1, text: 'envie de mourir', createdAt: octoberDay(1))
        ..seed(mood: 2, createdAt: octoberDay(2));
      await showHome(tester, HomeEnv(repo));

      expect(
        [for (final b in bubblesOfSize(tester, bubbleSm)) b.mood]..sort(),
        [1, 2],
      );
    });

    homeTest('CA14 : la plage suit l\'ajout d\'une entrée', (tester) async {
      final repo = weekJournal({1: 4});
      await showHome(tester, HomeEnv(repo));
      expect(dayEmpty(2), findsOneWidget);

      await tester.runAsync(() => repo.addEntry(mood: 2));
      await settle(tester);

      expect(dayEmpty(2), findsNothing);
      expect(smallBubbles, findsNWidgets(2));
    });

    homeTest('CA14 : la semaine suit l\'horloge : le lundi suivant, tous les '
        'jours sont vides', (tester) async {
      final env = HomeEnv(
        weekJournal({1: 4, 2: 3}),
        now: DateTime(2026, 10, 19, 9),
      );
      await showHome(tester, env);

      for (var i = 0; i < 7; i++) {
        expect(dayEmpty(i), findsOneWidget, reason: 'jour $i');
      }
    });
  });

  group('lecteur d\'écran (CA15)', () {
    homeTest('CA15 : un seul bouton « Ta plage cette semaine : lundi Bien, '
        'mardi pas d\'entrée, …, dimanche pas d\'entrée. Ouvre le bilan de la '
        'semaine. »', (tester) async {
      await showHome(tester, HomeEnv(weekJournal({1: 4})));

      final label = beachLabel([4, null, null, null, null, null, null]);
      expect(
        label,
        "Ta plage cette semaine : lundi Bien, mardi pas d'entrée, mercredi pas "
        "d'entrée, jeudi pas d'entrée, vendredi pas d'entrée, samedi pas "
        "d'entrée, dimanche pas d'entrée. Ouvre le bilan de la semaine.",
      );
      final node = find.bySemanticsLabel(label);
      expect(node, findsOneWidget);
      expect(isButtonNode(tester, node), isTrue);
      expect(beachCard, findsOneWidget);
    });

    homeTest('CA15 : chaque jour dit le libellé de son humeur (RM3)', (
      tester,
    ) async {
      await showHome(
        tester,
        HomeEnv(weekJournal({1: 1, 2: 2, 3: 3, 4: 4, 5: 5, 6: 4, 7: 3})),
      );

      expect(
        find.bySemanticsLabel(beachLabel([1, 2, 3, 4, 5, 4, 3])),
        findsOneWidget,
      );
    });

    homeTest('CA15 : les jours notés et sans entrée s\'alternent', (
      tester,
    ) async {
      await showHome(tester, HomeEnv(weekJournal({2: 5, 3: 1, 6: 3})));

      expect(
        find.bySemanticsLabel(beachLabel([null, 5, 1, null, null, 3, null])),
        findsOneWidget,
      );
    });

    homeTest('CA15 : plusieurs entrées le même jour, le libellé de la '
        'dernière', (tester) async {
      final repo = FakeEntryRepository(clock: () => eveningNow)
        ..seed(mood: 1, createdAt: octoberDay(3, 7))
        ..seed(mood: 4, createdAt: octoberDay(3, 19));
      await showHome(tester, HomeEnv(repo));

      expect(
        find.bySemanticsLabel(
          beachLabel([null, null, 4, null, null, null, null]),
        ),
        findsOneWidget,
      );
    });

    homeTest('CA15 : les bulles et les cercles ne sont pas annoncés à part', (
      tester,
    ) async {
      await showHome(tester, HomeEnv(weekJournal({1: 4, 3: 2})));

      final labels = semanticLabels(tester);
      expect(labels.where((l) => l.startsWith('Ta plage')), hasLength(1));
      expect(labels.where((l) => l.contains('pas d\'entrée')), hasLength(1));
    });
  });

  group('ouvrir le bilan (CA16)', () {
    homeTest('CA16 : toucher la plage ouvre l\'onglet « Semaine » sur la '
        'semaine en cours', (tester) async {
      await showHome(tester, HomeEnv(weekJournal({1: 4, 2: 3, 3: 2, 4: 5})));
      expect(isSelectedTab(tester, 'Journal'), isTrue);

      await tester.tap(beachCard);
      await settle(tester);

      expect(isSelectedTab(tester, 'Semaine'), isTrue);
      expect(isSelectedTab(tester, 'Journal'), isFalse);
      expect(find.text('Ta semaine'), findsOneWidget);
      expect(find.text('12 – 18 octobre'), findsOneWidget);
      expect(find.text('Semaine en cours'), findsOneWidget);
      expect(find.text(checkInEvening), findsNothing);
    });

    homeTest('CA16 : même avec moins de 3 entrées, le bilan s\'ouvre (il dit '
        'qu\'il manque des entrées)', (tester) async {
      await showHome(tester, HomeEnv(weekJournal({1: 4})));

      await tester.tap(beachCard);
      await settle(tester);

      expect(find.byType(WeeklyReviewScreen), findsOneWidget);
      expect(
        find.text('Pas encore de bilan pour cette semaine'),
        findsOneWidget,
      );
    });

    homeTest('CA16 : une seule entrée, d\'une autre semaine : la plage est là '
        'et le bilan s\'ouvre sur la semaine en cours, sans entrée', (
      tester,
    ) async {
      final repo = FakeEntryRepository(clock: () => eveningNow)
        ..seed(mood: 3, createdAt: DateTime(2026, 9, 20, 12));
      await showHome(tester, HomeEnv(repo));

      await tester.tap(beachCard);
      await settle(tester);

      expect(find.text('12 – 18 octobre'), findsOneWidget);
      expect(
        find.text('Pas encore de bilan pour cette semaine'),
        findsOneWidget,
      );
    });

    homeTest('CA16 : l\'écran de liste seul appelle onOpenWeek, sans rien '
        'ouvrir lui-même', (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        testApp(
          EntryListScreen(
            repository: weekJournal({1: 4}),
            settings: FakeSettingsRepository(),
            downloader: FakeModelDownloader(readyModel),
            clock: () => eveningNow,
            onOpenWeek: () => calls++,
          ),
        ),
      );
      await settle(tester);

      await tester.tap(beachCard);
      await settle(tester);

      expect(calls, 1);
      expect(find.byType(WeeklyReviewScreen), findsNothing);
    });

    homeTest('CA16 : l\'écran de liste seul, sans onOpenWeek, ouvre le bilan '
        'par-dessus', (tester) async {
      await tester.pumpWidget(
        testApp(
          EntryListScreen(
            repository: weekJournal({1: 4}),
            settings: FakeSettingsRepository(),
            downloader: FakeModelDownloader(readyModel),
            clock: () => eveningNow,
          ),
        ),
      );
      await settle(tester);

      await tester.tap(beachCard);
      await settle(tester);

      expect(find.byType(WeeklyReviewScreen), findsOneWidget);
      expect(find.text('Ta semaine'), findsOneWidget);
      expect(find.text('Journal'), findsOneWidget, reason: 'retour du bilan');
    });
  });

  group('états sans plage (CA17)', () {
    homeTest('CA17 : journal vide, ni plage ni compteur', (tester) async {
      await showHome(tester, HomeEnv(FakeEntryRepository()));

      expect(find.text(beachTitle), findsNothing);
      expect(beachCard, findsNothing);
      expect(smallBubbles, findsNothing);
      expect(find.byKey(const Key('day-empty-0')), findsNothing);
      expect(find.textContaining('coquillage'), findsNothing);
    });

    homeTest('CA17 : pendant la lecture, ni plage ni compteur', (tester) async {
      final repo = weekJournal({1: 4})..neverEmit = true;
      await showHome(tester, HomeEnv(repo));

      expect(find.text(beachTitle), findsNothing);
      expect(beachCard, findsNothing);
      expect(find.textContaining('coquillage'), findsNothing);
    });

    homeTest('CA17 : en cas d\'erreur, ni plage ni compteur', (tester) async {
      final repo = weekJournal({1: 4})..watchError = StateError('illisible');
      await showHome(tester, HomeEnv(repo));

      expect(find.text(beachTitle), findsNothing);
      expect(beachCard, findsNothing);
      expect(find.textContaining('coquillage'), findsNothing);
    });

    homeTest('CA17 : la plage apparaît dès la première entrée', (tester) async {
      final repo = FakeEntryRepository(clock: () => eveningNow);
      await showHome(tester, HomeEnv(repo));
      expect(find.text(beachTitle), findsNothing);

      await tester.runAsync(() => repo.addEntry(mood: 3));
      await settle(tester);

      expect(find.text(beachTitle), findsOneWidget);
      expect(find.text('1 coquillage cette semaine'), findsOneWidget);
    });
  });

  group('liste sous la plage (CA18)', () {
    homeTest('CA18 : ordre de l\'accueil : en-tête, check-in, plage, puis les '
        'jours regroupés (spec 001, CA2, CA3, CA6)', (tester) async {
      final repo = FakeEntryRepository(clock: () => eveningNow)
        ..seed(mood: 2, createdAt: DateTime(2026, 10, 13, 22, 5))
        ..seed(mood: 5, createdAt: DateTime(2026, 10, 12, 19, 30))
        ..seed(mood: 3, createdAt: DateTime(2026, 10, 14, 8, 15))
        ..seed(mood: 4, createdAt: DateTime(2026, 10, 14, 21, 40));
      await showHome(tester, HomeEnv(repo));

      final tops = [
        tester.getTopLeft(find.text('Ton journal')).dy,
        tester.getTopLeft(find.text(checkInEvening)).dy,
        tester.getTopLeft(find.text(beachTitle)).dy,
        tester.getTopLeft(find.text("Aujourd'hui")).dy,
        tester.getTopLeft(find.text('Hier')).dy,
        tester.getTopLeft(find.text('Lundi 12 octobre')).dy,
      ];
      expect(tops, [...tops]..sort());
      expect(tops.toSet(), hasLength(tops.length));
    });

    homeTest('CA18 : l\'état vide garde son texte et le logo, sous le '
        'check-in', (tester) async {
      await showHome(tester, HomeEnv(FakeEntryRepository()));

      expect(find.text(emptyJournalTitle), findsOneWidget);
      expect(
        find.text(
          'Note ton humeur en quelques secondes. Tout reste sur ton téléphone.',
        ),
        findsOneWidget,
      );
      final logo = find.byType(TidemarkLogo);
      expect(logo, findsWidgets);
      final checkIn = tester.getBottomLeft(find.text(checkInEvening)).dy;
      expect(
        tester.getTopLeft(find.text(emptyJournalTitle)).dy,
        greaterThan(checkIn),
      );
      expect(
        tester.getTopLeft(find.byType(TidemarkLogo).last).dy,
        greaterThan(checkIn),
      );
    });
  });

  group('texte à 200 % et thème sombre (CA27, CA28)', () {
    homeTest('CA27 : à 200 %, la plage ne déborde pas, rien n\'y est tronqué '
        'et les sept jours restent dans l\'écran', (tester) async {
      await showHome(
        tester,
        HomeEnv(weekJournal({1: 4, 2: 3, 5: 5})),
        textScale: 2.0,
      );

      expect(tester.takeException(), isNull);
      expectNoTruncatedText(
        tester,
        find.byType(Scaffold).first,
        'accueil 200 %',
      );
      final title = tester.getRect(find.text(beachTitle));
      expect(title.left, greaterThanOrEqualTo(0));
      expect(title.right, lessThanOrEqualTo(393));
      expect(initialsOnScreen(tester), dayInitials);
    }, tall: false);

    homeTest('CA28 : thème sombre, la plage prend les valeurs sombres de '
        'sea et de sand', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final key = GlobalKey();
      await showHome(tester, HomeEnv(weekJournal({1: 4})), boundary: key);

      final pixels = await capture(tester, key);
      expect(countColor(pixels, dark.sea), greaterThan(1000));
      expect(countColor(pixels, dark.sand), greaterThan(500));
      expect(countColor(pixels, light.sea), 0);
      expect(countColor(pixels, light.sand), 0);
    });

    homeTest('CA28 : thème clair, la plage prend la valeur claire de sand', (
      tester,
    ) async {
      final key = GlobalKey();
      await showHome(tester, HomeEnv(weekJournal({1: 4})), boundary: key);

      final pixels = await capture(tester, key);
      expect(countColor(pixels, light.sand), greaterThan(500));
      expect(countColor(pixels, dark.sand), 0);
    });
  });
}
