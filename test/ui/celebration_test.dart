// Coquillage ramassé (spec 010, CA12 à CA20) : la célébration qui remplace la saisie
// après un enregistrement réussi sans détresse. L'accueil sur un dépôt factice : aucun
// réseau, aucun vrai modèle. Les animations d'ambiance ne tournent que là où le test
// les allume (`ambient: true`) : alors jamais de `pumpAndSettle`.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/entries/entry.dart';
import 'package:tidemark/entries/topic.dart';
import 'package:tidemark/model/model_state.dart';
import 'package:tidemark/ui/screens/entry_form_screen.dart';
import 'package:tidemark/ui/screens/model_download_screen.dart';
import 'package:tidemark/ui/theme/tidemark_colors.dart';

import '../support/celebration_harness.dart';
import '../support/distress_harness.dart' show backToJournal, helpTitle;
import '../support/fake_entry_repository.dart';
import '../support/fake_model_downloader.dart';
import '../support/home_harness.dart';
import '../support/model_texts.dart' show later, offerTitle;
import '../support/playful_harness.dart';
import '../support/ui_harness.dart';

const light = TidemarkColors.light;
const dark = TidemarkColors.dark;

/// Dépôt factice dont toutes les lectures échouent une fois la première entrée
/// enregistrée : la célébration ne peut plus lire les entrées de la semaine (CA17).
class FailingReadsAfterAddRepository extends FakeEntryRepository {
  FailingReadsAfterAddRepository({super.clock});

  bool failReads = false;

  @override
  Future<Entry> addEntry({
    required int mood,
    String? text,
    AnalysisStatus status = AnalysisStatus.pending,
    List<Topic> topics = const [],
  }) async {
    final entry = await super.addEntry(
      mood: mood,
      text: text,
      status: status,
      topics: topics,
    );
    failReads = true;
    return entry;
  }

  @override
  Stream<List<Entry>> watchEntries() => failReads
      ? Stream.error(StateError('lecture impossible'))
      : super.watchEntries();

  @override
  Future<List<Entry>> latestEntries(int count) async => failReads
      ? throw StateError('lecture impossible')
      : super.latestEntries(count);

  @override
  Future<List<Entry>> allEntriesWithTags() async => failReads
      ? throw StateError('lecture impossible')
      : super.allEntriesWithTags();
}

/// Affiche l'accueil de [env] dans l'application de test de la célébration.
Future<void> start(
  WidgetTester tester,
  HomeEnv env, {
  double? textScale,
  bool ambient = false,
  bool reduceMotion = false,
  bool instant = false,
  GlobalKey? boundary,
}) async {
  await tester.pumpWidget(
    celebrationApp(
      env,
      textScale: textScale,
      ambient: ambient,
      reduceMotion: reduceMotion,
      instant: instant,
      boundary: boundary,
    ),
  );
  await settle(tester);
}

/// Entrées déjà dans la semaine du 12 au 18 octobre : [count] saisies le lundi et
/// le mardi, d'humeur 3.
FakeEntryRepository weekWith(int count) {
  final repo = FakeEntryRepository(clock: () => eveningNow);
  for (var i = 0; i < count; i++) {
    repo.seed(mood: 3, createdAt: octoberDay(1 + i ~/ 4, 8 + i % 4));
  }
  return repo;
}

void expectCelebrationGone() {
  expect(find.text(celebrationTitle), findsNothing);
  expect(find.text(softCelebrationTitle), findsNothing);
  expect(find.text(continueLabel), findsNothing);
}

void expectListShown(WidgetTester tester) {
  expect(find.text('Ton journal'), findsOneWidget);
  expect(find.text('Nouvelle entrée'), findsOneWidget);
  expect(find.byType(EntryFormScreen), findsNothing);
  expectCelebrationGone();
}

void main() {
  group('célébration complète, humeur de 3 à 5 (CA12)', () {
    for (final mood in [3, 4, 5]) {
      homeTest('CA12 : humeur $mood : la célébration remplace la saisie, avec '
          'le titre, la phrase et « Continuer »', (tester) async {
        final env = HomeEnv(weekJournal({1: 4, 2: 3}));
        await start(tester, env);

        await saveAndSettle(tester, mood: mood);

        expect(find.text(celebrationTitle), findsOneWidget);
        expect(find.text(nthShellLine(3)), findsOneWidget);
        expect(find.text(continueLabel), findsOneWidget);
        expect(find.text(softCelebrationTitle), findsNothing);
        expect(find.text('Comment ça va ?'), findsNothing);
        expect(find.byType(EntryFormScreen), findsNothing);
        expect(env.repo.entries, hasLength(3));
      });
    }

    homeTest('CA12 : le fond de la célébration est `hero`, le titre en '
        '`on-hero` (clair)', (tester) async {
      await start(tester, HomeEnv(weekJournal({1: 4})));

      await saveAndSettle(tester, mood: 4);

      expect(scaffoldColor(tester, find.text(celebrationTitle)), light.hero);
      expect(
        paintedTextColor(tester, find.text(celebrationTitle)),
        light.onHero,
      );
    });

    homeTest('CA12, CA20 : même célébration en sombre, aux valeurs sombres '
        'des jetons', (tester) async {
      useDarkPlatform(tester);
      await start(tester, HomeEnv(weekJournal({1: 4})));

      await saveAndSettle(tester, mood: 4);

      expect(scaffoldColor(tester, find.text(celebrationTitle)), dark.hero);
      expect(
        paintedTextColor(tester, find.text(celebrationTitle)),
        dark.onHero,
      );
    });

    homeTest('CA12 : la première entrée de la semaine : « Ton 1er de la '
        'semaine. Il ouvre ta plage. »', (tester) async {
      await start(tester, HomeEnv(weekJournal({})));

      await saveAndSettle(tester, mood: 4);

      expect(find.text(firstShellLine), findsOneWidget);
      expect(find.textContaining('à côté des autres'), findsNothing);
    });

    homeTest('CA12 : la deuxième : « Ton 2e de la semaine. Il rejoint ta '
        'plage, à côté des autres. »', (tester) async {
      await start(tester, HomeEnv(weekJournal({1: 4})));

      await saveAndSettle(tester, mood: 4);

      expect(find.text(nthShellLine(2)), findsOneWidget);
    });

    homeTest('CA12 : N compte toutes les entrées de la semaine en cours, '
        'plusieurs le même jour comprises', (tester) async {
      await start(tester, HomeEnv(weekWith(5)));

      await saveAndSettle(tester, mood: 4);

      expect(find.text(nthShellLine(6)), findsOneWidget);
    });

    homeTest('CA12 : les entrées d\'une semaine passée ne comptent pas : la '
        'première de la semaine reste « 1er »', (tester) async {
      final repo = FakeEntryRepository(clock: () => eveningNow);
      repo.seed(mood: 5, createdAt: DateTime(2026, 10, 11, 23, 30));
      repo.seed(mood: 5, createdAt: DateTime(2026, 10, 9, 12));
      await start(tester, HomeEnv(repo));

      await saveAndSettle(tester, mood: 4);

      expect(find.text(firstShellLine), findsOneWidget);
      expect(
        find.bySemanticsLabel(shellRowLabel(1)),
        findsOneWidget,
        reason: 'la rangée ne montre que la semaine en cours',
      );
    });
  });

  group('rangée des coquillages de la semaine (CA12, CA18, cas limite)', () {
    homeTest('CA12, CA18 : la rangée s\'annonce « N coquillages cette '
        'semaine », N comprenant l\'entrée qui vient d\'être enregistrée', (
      tester,
    ) async {
      await start(tester, HomeEnv(weekJournal({1: 4, 2: 3})));

      await saveAndSettle(tester, mood: 5);

      expect(find.bySemanticsLabel(shellRowLabel(3)), findsOneWidget);
    });

    homeTest('CA18 : un seul coquillage : « 1 coquillage cette semaine »', (
      tester,
    ) async {
      await start(tester, HomeEnv(weekJournal({})));

      await saveAndSettle(tester, mood: 5);

      expect(
        find.bySemanticsLabel('1 coquillage cette semaine'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(RegExp(r'^1 coquillages')), findsNothing);
    });

    homeTest('CA12 : 7 entrées dans la semaine : 7 coquillages, pas de '
        '« +N »', (tester) async {
      await start(tester, HomeEnv(weekWith(6)));

      await saveAndSettle(tester, mood: 4);

      expect(find.text(nthShellLine(7)), findsOneWidget);
      expect(find.bySemanticsLabel(shellRowLabel(7)), findsOneWidget);
      expect(find.textContaining('+'), findsNothing);
    });

    homeTest('CA12, cas limite : 8e entrée de la semaine : 7 coquillages puis '
        '« +1 »', (tester) async {
      await start(tester, HomeEnv(weekWith(7)));

      await saveAndSettle(tester, mood: 4);

      expect(find.text(nthShellLine(8)), findsOneWidget);
      expect(find.text('+1'), findsOneWidget);
      expect(find.bySemanticsLabel(shellRowLabel(8)), findsOneWidget);
    });

    homeTest('CA12 : 10 entrées dans la semaine : « +3 »', (tester) async {
      await start(tester, HomeEnv(weekWith(9)));

      await saveAndSettle(tester, mood: 4);

      expect(find.text('+3'), findsOneWidget);
      expect(find.bySemanticsLabel(shellRowLabel(10)), findsOneWidget);
    });

    homeTest('CA12 : les coquillages de la rangée prennent les couleurs de '
        'leurs humeurs, de la plus ancienne à la plus récente', (tester) async {
      final key = GlobalKey();
      final repo = FakeEntryRepository(clock: () => eveningNow);
      repo.seed(mood: 5, createdAt: octoberDay(1));
      repo.seed(mood: 2, createdAt: octoberDay(2));
      await start(tester, HomeEnv(repo), instant: true, boundary: key);

      await saveAndSettle(tester, mood: 3);

      // Sous la phrase, il ne reste que la rangée : le grand coquillage est au-dessus.
      final below = tester.getRect(find.text(nthShellLine(3))).bottom.ceil();
      final pixels = await capture(tester, key);
      final x5 = leftmostFrom(pixels, light.mood5, below);
      final x2 = leftmostFrom(pixels, light.mood2, below);
      final x3 = leftmostFrom(pixels, light.mood3, below);
      expect(x5, isNotNull, reason: 'un coquillage d\'humeur 5 dans la rangée');
      expect(x2, isNotNull, reason: 'un coquillage d\'humeur 2 dans la rangée');
      expect(x3, isNotNull, reason: 'un coquillage d\'humeur 3 dans la rangée');
      expect(x5!, lessThan(x2!), reason: 'lundi avant mardi');
      expect(x2, lessThan(x3!), reason: 'l\'entrée du soir en dernier');
    });

    homeTest('CA12 : le grand coquillage a la couleur de l\'humeur '
        'enregistrée', (tester) async {
      for (final mood in [3, 5]) {
        final key = GlobalKey();
        await start(
          tester,
          HomeEnv(weekJournal({})),
          instant: true,
          boundary: key,
        );

        await saveAndSettle(tester, mood: mood);

        final pixels = await capture(tester, key);
        expect(
          countColor(pixels, light.moodColor(mood)),
          greaterThan(4000),
          reason: 'humeur $mood',
        );
        await tester.pumpWidget(const SizedBox());
      }
    });
  });

  group('célébration douce, humeur 1 ou 2 (CA13)', () {
    for (final mood in [1, 2]) {
      homeTest('CA13 : humeur $mood : titre « Entrée enregistrée », phrase '
          '« Elle rejoint ta plage. », ni rang ni rangée', (tester) async {
        await start(tester, HomeEnv(weekJournal({1: 4, 2: 3})));

        await saveAndSettle(tester, mood: mood);

        expect(find.text(softCelebrationTitle), findsOneWidget);
        expect(find.text(softCelebrationLine), findsOneWidget);
        expect(find.text(continueLabel), findsOneWidget);
        expect(find.text(celebrationTitle), findsNothing);
        expect(find.textContaining('de la semaine'), findsNothing);
        expect(find.textContaining('+'), findsNothing);
        expect(find.bySemanticsLabel(RegExp('coquillage')), findsNothing);
        expect(find.byType(EntryFormScreen), findsNothing);
      });

      homeTest('CA13 : humeur $mood : fond `hero`', (tester) async {
        await start(tester, HomeEnv(weekJournal({1: 4})));

        await saveAndSettle(tester, mood: mood);

        expect(
          scaffoldColor(tester, find.text(softCelebrationTitle)),
          light.hero,
        );
      });

      homeTest('CA13, CA19 : humeur $mood : même sous animations d\'ambiance, '
          'rien ne bouge : aucune animation, image identique d\'un instant à '
          'l\'autre', (tester) async {
        final key = GlobalKey();
        await start(
          tester,
          HomeEnv(weekJournal({1: 4})),
          ambient: true,
          instant: true,
          boundary: key,
        );
        await fillAndSave(tester, mood: mood);
        await pumpUntilCelebrated(tester);

        await tester.pump(const Duration(milliseconds: 50));
        final early = (await capture(tester, key)).bytes;
        await tester.pump(const Duration(milliseconds: 1500));
        final late = (await capture(tester, key)).bytes;

        expect(late, early, reason: 'ni apparition animée ni bulles');
        expect(tester.hasRunningAnimations, isFalse);
      });
    }

    homeTest('CA13 : la célébration douce ne dépend pas du texte : une humeur '
        '2 avec texte est douce aussi', (tester) async {
      await start(tester, HomeEnv(weekJournal({})));

      await saveAndSettle(tester, mood: 2, text: 'Une journée lourde.');

      expect(find.text(softCelebrationTitle), findsOneWidget);
    });
  });

  group('pas de célébration (CA14, CA15)', () {
    homeTest('CA14 : un texte en détresse ouvre l\'écran d\'aide, sans '
        'célébration', (tester) async {
      final env = HomeEnv(weekJournal({1: 4}));
      await start(tester, env);

      await saveAndSettle(tester, mood: 4, text: 'envie de mourir');

      expect(find.text(helpTitle), findsOneWidget);
      expectCelebrationGone();
      expect(env.repo.entries, hasLength(2));
    });

    homeTest('CA14 : une série d\'humeurs basses ouvre l\'écran d\'aide, sans '
        'célébration', (tester) async {
      final repo = FakeEntryRepository(clock: () => eveningNow);
      repo.seed(mood: 1, createdAt: DateTime(2026, 10, 8, 20));
      repo.seed(mood: 1, createdAt: DateTime(2026, 10, 12, 20));
      await start(tester, HomeEnv(repo));

      await saveAndSettle(tester, mood: 1);

      expect(find.text(helpTitle), findsOneWidget);
      expectCelebrationGone();
    });

    homeTest('CA14 : avec des sujets, la détresse ouvre quand même l\'écran '
        'd\'aide seul, qui ne parle pas des sujets', (tester) async {
      final env = HomeEnv(weekJournal({}));
      await start(tester, env);

      await saveAndSettle(
        tester,
        mood: 3,
        text: 'envie de mourir',
        topics: [Topic.work, Topic.sleep],
      );

      expect(find.text(helpTitle), findsOneWidget);
      expectCelebrationGone();
      expect(find.text(topicsTitle), findsNothing);
      expect(find.text('travail'), findsNothing);
      expect(env.repo.entries.single.topics, [Topic.sleep, Topic.work]);
    });

    homeTest('CA14 : après l\'écran d\'aide, le retour mène à l\'accueil sans '
        'célébration', (tester) async {
      await start(tester, HomeEnv(weekJournal({})));
      await saveAndSettle(tester, mood: 3, text: 'envie de mourir');

      await tester.tap(find.text(backToJournal));
      await settle(tester);

      expectListShown(tester);
    });

    homeTest('CA15 : une erreur à l\'enregistrement : pas de célébration, la '
        'saisie garde le bandeau d\'erreur', (tester) async {
      final repo = weekJournal({1: 4});
      repo.beforeAdd = () async => throw StateError('stockage plein');
      await start(tester, HomeEnv(repo));

      await saveAndSettle(tester, mood: 4, text: 'Un texte à garder.');

      expectCelebrationGone();
      expect(find.text("L'entrée n'a pas été enregistrée"), findsOneWidget);
      expect(find.text('Comment ça va ?'), findsOneWidget);
      expect(inputText(tester), 'Un texte à garder.');
    });

    homeTest('CA15 : « Réessayer » réussi mène alors à la célébration', (
      tester,
    ) async {
      final repo = weekJournal({1: 4});
      repo.beforeAdd = () async => throw StateError('stockage plein');
      await start(tester, HomeEnv(repo));
      await saveAndSettle(tester, mood: 4);
      expectCelebrationGone();

      repo.beforeAdd = null;
      await tester.tap(find.text('Réessayer'));
      await settle(tester);

      expect(find.text(celebrationTitle), findsOneWidget);
      expect(repo.entries, hasLength(2));
    });
  });

  group('« Continuer » et le geste de retour (CA16)', () {
    homeTest('CA16 : « Continuer » ramène à l\'accueil, avec l\'entrée en tête '
        'de la liste', (tester) async {
      final repo = FakeEntryRepository(clock: () => eveningNow);
      repo.seed(
        mood: 3,
        text: 'Lundi tranquille.',
        createdAt: octoberDay(1),
        status: AnalysisStatus.skipped,
      );
      await start(tester, HomeEnv(repo));
      await saveAndSettle(tester, mood: 4, text: 'Ce soir, la mer.');

      await continueFromCelebration(tester);

      expectListShown(tester);
      expect(
        tester.getTopLeft(find.textContaining('Ce soir, la mer.')).dy,
        lessThan(
          tester.getTopLeft(find.textContaining('Lundi tranquille.')).dy,
        ),
      );
    });

    homeTest('CA16 : un geste de retour fait comme « Continuer »', (
      tester,
    ) async {
      await start(tester, HomeEnv(weekJournal({1: 4})));
      await saveAndSettle(tester, mood: 4, text: 'Ce soir, la mer.');
      expect(find.text(celebrationTitle), findsOneWidget);

      await tester.binding.handlePopRoute();
      await settle(tester);

      expectListShown(tester);
      expect(find.textContaining('Ce soir, la mer.'), findsOneWidget);
    });

    homeTest('CA16 : la célébration douce se quitte de la même façon', (
      tester,
    ) async {
      await start(tester, HomeEnv(weekJournal({1: 4})));
      await saveAndSettle(tester, mood: 2);

      await continueFromCelebration(tester);

      expectListShown(tester);
    });

    homeTest('CA16 : après « Continuer », une nouvelle saisie est possible et '
        'mène à une nouvelle célébration', (tester) async {
      await start(tester, HomeEnv(weekJournal({1: 4})));
      await saveAndSettle(tester, mood: 4);
      await continueFromCelebration(tester);

      await saveAndSettle(tester, mood: 5);

      expect(find.text(nthShellLine(3)), findsOneWidget);
    });

    group('proposition du modèle (RM31, spec 003)', () {
      HomeEnv absentModel({bool offerShown = false}) {
        final env = HomeEnv(
          weekJournal({1: 4}),
          downloader: FakeModelDownloader(const ModelAbsent()),
        );
        env.settings.modelOfferShown = offerShown;
        return env;
      }

      homeTest('CA16 : la célébration passe avant la proposition : juste '
          'après l\'enregistrement, la proposition ne s\'ouvre pas', (
        tester,
      ) async {
        final env = absentModel();
        await start(tester, env);

        await saveAndSettle(tester, mood: 3, text: 'Journée calme.');

        expect(find.text(celebrationTitle), findsOneWidget);
        expect(find.byType(ModelDownloadScreen), findsNothing);
        expect(find.text(offerTitle), findsNothing);
        expect(env.downloader.startCalls, 0);
      });

      homeTest('CA16 : « Continuer » ouvre alors la proposition du modèle, '
          'marquée comme affichée', (tester) async {
        final env = absentModel();
        await start(tester, env);
        await saveAndSettle(tester, mood: 3, text: 'Journée calme.');

        await continueFromCelebration(tester);

        expect(find.byType(ModelDownloadScreen), findsOneWidget);
        expect(find.text(offerTitle), findsOneWidget);
        expect(find.text(celebrationTitle), findsNothing);
        expect(env.settings.modelOfferShown, isTrue);
        expect(env.downloader.startCalls, 0);
      });

      homeTest('CA16 : un geste de retour ouvre aussi la proposition', (
        tester,
      ) async {
        final env = absentModel();
        await start(tester, env);
        await saveAndSettle(tester, mood: 3, text: 'Journée calme.');

        await tester.binding.handlePopRoute();
        await settle(tester);

        expect(find.text(offerTitle), findsOneWidget);
      });

      homeTest('CA16 : la célébration douce mène elle aussi à la '
          'proposition', (tester) async {
        final env = absentModel();
        await start(tester, env);
        await saveAndSettle(tester, mood: 2, text: 'Journée lourde.');
        expect(find.text(softCelebrationTitle), findsOneWidget);

        await continueFromCelebration(tester);

        expect(find.text(offerTitle), findsOneWidget);
      });

      homeTest('CA16 : « Plus tard » dans la proposition ramène à '
          'l\'accueil', (tester) async {
        final env = absentModel();
        await start(tester, env);
        await saveAndSettle(tester, mood: 3, text: 'Journée calme.');
        await continueFromCelebration(tester);

        await tester.tap(find.text(later));
        await settle(tester);

        expectListShown(tester);
        expect(find.textContaining('Journée calme.'), findsOneWidget);
      });

      homeTest('CA16 : proposition déjà affichée : « Continuer » ramène '
          'directement à l\'accueil', (tester) async {
        final env = absentModel(offerShown: true);
        await start(tester, env);
        await saveAndSettle(tester, mood: 3, text: 'Journée calme.');

        await continueFromCelebration(tester);

        expect(find.byType(ModelDownloadScreen), findsNothing);
        expectListShown(tester);
      });

      homeTest('CA16 : une entrée sans texte n\'ouvre pas la proposition '
          '(RM24)', (tester) async {
        final env = absentModel();
        await start(tester, env);
        await saveAndSettle(tester, mood: 3);

        await continueFromCelebration(tester);

        expect(find.byType(ModelDownloadScreen), findsNothing);
        expectListShown(tester);
        expect(env.settings.modelOfferShown, isFalse);
      });

      homeTest('CA16 : modèle prêt : « Continuer » ramène à l\'accueil', (
        tester,
      ) async {
        final env = HomeEnv(weekJournal({1: 4}));
        await start(tester, env);
        await saveAndSettle(tester, mood: 3, text: 'Journée calme.');

        await continueFromCelebration(tester);

        expect(find.byType(ModelDownloadScreen), findsNothing);
        expectListShown(tester);
      });

      homeTest('CA16 : la proposition ne s\'ouvre qu\'une fois : à l\'entrée '
          'suivante, « Continuer » ramène à l\'accueil', (tester) async {
        final env = absentModel();
        await start(tester, env);
        await saveAndSettle(tester, mood: 3, text: 'Première.');
        await continueFromCelebration(tester);
        await tester.tap(find.text(later));
        await settle(tester);

        await saveAndSettle(tester, mood: 3, text: 'Seconde.');
        await continueFromCelebration(tester);

        expect(find.byType(ModelDownloadScreen), findsNothing);
        expectListShown(tester);
      });
    });
  });

  group('lecture de la semaine en erreur (CA17)', () {
    homeTest('CA17 : la célébration s\'affiche avec « Il rejoint ta plage. », '
        'sans rang ni rangée', (tester) async {
      final repo = FailingReadsAfterAddRepository(clock: () => eveningNow);
      repo.seed(mood: 4, createdAt: octoberDay(1));
      await start(tester, HomeEnv(repo));

      await saveAndSettle(tester, mood: 4);

      expect(find.text(fallbackCelebrationLine), findsOneWidget);
      expect(find.textContaining('de la semaine'), findsNothing);
      expect(find.bySemanticsLabel(RegExp('coquillage')), findsNothing);
      expect(find.textContaining('+'), findsNothing);
      expect(find.text(continueLabel), findsOneWidget);
      expect(repo.entries, hasLength(2), reason: 'l\'entrée est enregistrée');
    });

    homeTest('CA17 : « Continuer » quitte cette célébration comme les '
        'autres', (tester) async {
      final repo = FailingReadsAfterAddRepository(clock: () => eveningNow);
      await start(tester, HomeEnv(repo));
      await saveAndSettle(tester, mood: 4);

      await continueFromCelebration(tester);

      expectCelebrationGone();
      expect(find.byType(EntryFormScreen), findsNothing);
    });
  });

  group('lecteur d\'écran (CA18)', () {
    homeTest('CA18 : le titre est annoncé en premier ; la phrase, la rangée '
        'et « Continuer » suivent, rien d\'autre', (tester) async {
      await start(tester, HomeEnv(weekJournal({1: 4, 2: 3})));

      await saveAndSettle(tester, mood: 5);

      final labels = semanticLabels(tester);
      expect(labels.first, celebrationTitle);
      expect(labels, hasLength(4), reason: '$labels');
      expect(
        labels,
        containsAll([nthShellLine(3), shellRowLabel(3), continueLabel]),
      );
    });

    homeTest('CA18 : avec « +N », la rangée reste une seule annonce', (
      tester,
    ) async {
      await start(tester, HomeEnv(weekWith(7)));

      await saveAndSettle(tester, mood: 5);

      final labels = semanticLabels(tester);
      expect(labels.first, celebrationTitle);
      expect(labels, hasLength(4), reason: '$labels');
      expect(labels, contains(shellRowLabel(8)));
    });

    homeTest('CA18 : « Continuer » est annoncé comme un bouton', (
      tester,
    ) async {
      await start(tester, HomeEnv(weekJournal({})));

      await saveAndSettle(tester, mood: 5);

      expect(
        anyButtonNode(tester, find.bySemanticsLabel(continueLabel)),
        isTrue,
      );
    });

    homeTest('CA18 : version douce : titre, phrase et « Continuer » ; ni '
        'coquillage ni rangée annoncés', (tester) async {
      await start(tester, HomeEnv(weekJournal({1: 4})));

      await saveAndSettle(tester, mood: 1);

      final labels = semanticLabels(tester);
      expect(labels.first, softCelebrationTitle);
      expect(labels, hasLength(3), reason: '$labels');
      expect(labels, containsAll([softCelebrationLine, continueLabel]));
    });
  });

  group('animations (CA12, CA19)', () {
    homeTest('CA12 : le coquillage apparaît par une animation finie : absent '
        'au début, entier ensuite, puis immobile', (tester) async {
      final key = GlobalKey();
      await start(
        tester,
        HomeEnv(weekJournal({})),
        ambient: true,
        instant: true,
        boundary: key,
      );
      await fillAndSave(tester, mood: 4);
      await pumpUntilCelebrated(tester);

      await tester.pump(const Duration(milliseconds: 50));
      final early = countColor(await capture(tester, key), light.mood4);
      await tester.pump(const Duration(milliseconds: 900));
      final done = countColor(await capture(tester, key), light.mood4);
      await tester.pump(const Duration(milliseconds: 500));
      final later = countColor(await capture(tester, key), light.mood4);

      expect(done, greaterThan(4000), reason: 'le coquillage est entier');
      expect(early, lessThan(done * 0.8), reason: 'il apparaît en 0,7 s');
      expect(later, done, reason: 'l\'animation est finie');
    });

    homeTest('CA19 : sous « réduire les animations », le coquillage est là '
        'dès la première image et plus rien ne bouge', (tester) async {
      final key = GlobalKey();
      await start(
        tester,
        HomeEnv(weekJournal({})),
        ambient: true,
        reduceMotion: true,
        instant: true,
        boundary: key,
      );
      await fillAndSave(tester, mood: 4);
      await pumpUntilCelebrated(tester);

      await tester.pump(const Duration(milliseconds: 50));
      final early = (await capture(tester, key));
      await tester.pump(const Duration(milliseconds: 1500));
      final later = (await capture(tester, key));

      expect(countColor(early, light.mood4), greaterThan(4000));
      expect(
        later.bytes,
        early.bytes,
        reason: 'aucune bulle, aucune apparition',
      );
      expect(tester.hasRunningAnimations, isFalse);
    });

    homeTest('CA19 : sous « réduire les animations », pas d\'animation et '
        '`pumpAndSettle` se termine', (tester) async {
      await start(
        tester,
        HomeEnv(weekJournal({1: 4})),
        ambient: true,
        reduceMotion: true,
      );
      await fillAndSave(tester, mood: 5);

      await tester.pumpAndSettle();

      expect(find.text(celebrationTitle), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
    });

    homeTest('CA12 : sans « réduire les animations », des bulles d\'air '
        'tournent sous la célébration complète', (tester) async {
      await start(tester, HomeEnv(weekJournal({1: 4})), ambient: true);
      await fillAndSave(tester, mood: 5);
      await pumpUntilCelebrated(tester);

      await tester.pump(const Duration(seconds: 2));

      expect(tester.hasRunningAnimations, isTrue);
    });
  });

  group('texte à 200 % et thème sombre (CA20)', () {
    homeTest('CA20 : célébration complète avec « +N » à 200 % en sombre : rien '
        'n\'est tronqué, rien ne déborde, « Continuer » se touche', (
      tester,
    ) async {
      useDarkPlatform(tester);
      final key = GlobalKey();
      await start(tester, HomeEnv(weekWith(7)), instant: true, boundary: key);
      await saveAndSettle(tester, mood: 5);

      // La taille de texte passe à 200 % pendant que la célébration est affichée.
      await useSystemTextScale(tester, 2.0);
      await settle(tester);

      expect(tester.takeException(), isNull);
      final screen = find.ancestor(
        of: find.text(celebrationTitle),
        matching: find.byType(Scaffold),
      );
      expect(scaffoldColor(tester, find.text(celebrationTitle)), dark.hero);
      expectNothingTruncated(tester, screen, 'célébration à 200 %');
      expect(find.text(nthShellLine(8)), findsOneWidget);
      expect(find.text('+1'), findsOneWidget);
      expect(
        countColor(await capture(tester, key), dark.moodColor(5)),
        greaterThan(4000),
      );
      await continueFromCelebration(tester);
      expectListShown(tester);
    }, tall: false);

    homeTest('CA20 : célébration douce à 200 % en sombre : rien n\'est '
        'tronqué', (tester) async {
      useDarkPlatform(tester);
      await start(tester, HomeEnv(weekJournal({1: 4})));
      await saveAndSettle(tester, mood: 1);

      await useSystemTextScale(tester, 2.0);
      await settle(tester);

      expect(tester.takeException(), isNull);
      final screen = find.ancestor(
        of: find.text(softCelebrationTitle),
        matching: find.byType(Scaffold),
      );
      expect(scaffoldColor(tester, find.text(softCelebrationTitle)), dark.hero);
      expectNothingTruncated(tester, screen, 'célébration douce à 200 %');
      await continueFromCelebration(tester);
      expectListShown(tester);
    }, tall: false);
  });
}
