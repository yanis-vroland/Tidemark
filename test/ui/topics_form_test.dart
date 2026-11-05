// Section « Ce qui a compté » de la saisie (spec 010, CA1 à CA5, CA15, CA20) : six
// sujets en autocollants à bascule, enregistrés avec l'entrée. Dépôt factice.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/entries/entry.dart';
import 'package:tidemark/entries/topic.dart';
import 'package:tidemark/ui/screens/entry_form_screen.dart';
import 'package:tidemark/ui/theme/tidemark_colors.dart';

import '../support/celebration_harness.dart';
import '../support/fake_entry_repository.dart';
import '../support/fake_model_downloader.dart';
import '../support/fake_settings_repository.dart';
import '../support/home_harness.dart';
import '../support/playful_harness.dart';
import '../support/ui_harness.dart';

const light = TidemarkColors.light;
const dark = TidemarkColors.dark;

/// Écran haut : toute la saisie est visible sans défiler, la position des
/// autocollants se lit directement.
void useTallPhone(WidgetTester tester, {double height = 2400}) {
  tester.view.physicalSize = Size(393, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Widget form(
  FakeEntryRepository repo, {
  double textScale = 1.0,
  int? initialMood,
}) => testApp(
  EntryFormScreen(
    repository: repo,
    settings: FakeSettingsRepository(),
    downloader: FakeModelDownloader(readyModel),
    initialMood: initialMood,
  ),
  textScale: textScale,
);

Future<FakeEntryRepository> showForm(
  WidgetTester tester, {
  FakeEntryRepository? repo,
  double textScale = 1.0,
  int? initialMood,
}) async {
  final used = repo ?? FakeEntryRepository();
  await tester.pumpWidget(
    form(used, textScale: textScale, initialMood: initialMood),
  );
  await settle(tester);
  return used;
}

/// Le texte du sujet [topic] est-il peint en [color] ?
Color? textColorOf(WidgetTester tester, Topic topic) =>
    paintedTextColor(tester, find.text(topic.label));

Color? backgroundOf(WidgetTester tester, Topic topic) =>
    backgroundBehind(tester, find.text(topic.label));

/// `testWidgets` avec la sémantique activée et un écran haut.
void formTest(
  String description,
  Future<void> Function(WidgetTester tester) body,
) {
  testWidgets(description, (tester) async {
    useTallPhone(tester);
    final semantics = tester.ensureSemantics();
    try {
      await body(tester);
    } finally {
      semantics.dispose();
    }
  });
}

void main() {
  group('la section (CA1, CA3)', () {
    formTest('CA1 : une section « Ce qui a compté » montre les six sujets '
        'dès l\'ouverture, sans humeur choisie', (tester) async {
      await showForm(tester);

      expect(find.text(topicsTitle), findsOneWidget);
      for (final topic in Topic.values) {
        expect(find.text(topic.label), findsOneWidget, reason: topic.name);
      }
    });

    formTest('CA1 : les sujets se lisent dans l\'ordre de la liste, du haut '
        'vers le bas et de gauche à droite', (tester) async {
      await showForm(tester);

      final positions = [
        for (final topic in Topic.values)
          tester.getTopLeft(find.text(topic.label)),
      ];
      for (var i = 1; i < positions.length; i++) {
        expect(
          readsAfter(positions[i - 1], positions[i]),
          isTrue,
          reason: '${Topic.values[i].name} après ${Topic.values[i - 1].name}',
        );
      }
    });

    formTest('CA1 : les sujets sont sous le titre de leur section', (
      tester,
    ) async {
      await showForm(tester);

      final title = tester.getTopLeft(find.text(topicsTitle)).dy;
      for (final topic in Topic.values) {
        expect(
          tester.getTopLeft(find.text(topic.label)).dy,
          greaterThan(title),
          reason: topic.name,
        );
      }
    });

    formTest('CA1 : aucun sujet n\'est choisi au départ', (tester) async {
      await showForm(tester);

      for (final topic in Topic.values) {
        expect(isTopicOn(tester, topic), isFalse, reason: topic.name);
        expect(
          backgroundOf(tester, topic),
          isNot(light.ink),
          reason: '${topic.name} n\'a pas le fond d\'un sujet choisi',
        );
      }
    });

    formTest('CA3 : le titre de la section est un en-tête sémantique', (
      tester,
    ) async {
      await showForm(tester);

      expect(
        tester.getSemantics(find.text(topicsTitle)).flagsCollection.isHeader,
        isTrue,
      );
    });

    formTest('CA3 : chaque sujet s\'annonce comme un bouton avec son libellé', (
      tester,
    ) async {
      await showForm(tester);

      for (final topic in Topic.values) {
        expect(
          topicButton(topic),
          findsOneWidget,
          reason: 'un nœud « ${topic.label} »',
        );
        expect(
          isButtonNode(tester, topicButton(topic)),
          isTrue,
          reason: topic.name,
        );
      }
    });

    formTest('CA3 : l\'état (choisi ou non) est annoncé par la sémantique, le '
        'libellé reste celui du sujet', (tester) async {
      await showForm(tester);
      expect(isTopicOn(tester, Topic.sport), isFalse);

      await tapTopic(tester, Topic.sport);

      expect(isTopicOn(tester, Topic.sport), isTrue);
      expect(isTopicOn(tester, Topic.amis), isFalse);
      expect(topicButton(Topic.sport), findsOneWidget);

      await tapTopic(tester, Topic.sport);

      expect(isTopicOn(tester, Topic.sport), isFalse);
    });
  });

  group('choisir et retirer un sujet (CA2)', () {
    formTest('CA2 : toucher un sujet le choisit : fond `ink`, texte '
        '`surface`', (tester) async {
      await showForm(tester);

      await tapTopic(tester, Topic.amis);

      expect(backgroundOf(tester, Topic.amis), light.ink);
      expect(textColorOf(tester, Topic.amis), light.surface);
      expect(isTopicOn(tester, Topic.amis), isTrue);
    });

    formTest('CA2 : le toucher de nouveau le retire : il retrouve son '
        'apparence de départ', (tester) async {
      await showForm(tester);
      final before = (
        backgroundOf(tester, Topic.amis),
        textColorOf(tester, Topic.amis),
      );

      await tapTopic(tester, Topic.amis);
      await tapTopic(tester, Topic.amis);

      expect(isTopicOn(tester, Topic.amis), isFalse);
      expect((
        backgroundOf(tester, Topic.amis),
        textColorOf(tester, Topic.amis),
      ), before);
    });

    formTest('CA2 : choisir un sujet n\'en change aucun autre', (tester) async {
      await showForm(tester);

      await tapTopic(tester, Topic.travail);
      await tapTopic(tester, Topic.nature);

      expect(
        [for (final t in Topic.values) isTopicOn(tester, t)],
        [false, true, false, false, false, true],
      );
    });

    formTest('CA2 : de 0 à 6 sujets : les six peuvent être choisis ensemble', (
      tester,
    ) async {
      await showForm(tester);

      for (final topic in Topic.values) {
        await tapTopic(tester, topic);
      }

      for (final topic in Topic.values) {
        expect(isTopicOn(tester, topic), isTrue, reason: topic.name);
        expect(backgroundOf(tester, topic), light.ink);
      }
    });

    formTest('CA2 : toucher le bouton trouvé par son libellé sémantique le '
        'choisit aussi', (tester) async {
      await showForm(tester);

      await tester.tap(topicButton(Topic.famille));
      await tester.pump();

      expect(isTopicOn(tester, Topic.famille), isTrue);
    });

    formTest('CA2 : aucun sujet n\'est obligatoire : avec une humeur seule, '
        '« Enregistrer » est actif', (tester) async {
      await showForm(tester, initialMood: 4);

      expect(isEnabled(tester, 'Enregistrer'), isTrue);
    });

    formTest('CA2 : des sujets sans humeur ne suffisent pas : « Enregistrer » '
        'reste désactivé (spec 001, CA7)', (tester) async {
      await showForm(tester);

      await tapTopic(tester, Topic.sport);

      expect(isEnabled(tester, 'Enregistrer'), isFalse);
    });

    formTest('CA2 : choisir des sujets ne change pas l\'humeur choisie', (
      tester,
    ) async {
      await showForm(tester);
      await pickMood(tester, 2);

      await tapTopic(tester, Topic.sommeil);

      expect(isChosen(tester, 2), isTrue);
      expect(isChosen(tester, 4), isFalse);
    });
  });

  group('enregistrer avec des sujets (CA4)', () {
    formTest('CA4 : humeur et sujets, sans texte : l\'entrée est enregistrée '
        'avec ses sujets, « non analysée » (RM24)', (tester) async {
      final repo = await showForm(tester);
      await pickMood(tester, 4);
      await tapTopic(tester, Topic.nature);
      await tapTopic(tester, Topic.amis);

      await tester.tap(find.text('Enregistrer'));
      await settle(tester);

      expect(repo.addCalls, hasLength(1));
      expect(repo.addCalls.single.mood, 4);
      expect(
        repo.addCalls.single.topics,
        unorderedEquals([Topic.nature, Topic.amis]),
      );
      final saved = repo.entries.single;
      expect(saved.topics, [Topic.amis, Topic.nature]);
      expect(saved.text, isNull);
      expect(saved.analysisStatus, AnalysisStatus.skipped);
    });

    formTest('CA4 : humeur, texte et sujets : enregistrés ensemble, statut '
        '« en attente »', (tester) async {
      final repo = await showForm(tester);
      await pickMood(tester, 5);
      await tester.enterText(textInput, 'Belle journée au soleil.');
      await tapTopic(tester, Topic.sport);

      await tester.tap(find.text('Enregistrer'));
      await settle(tester);

      final saved = repo.entries.single;
      expect(saved.text, 'Belle journée au soleil.');
      expect(saved.topics, [Topic.sport]);
      expect(saved.analysisStatus, AnalysisStatus.pending);
    });

    formTest('CA4 : les sujets sont rangés dans l\'ordre de la liste, quel '
        'que soit l\'ordre des touchers', (tester) async {
      final repo = await showForm(tester, initialMood: 3);
      for (final topic in Topic.values.reversed) {
        await tapTopic(tester, topic);
      }

      await tester.tap(find.text('Enregistrer'));
      await settle(tester);

      expect(repo.entries.single.topics, Topic.values);
    });

    formTest('CA4 : un sujet choisi puis retiré n\'est pas enregistré', (
      tester,
    ) async {
      final repo = await showForm(tester, initialMood: 3);
      await tapTopic(tester, Topic.travail);
      await tapTopic(tester, Topic.sport);
      await tapTopic(tester, Topic.travail);

      await tester.tap(find.text('Enregistrer'));
      await settle(tester);

      expect(repo.entries.single.topics, [Topic.sport]);
    });

    formTest('CA4 : sans sujet choisi, l\'entrée n\'en a aucun', (
      tester,
    ) async {
      final repo = await showForm(tester, initialMood: 3);

      await tester.tap(find.text('Enregistrer'));
      await settle(tester);

      expect(repo.addCalls.single.topics, isEmpty);
      expect(repo.entries.single.topics, isEmpty);
    });

    formTest('CA4 : un texte en détresse enregistre quand même les sujets, '
        'l\'entrée est « non analysée »', (tester) async {
      final repo = await showForm(tester, initialMood: 3);
      await tester.enterText(textInput, 'envie de mourir');
      await tapTopic(tester, Topic.famille);

      await tester.tap(find.text('Enregistrer'));
      await settle(tester);

      final saved = repo.entries.single;
      expect(saved.topics, [Topic.famille]);
      expect(saved.analysisStatus, AnalysisStatus.skipped);
    });

    formTest('CA15 : une erreur à l\'enregistrement garde les sujets choisis, '
        'et « Réessayer » les enregistre', (tester) async {
      final repo = FakeEntryRepository(
        beforeAdd: () async => throw StateError('stockage plein'),
      );
      await showForm(tester, repo: repo, initialMood: 4);
      await tapTopic(tester, Topic.amis);
      await tapTopic(tester, Topic.nature);

      await tester.tap(find.text('Enregistrer'));
      await settle(tester);

      expect(find.text("L'entrée n'a pas été enregistrée"), findsOneWidget);
      expect(isTopicOn(tester, Topic.amis), isTrue);
      expect(isTopicOn(tester, Topic.nature), isTrue);
      expect(isTopicOn(tester, Topic.sport), isFalse);

      repo.beforeAdd = null;
      await tester.tap(find.text('Réessayer'));
      await settle(tester);

      expect(repo.entries.single.topics, [Topic.amis, Topic.nature]);
    });
  });

  group('abandonner avec des sujets (CA5)', () {
    homeTest(
      'CA5 : des sujets choisis puis « Annuler » sans texte : rien n\'est '
      'enregistré, sans confirmation',
      (tester) async {
        final env = HomeEnv(weekJournal({1: 4}));
        await tester.pumpWidget(env.app());
        await settle(tester);
        await tester.tap(find.text('Nouvelle entrée'));
        await settle(tester);
        await pickMood(tester, 3);
        await tapTopic(tester, Topic.sport);
        await tapTopic(tester, Topic.amis);

        await tester.tap(find.text('Annuler'));
        await settle(tester);

        expect(find.text('Abandonner cette entrée ?'), findsNothing);
        expect(find.byType(EntryFormScreen), findsNothing);
        expect(env.repo.addCalls, isEmpty);
        expect(env.repo.entries, hasLength(1));
        expect(find.text('Ton journal'), findsOneWidget);
      },
    );

    homeTest('CA5 : un geste de retour, sujets choisis et sans texte : '
        'sortie sans confirmation, rien d\'enregistré', (tester) async {
      final env = HomeEnv(weekJournal({1: 4}));
      await tester.pumpWidget(env.app());
      await settle(tester);
      await tester.tap(find.text('Nouvelle entrée'));
      await settle(tester);
      await tapTopic(tester, Topic.nature);

      await tester.binding.handlePopRoute();
      await settle(tester);

      expect(find.text('Abandonner cette entrée ?'), findsNothing);
      expect(find.byType(EntryFormScreen), findsNothing);
      expect(env.repo.addCalls, isEmpty);
    });

    homeTest('CA5 : un texte écrit demande toujours confirmation (spec 001, '
        'CA30), sujets ou non', (tester) async {
      final env = HomeEnv(weekJournal({1: 4}));
      await tester.pumpWidget(env.app());
      await settle(tester);
      await tester.tap(find.text('Nouvelle entrée'));
      await settle(tester);
      await tapTopic(tester, Topic.nature);
      await tester.enterText(textInput, 'Un début de texte.');
      await tester.pump();

      await tester.tap(find.text('Annuler'));
      await settle(tester);

      expect(find.text('Abandonner cette entrée ?'), findsOneWidget);
      expect(env.repo.addCalls, isEmpty);
    });
  });

  group('texte à 200 % et thème sombre (CA20)', () {
    testWidgets('CA20 : à 200 %, la section et ses six sujets ne sont ni '
        'tronqués ni débordants, et restent dans l\'écran', (tester) async {
      useTallPhone(tester, height: 852);
      final semantics = tester.ensureSemantics();
      await showForm(tester, textScale: 2.0);

      expect(tester.takeException(), isNull);
      for (final topic in Topic.values) {
        await tester.ensureVisible(find.text(topic.label));
        await tester.pump();
        final rect = tester.getRect(find.text(topic.label));
        expect(rect.left, greaterThanOrEqualTo(0), reason: topic.name);
        expect(rect.right, lessThanOrEqualTo(393), reason: topic.name);
      }
      await tester.ensureVisible(find.text(topicsTitle));
      await tester.pump();
      expectNothingTruncated(tester, find.byType(Scaffold), 'saisie à 200 %');
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });

    testWidgets('CA20 : à 200 %, les sujets restent touchables : on peut les '
        'choisir', (tester) async {
      useTallPhone(tester, height: 852);
      final semantics = tester.ensureSemantics();
      await showForm(tester, textScale: 2.0, initialMood: 3);

      for (final topic in [Topic.sommeil, Topic.nature]) {
        await tester.ensureVisible(find.text(topic.label));
        await tester.pump();
        await tester.tap(find.text(topic.label));
        await tester.pump();
      }

      expect(isTopicOn(tester, Topic.sommeil), isTrue);
      expect(isTopicOn(tester, Topic.nature), isTrue);
      expect(isTopicOn(tester, Topic.sport), isFalse);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });

    formTest('CA20 : en sombre, un sujet choisi a le fond `ink` et le texte '
        '`surface` sombres', (tester) async {
      useDarkPlatform(tester);
      await showForm(tester);

      await tapTopic(tester, Topic.sport);

      expect(backgroundOf(tester, Topic.sport), dark.ink);
      expect(textColorOf(tester, Topic.sport), dark.surface);
      expect(backgroundOf(tester, Topic.amis), isNot(dark.ink));
    });

    testWidgets('CA20 : en sombre et à 200 %, rien ne déborde et les jetons '
        'sombres s\'appliquent', (tester) async {
      useDarkPlatform(tester);
      useTallPhone(tester, height: 852);
      final semantics = tester.ensureSemantics();
      await showForm(tester, textScale: 2.0);
      await tester.ensureVisible(find.text(Topic.nature.label));
      await tester.pump();

      await tester.tap(find.text(Topic.nature.label));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(backgroundOf(tester, Topic.nature), dark.ink);
      expect(textColorOf(tester, Topic.nature), dark.surface);
      semantics.dispose();
    });
  });
}
