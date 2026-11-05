// Sujets dans le détail et la liste (spec 010, CA7, CA8, CA20) : la section « Ce qui
// a compté » du détail, absente sans sujet, avant « Étiquettes » ; la liste ne montre
// pas les sujets. Un parcours complet sur la vraie base en mémoire.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/analysis/mood_analyzer.dart';
import 'package:tidemark/entries/entry.dart';
import 'package:tidemark/entries/topic.dart';
import 'package:tidemark/ui/screens/entry_detail_screen.dart';
import 'package:tidemark/ui/theme/tidemark_colors.dart';

import '../support/celebration_harness.dart';
import '../support/fake_entry_repository.dart';
import '../support/home_harness.dart';
import '../support/playful_harness.dart';
import '../support/ui_harness.dart';

const light = TidemarkColors.light;
const dark = TidemarkColors.dark;

const tagsTitle = 'Étiquettes';
const diaryText = 'Longue journée, mais la balade du soir m\'a fait du bien.';

/// Une entrée dans [repo], avec [topics] et, si [tags] est donné, ces étiquettes
/// (l'entrée est alors « étiquetée »).
Future<Entry> seedEntry(
  FakeEntryRepository repo, {
  int mood = 4,
  String? text = diaryText,
  List<Topic> topics = const [],
  List<Tag>? tags,
}) async {
  final seeded = repo.seed(
    mood: mood,
    text: text,
    createdAt: DateTime(2026, 10, 14, 21, 40),
    topics: topics,
  );
  if (tags != null) await repo.saveAnalysis(seeded.id, Tagged(tags));
  return repo.entries.firstWhere((e) => e.id == seeded.id);
}

Future<void> showDetail(
  WidgetTester tester,
  FakeEntryRepository repo,
  Entry entry, {
  double textScale = 1.0,
}) async {
  await tester.pumpWidget(
    testApp(
      EntryDetailScreen(entry: entry, repository: repo),
      textScale: textScale,
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
}

void useTall(WidgetTester tester, {double height = 2400}) {
  tester.view.physicalSize = Size(393, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// `testWidgets` avec la sémantique activée et un écran haut.
void detailTest(
  String description,
  Future<void> Function(WidgetTester tester, FakeEntryRepository repo) body, {
  double height = 2400,
}) {
  testWidgets(description, (tester) async {
    useTall(tester, height: height);
    final semantics = tester.ensureSemantics();
    try {
      await body(tester, FakeEntryRepository());
    } finally {
      semantics.dispose();
    }
  });
}

final tagged = [
  const Tag('fatigue', TagKind.emotion),
  const Tag('calme', TagKind.emotion),
  const Tag('maison', TagKind.theme),
];

void main() {
  group('détail : section « Ce qui a compté » (CA7)', () {
    detailTest('CA7 : une entrée avec des sujets montre la section et ses '
        'autocollants', (tester, repo) async {
      final entry = await seedEntry(
        repo,
        topics: [Topic.friends, Topic.nature],
      );

      await showDetail(tester, repo, entry);

      expect(find.text(topicsTitle), findsOneWidget);
      expect(find.text('amis'), findsOneWidget);
      expect(find.text('nature'), findsOneWidget);
      expect(find.text('sport'), findsNothing);
    });

    detailTest('CA7 : les autocollants des sujets ont le fond `ink` et le '
        'texte `surface`', (tester, repo) async {
      final entry = await seedEntry(repo, topics: [Topic.family]);

      await showDetail(tester, repo, entry);

      expect(backgroundBehind(tester, find.text('famille')), light.ink);
      expect(paintedTextColor(tester, find.text('famille')), light.surface);
    });

    detailTest('CA7 : en sombre, les valeurs sombres de `ink` et `surface` '
        's\'appliquent', (tester, repo) async {
      useDarkPlatform(tester);
      final entry = await seedEntry(repo, topics: [Topic.family]);

      await showDetail(tester, repo, entry);

      expect(backgroundBehind(tester, find.text('famille')), dark.ink);
      expect(paintedTextColor(tester, find.text('famille')), dark.surface);
    });

    detailTest('CA7 : le titre de la section est un en-tête sémantique', (
      tester,
      repo,
    ) async {
      final entry = await seedEntry(repo, topics: [Topic.sport]);

      await showDetail(tester, repo, entry);

      expect(
        tester.getSemantics(find.text(topicsTitle)).flagsCollection.isHeader,
        isTrue,
      );
    });

    detailTest('CA7 : les six sujets s\'affichent dans l\'ordre de la liste', (
      tester,
      repo,
    ) async {
      final entry = await seedEntry(repo, topics: Topic.values);

      await showDetail(tester, repo, entry);

      final positions = [
        for (final topic in Topic.values)
          tester.getTopLeft(find.text(topic.label)),
      ];
      for (var i = 1; i < positions.length; i++) {
        expect(
          readsAfter(positions[i - 1], positions[i]),
          isTrue,
          reason: Topic.values[i].name,
        );
      }
    });

    detailTest('CA7 : la section vient avant « Étiquettes »', (
      tester,
      repo,
    ) async {
      final entry = await seedEntry(
        repo,
        topics: [Topic.work, Topic.sport],
        tags: tagged,
      );

      await showDetail(tester, repo, entry);

      expect(find.text(tagsTitle), findsOneWidget);
      final topicsTop = tester.getTopLeft(find.text(topicsTitle)).dy;
      final tagsTop = tester.getTopLeft(find.text(tagsTitle)).dy;
      expect(topicsTop, lessThan(tagsTop));
      expect(tester.getTopLeft(find.text('sport')).dy, lessThan(tagsTop));
      expect(tester.getTopLeft(find.text('maison')).dy, greaterThan(tagsTop));
    });

    detailTest('CA7 : sans sujet, la section n\'apparaît pas, « Étiquettes » '
        'reste', (tester, repo) async {
      final entry = await seedEntry(repo, tags: tagged);

      await showDetail(tester, repo, entry);

      expect(find.text(topicsTitle), findsNothing);
      expect(find.text(tagsTitle), findsOneWidget);
    });

    detailTest('CA7 : sans sujet ni texte, la section n\'apparaît pas', (
      tester,
      repo,
    ) async {
      final entry = await seedEntry(repo, text: null);

      await showDetail(tester, repo, entry);

      expect(find.text(topicsTitle), findsNothing);
    });

    detailTest('CA7 : une entrée sans texte mais avec des sujets montre la '
        'section, sans « Étiquettes »', (tester, repo) async {
      final entry = await seedEntry(repo, text: null, topics: [Topic.sleep]);

      await showDetail(tester, repo, entry);

      expect(find.text(topicsTitle), findsOneWidget);
      expect(find.text('sommeil'), findsOneWidget);
      expect(find.text(tagsTitle), findsNothing);
    });

    detailTest('CA7, cas limite : un même libellé comme sujet et comme '
        'étiquette reste dans deux sections distinctes', (tester, repo) async {
      final entry = await seedEntry(
        repo,
        topics: [Topic.work],
        tags: const [
          Tag('fatigue', TagKind.emotion),
          Tag('travail', TagKind.theme),
        ],
      );

      await showDetail(tester, repo, entry);

      expect(find.text('travail'), findsNWidgets(2));
      final tagsTop = tester.getTopLeft(find.text(tagsTitle)).dy;
      expect(
        tester.getTopLeft(find.text('travail').first).dy,
        lessThan(tagsTop),
        reason: 'le sujet est dans « Ce qui a compté »',
      );
      expect(
        tester.getTopLeft(find.text('travail').last).dy,
        greaterThan(tagsTop),
        reason: 'l\'étiquette est dans « Étiquettes »',
      );
      expect(backgroundBehind(tester, find.text('travail').first), light.ink);
      expect(
        backgroundBehind(tester, find.text('travail').last),
        isNot(light.ink),
        reason: 'la puce d\'étiquette n\'a pas le fond d\'un sujet',
      );
    });

    detailTest('CA7 : le reste du détail est inchangé : texte, humeur, date', (
      tester,
      repo,
    ) async {
      final entry = await seedEntry(repo, topics: [Topic.friends]);

      await showDetail(tester, repo, entry);

      expect(find.textContaining('Longue journée'), findsOneWidget);
      expect(find.text('Bien'), findsOneWidget);
      expect(find.textContaining('Mercredi 14 octobre'), findsOneWidget);
      expect(find.text('Supprimer cette entrée'), findsOneWidget);
    });
  });

  group('texte à 200 % et thème sombre (CA20)', () {
    detailTest('CA20 : le détail avec six sujets à 200 % en sombre : rien '
        'n\'est tronqué ni ne déborde', (tester, repo) async {
      useDarkPlatform(tester);
      final entry = await seedEntry(repo, topics: Topic.values, tags: tagged);

      await showDetail(tester, repo, entry, textScale: 2.0);

      expect(tester.takeException(), isNull);
      for (final topic in Topic.values) {
        expect(find.text(topic.label), findsOneWidget);
        final rect = tester.getRect(find.text(topic.label));
        expect(rect.left, greaterThanOrEqualTo(0), reason: topic.name);
        expect(rect.right, lessThanOrEqualTo(393), reason: topic.name);
      }
      expect(backgroundBehind(tester, find.text('amis')), dark.ink);
      expect(paintedTextColor(tester, find.text('amis')), dark.surface);
      expectNothingTruncated(tester, find.byType(Scaffold), 'détail à 200 %');
    }, height: 4800);
  });

  group('liste : les sujets n\'y paraissent pas (CA8)', () {
    homeTest('CA8 : la carte ne montre aucun sujet', (tester) async {
      final repo = FakeEntryRepository(clock: () => eveningNow);
      repo.seed(
        mood: 4,
        text: 'Journée calme.',
        createdAt: octoberDay(3),
        topics: [Topic.sport, Topic.family, Topic.sleep],
      );
      await showHome(tester, HomeEnv(repo));

      expect(find.textContaining('Journée calme.'), findsOneWidget);
      expect(find.text(topicsTitle), findsNothing);
      for (final topic in Topic.values) {
        expect(find.text(topic.label), findsNothing, reason: topic.name);
      }
    });

    homeTest('CA8 : la carte et son annonce sont les mêmes avec ou sans '
        'sujets', (tester) async {
      Future<List<String>> labelsWith(List<Topic> topics) async {
        final repo = FakeEntryRepository(clock: () => eveningNow);
        repo.seed(
          mood: 4,
          text: 'Journée calme.',
          createdAt: octoberDay(3),
          topics: topics,
        );
        await showHome(tester, HomeEnv(repo));
        final labels = semanticLabels(tester);
        await tester.pumpWidget(const SizedBox());
        return labels;
      }

      final without = await labelsWith(const []);
      final withTopics = await labelsWith([Topic.sport, Topic.family]);

      expect(withTopics, without);
      expect(withTopics.where((l) => l.contains('Journée calme.')), isNotEmpty);
    });
  });

  group('parcours complet sur la vraie base (CA4, CA7, CA8, CA16)', () {
    dbTestWidgets('CA4, CA7 : des sujets choisis à la saisie sont enregistrés, '
        'relus par la liste puis affichés dans le détail', (tester, env) async {
      await tester.pumpWidget(env.app());
      await settle(tester);
      await openForm(tester);
      await pickMood(tester, 4);
      await tester.enterText(textInput, 'Balade au bord de l\'eau.');
      await tester.pump();
      await tester.ensureVisible(find.text('nature'));
      await tapTopic(tester, Topic.nature);
      await tester.ensureVisible(find.text('amis'));
      await tapTopic(tester, Topic.friends);
      await tester.ensureVisible(find.text('Enregistrer'));

      await tester.tap(find.text('Enregistrer'));
      await settle(tester);
      await continueFromCelebration(tester);

      final saved = await env.entries(tester);
      expect(saved.single.topics, [Topic.friends, Topic.nature]);
      // CA8 : la carte de la liste ne les montre pas.
      expect(find.textContaining('Balade au bord de l'), findsOneWidget);
      expect(find.text(topicsTitle), findsNothing);
      expect(find.text('amis'), findsNothing);
      expect(find.text('nature'), findsNothing);

      await tester.tap(find.textContaining('Balade au bord de l'));
      await settle(tester);

      expect(find.text(topicsTitle), findsOneWidget);
      expect(find.text('amis'), findsOneWidget);
      expect(find.text('nature'), findsOneWidget);
    });

    dbTestWidgets('CA10 : supprimer l\'entrée depuis son détail efface aussi '
        'ses sujets', (tester, env) async {
      final entry = (await tester.runAsync(
        () => env.repo.addEntry(
          mood: 4,
          text: 'À supprimer.',
          topics: [Topic.sport],
        ),
      ))!;
      await tester.pumpWidget(env.app());
      await settle(tester);
      await tester.tap(find.textContaining('À supprimer.'));
      await settle(tester);
      expect(find.text('sport'), findsOneWidget);

      await tester.tap(find.text('Supprimer cette entrée'));
      await settle(tester);
      await tester.tap(find.text('Supprimer'));
      await settle(tester);

      final left = await tester.runAsync(
        () => env.db
            .customSelect(
              'SELECT count(*) AS n FROM entry_topics '
              'WHERE entry_id = ${entry.id}',
            )
            .getSingle(),
      );
      expect(left!.read<int>('n'), 0);
      expect(await env.entries(tester), isEmpty);
    });
  });
}
