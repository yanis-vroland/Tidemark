// Carte du check-in de l'accueil (spec 009, CA11 à CA13) : cinq bulles `bubble-check`
// avec leur libellé, annonce « Noter Bien, humeur 4 sur 5 », ouverture de la saisie
// avec l'humeur déjà choisie. Dépôt factice ; horloge : mercredi 14 octobre 2026.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/entries/entry.dart';
import 'package:tidemark/ui/screens/entry_form_screen.dart';
import 'package:tidemark/ui/widgets/mood_bubble.dart';

import '../support/celebration_harness.dart';
import '../support/fake_entry_repository.dart';
import '../support/home_harness.dart';
import '../support/playful_harness.dart';
import '../support/ui_harness.dart';

const bubbleCheck = 54.0;

Finder get checkInBubbles => bubbleFinder(bubbleCheck);

void main() {
  group('la carte (CA11)', () {
    homeTest('CA11 : le soir, « Comment va ta marée ce soir ? » et cinq bulles '
        'de 54 points, de l\'humeur 1 à 5', (tester) async {
      await showHome(tester, HomeEnv(weekJournal({1: 4})));

      expect(find.text(checkInEvening), findsOneWidget);
      expect(find.text(checkInDay), findsNothing);
      final moods = [
        for (final b in bubblesOfSize(tester, bubbleCheck)) b.mood,
      ];
      expect(moods, [1, 2, 3, 4, 5]);
    });

    homeTest('CA11 : le jour, « Comment va ta marée aujourd\'hui ? »', (
      tester,
    ) async {
      await showHome(tester, HomeEnv(weekJournal({1: 4}), now: morningNow));

      expect(find.text(checkInDay), findsOneWidget);
      expect(find.text(checkInEvening), findsNothing);
    });

    homeTest('CA11 : les bulles sont alignées de gauche à droite, avec leur '
        'libellé (RM3) dessous', (tester) async {
      await showHome(tester, HomeEnv(weekJournal({1: 4})));

      final bubbles = checkInBubbles;
      expect(bubbles, findsNWidgets(5));
      var previousX = -1.0;
      for (var mood = 1; mood <= 5; mood++) {
        final bubble = find.byWidgetPredicate(
          (w) => w is MoodBubble && w.size == bubbleCheck && w.mood == mood,
        );
        final rect = tester.getRect(bubble);
        expect(rect.size, const Size(bubbleCheck, bubbleCheck));
        expect(rect.center.dx, greaterThan(previousX));
        previousX = rect.center.dx;
        expect(
          labelBelow(tester, bubble, moodLabel(mood)),
          findsOneWidget,
          reason: 'libellé « ${moodLabel(mood)} » sous la bulle $mood',
        );
      }
    });

    homeTest('CA11 : la carte est là sur un journal vide', (tester) async {
      await showHome(tester, HomeEnv(FakeEntryRepository()));

      expect(find.text(checkInEvening), findsOneWidget);
      expect(checkInBubbles, findsNWidgets(5));
      expect(find.text(emptyJournalTitle), findsOneWidget);
    });

    homeTest('CA11 : pendant la lecture, la carte n\'apparaît pas', (
      tester,
    ) async {
      final repo = weekJournal({1: 4})..neverEmit = true;
      await showHome(tester, HomeEnv(repo));

      expect(find.textContaining('Comment va ta marée'), findsNothing);
      expect(checkInBubbles, findsNothing);
    });

    homeTest('CA11 : en cas d\'erreur de lecture, la carte n\'apparaît pas', (
      tester,
    ) async {
      final repo = weekJournal({1: 4})..watchError = StateError('illisible');
      await showHome(tester, HomeEnv(repo));

      expect(find.textContaining('Comment va ta marée'), findsNothing);
      expect(checkInBubbles, findsNothing);
      expect(find.text("Ton journal n'a pas pu être lu"), findsOneWidget);
    });

    homeTest('CA11 : la carte apparaît dès la fin de la lecture', (
      tester,
    ) async {
      final repo = weekJournal({1: 4})..watchError = StateError('illisible');
      final env = HomeEnv(repo);
      await showHome(tester, env);
      expect(checkInBubbles, findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      repo.watchError = null;
      await showHome(tester, env);

      expect(checkInBubbles, findsNWidgets(5));
    });
  });

  group('lecteur d\'écran (CA12)', () {
    homeTest('CA12 : chaque bulle s\'annonce comme un bouton « Noter Bien, '
        'humeur 4 sur 5 »', (tester) async {
      await showHome(tester, HomeEnv(weekJournal({1: 4})));

      for (var mood = 1; mood <= 5; mood++) {
        final label = checkInBubbleLabel(mood);
        final node = find.bySemanticsLabel(label);
        expect(node, findsOneWidget, reason: label);
        expect(isButtonNode(tester, node), isTrue, reason: label);
      }
      expect(checkInBubbleLabel(4), 'Noter Bien, humeur 4 sur 5');
    });

    homeTest('CA12 : la bulle elle-même n\'est pas annoncée en plus', (
      tester,
    ) async {
      await showHome(tester, HomeEnv(weekJournal({1: 4})));

      final announced = semanticLabels(tester)
          .where((l) => l.startsWith('Noter '))
          .toList();
      expect(announced, hasLength(5));
    });
  });

  group('toucher une bulle (CA13)', () {
    for (var mood = 1; mood <= 5; mood++) {
      homeTest(
        'CA13 : la bulle $mood ouvre la saisie avec « ${moodLabel(mood)} » '
        'déjà choisie et « Enregistrer » actif',
        (tester) async {
          await showHome(tester, HomeEnv(weekJournal({1: 4})));

          await tester.tap(find.bySemanticsLabel(checkInBubbleLabel(mood)));
          await settle(tester);

          expect(find.byType(EntryFormScreen), findsOneWidget);
          expect(isChosen(tester, mood), isTrue);
          // « Très bas » et « Très bien » sont aussi les repères des bouts de
          // l'échelle de la saisie : deux textes une fois l'humeur choisie.
          expect(
            find.descendant(
              of: find.byType(EntryFormScreen),
              matching: find.text(moodLabel(mood)),
            ),
            mood == 1 || mood == 5 ? findsNWidgets(2) : findsOneWidget,
          );
          expect(isEnabled(tester, 'Enregistrer'), isTrue);
          expect(
            find.text('Choisis une humeur pour enregistrer.'),
            findsNothing,
          );
        },
      );
    }

    homeTest('CA13 : le reste de la saisie est inchangé : texte vide, une '
        'autre humeur reste choisissable', (tester) async {
      await showHome(tester, HomeEnv(weekJournal({1: 4})));
      await tester.tap(find.bySemanticsLabel(checkInBubbleLabel(4)));
      await settle(tester);

      expect(inputText(tester), isEmpty);
      await pickMood(tester, 2);
      expect(isChosen(tester, 2), isTrue);
      expect(isChosen(tester, 4), isFalse);
    });

    homeTest('CA13 : enregistrer sans autre geste crée l\'entrée de l\'humeur '
        'touchée, sans texte', (tester) async {
      final repo = weekJournal({1: 4});
      await showHome(tester, HomeEnv(repo));
      await tester.tap(find.bySemanticsLabel(checkInBubbleLabel(5)));
      await settle(tester);

      await tester.tap(find.text('Enregistrer'));
      await settle(tester);
      // Spec 010, CA16 : la célébration passe avant le retour à l'accueil.
      await continueFromCelebration(tester);

      expect(repo.addCalls, hasLength(1));
      expect(repo.addCalls.single.mood, 5);
      expect(repo.addCalls.single.text, isNull);
      expect(find.byType(EntryFormScreen), findsNothing);
      expect(find.text('Ton journal'), findsOneWidget);
    });

    homeTest('CA13 : revenir sans enregistrer n\'enregistre rien et ne garde '
        'pas l\'humeur', (tester) async {
      final repo = weekJournal({1: 4});
      await showHome(tester, HomeEnv(repo));
      await tester.tap(find.bySemanticsLabel(checkInBubbleLabel(2)));
      await settle(tester);

      await tester.binding.handlePopRoute();
      await settle(tester);

      expect(repo.addCalls, isEmpty);
      await tester.tap(find.text('Nouvelle entrée'));
      await settle(tester);
      expect(isEnabled(tester, 'Enregistrer'), isFalse);
    });

    homeTest('CA13 : la bulle fonctionne aussi sur un journal vide', (
      tester,
    ) async {
      await showHome(tester, HomeEnv(FakeEntryRepository()));

      await tester.tap(find.bySemanticsLabel(checkInBubbleLabel(3)));
      await settle(tester);

      expect(isChosen(tester, 3), isTrue);
      expect(isEnabled(tester, 'Enregistrer'), isTrue);
    });
  });

  group('texte à 200 % (CA27)', () {
    homeTest('CA27 : à 200 %, la carte ne déborde pas, les bulles gardent '
        'leur taille et les libellés restent entiers', (tester) async {
      await showHome(tester, HomeEnv(weekJournal({1: 4})), textScale: 2.0);

      expect(tester.takeException(), isNull);
      for (final bubble in checkInBubbles.evaluate()) {
        final size = tester.getSize(find.byWidget(bubble.widget));
        expect(size, const Size(bubbleCheck, bubbleCheck));
      }
      for (var mood = 1; mood <= 5; mood++) {
        final rect = tester.getRect(
          find.byWidgetPredicate(
            (w) => w is MoodBubble && w.size == bubbleCheck && w.mood == mood,
          ),
        );
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(393));
      }
    }, tall: false);
  });
}
