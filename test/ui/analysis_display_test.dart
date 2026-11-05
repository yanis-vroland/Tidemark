// Affichage de l'étiquetage (spec 004, CA18 à CA30) : puces et mentions de la liste,
// section « Étiquettes » du détail, accessibilité, 200 %, thème sombre. Les textes
// font foi dans la maquette docs/maquettes/004-etiquetage-automatique/ ; les composants
// `TagChip` et `LoadingNote` sont décrits dans docs/maquettes/000-charte/components/.
// File d'analyse réglée à la main (`StubAnalysisQueue`) : ces tests ne dépendent pas de
// la file réelle.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/analysis/analysis_queue.dart';
import 'package:tidemark/analysis/mood_analyzer.dart';
import 'package:tidemark/entries/entry.dart';
import 'package:tidemark/main.dart';
import 'package:tidemark/model/model_state.dart';
import 'package:tidemark/ui/analysis_scope.dart';
import 'package:tidemark/ui/screens/entry_detail_screen.dart';
import 'package:tidemark/ui/screens/entry_list_screen.dart';
import 'package:tidemark/ui/screens/model_download_screen.dart';
import 'package:tidemark/ui/theme/tidemark_colors.dart';

import '../support/analysis_harness.dart';
import '../support/distress_harness.dart'
    show expectNoTruncatedText, paintedColors, readingOrder;
import '../support/fake_entry_repository.dart';
import '../support/fake_model_downloader.dart';
import '../support/fake_settings_repository.dart';
import '../support/model_texts.dart'
    show downloadButton, isAnnounced, offerTitle;
import '../support/ui_harness.dart';

const analysingText = 'Analyse en cours sur ton téléphone…';
const queuedText = "En attente d'analyse sur ton téléphone.";
const absentText =
    "Pas encore analysée : le modèle d'analyse n'est pas sur ton téléphone.";
const downloadingText =
    'Pas encore analysée : le modèle est en cours de téléchargement.';
const unavailableText =
    "Pas encore analysée : le modèle n'a pas pu être chargé. Nouvel essai au "
    'prochain lancement de Tidemark.';
const noTagText = "Aucune étiquette n'a été proposée pour cette entrée.";
const analysedMention = 'Analysé sur ton téléphone';

const bodyText =
    "Longue journée au travail, mais la balade du soir au bord de l'eau m'a fait "
    'du bien.';
const distressText = 'J’ai envie de mourir.';

const light = TidemarkColors.light;
const dark = TidemarkColors.dark;

const loading = ModelDownloading(receivedBytes: 1, totalBytes: 10);

/// Faux, file réglée à la main et écrans.
class UiEnv {
  UiEnv({ModelState model = readyModel})
    : downloader = FakeModelDownloader(model);

  final repo = FakeEntryRepository(clock: () => fixedNow);
  final FakeModelDownloader downloader;
  final queue = StubAnalysisQueue();

  Entry _current(int id) => repo.entries.firstWhere((e) => e.id == id);

  Future<Entry> tagged(
    DateTime at,
    String text,
    List<Tag> tags, {
    int mood = 4,
  }) async {
    final e = repo.seed(mood: mood, text: text, createdAt: at);
    await repo.saveAnalysis(e.id, Tagged(tags));
    return _current(e.id);
  }

  Entry pending(DateTime at, String text, {int mood = 3}) =>
      repo.seed(mood: mood, text: text, createdAt: at);

  Future<Entry> untagged(DateTime at, String text, {int mood = 3}) async {
    final e = repo.seed(mood: mood, text: text, createdAt: at);
    await repo.saveAnalysis(e.id, const Untagged());
    return _current(e.id);
  }

  Entry skipped(DateTime at, {String? text, int mood = 3}) => repo.seed(
    mood: mood,
    text: text,
    createdAt: at,
    status: AnalysisStatus.skipped,
  );

  Widget app() => TidemarkApp(
    repository: repo,
    settings: FakeSettingsRepository(),
    clock: () => fixedNow,
    downloader: downloader,
    analysisQueue: queue,
  );

  Widget detail(Entry entry, {double textScale = 1.0}) => AnalysisScope(
    queue: queue,
    child: testApp(
      EntryDetailScreen(
        entry: entry,
        repository: repo,
        downloader: downloader,
        clock: () => fixedNow,
      ),
      textScale: textScale,
    ),
  );

  Widget list({double textScale = 1.0}) => AnalysisScope(
    queue: queue,
    child: testApp(
      EntryListScreen(
        repository: repo,
        settings: FakeSettingsRepository(),
        clock: () => fixedNow,
        downloader: downloader,
      ),
      textScale: textScale,
    ),
  );
}

Future<void> show(WidgetTester tester, Widget app) async {
  await tester.pumpWidget(app);
  await settle(tester);
}

/// `testWidgets` avec la sémantique activée (libérée dans le test, comme l'exige le
/// harnais) et un écran de téléphone.
void semanticsTestWidgets(
  String description,
  Future<void> Function(WidgetTester tester) body,
) {
  testWidgets(description, (tester) async {
    usePhoneScreen(tester);
    final handle = tester.ensureSemantics();
    try {
      await body(tester);
    } finally {
      handle.dispose();
    }
  });
}

void useDarkTheme(WidgetTester tester) {
  tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
}

/// Messages envoyés au lecteur d'écran par `SemanticsService.announce`.
List<String> captureAnnouncements(WidgetTester tester) {
  final messages = <String>[];
  tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(
    SystemChannels.accessibility,
    (dynamic message) async {
      if (message is Map && message['type'] == 'announce') {
        final data = message['data'];
        if (data is Map) messages.add('${data['message']}');
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger
        .setMockDecodedMessageHandler<dynamic>(
          SystemChannels.accessibility,
          null,
        ),
  );
  return messages;
}

const finishedTaggedText =
    'Analyse terminée. Émotions : fatigue, calme. Thèmes : travail.';
const finishedUntaggedText =
    "Analyse terminée. Aucune étiquette n'a été proposée pour cette entrée.";

/// Annonces de fin d'analyse parmi [announcements] (les autres annonces, comme le
/// changement de statut « Analyse en cours », ne comptent pas ici).
List<String> finishedAnnouncements(List<String> announcements) => [
  for (final m in announcements)
    if (m.startsWith('Analyse terminée')) m,
];

/// `semanticsTestWidgets` sur la plateforme [platform], remise à sa valeur en fin
/// de test.
void platformSemanticsTestWidgets(
  String description,
  TargetPlatform platform,
  Future<void> Function(WidgetTester tester) body,
) {
  semanticsTestWidgets(description, (tester) async {
    debugDefaultTargetPlatformOverride = platform;
    try {
      await body(tester);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

/// L'analyse de l'entrée du scénario se termine : résultat écrit, file au repos.
Future<void> finishAnalysis(
  WidgetTester tester,
  ({UiEnv env, Entry entry}) scenario,
  AnalysisResult result,
) async {
  await scenario.env.repo.saveAnalysis(scenario.entry.id, result);
  scenario.env.queue.setCurrent(null);
  await settle(tester);
}

/// Libellé du nœud sémantique ancêtre de [finder] (lui-même compris) qui porte le
/// drapeau de région vive ; `null` s'il n'y en a aucun.
String? liveRegionLabel(WidgetTester tester, Finder finder) {
  SemanticsNode? node = tester.getSemantics(finder);
  while (node != null) {
    if (node.flagsCollection.isLiveRegion) return node.label;
    node = node.parent;
  }
  return null;
}

double top(WidgetTester tester, Finder finder) => tester.getTopLeft(finder).dy;

/// Couleur de fond de la puce qui porte [label] : celle du plus proche ancêtre qui
/// peint un fond.
Color? chipColor(WidgetTester tester, String label) {
  Color? colorOf(Widget w) => switch (w) {
    DecoratedBox(:final decoration) => switch (decoration) {
      BoxDecoration(:final color) => color,
      ShapeDecoration(:final color) => color,
      _ => null,
    },
    ColoredBox(:final color) => color,
    Material(:final color) => color,
    _ => null,
  };
  final ancestors = find.ancestor(
    of: find.text(label),
    matching: find.byWidgetPredicate((w) => colorOf(w) != null),
  );
  expect(ancestors, findsWidgets, reason: 'aucun fond derrière « $label »');
  return colorOf(ancestors.evaluate().first.widget);
}

/// Les puces [labels] tiennent dans l'écran (393 de large) et passent à la ligne :
/// au moins deux rangées.
void expectChipsWrapped(WidgetTester tester, List<String> labels) {
  final rows = <int>{};
  for (final label in labels) {
    final rect = tester.getRect(find.text(label));
    expect(rect.left, greaterThanOrEqualTo(0), reason: label);
    expect(rect.right, lessThanOrEqualTo(393), reason: label);
    rows.add(rect.top.round());
  }
  expect(
    rows.length,
    greaterThanOrEqualTo(2),
    reason: 'les puces auraient dû passer à la ligne',
  );
}

/// Jeu de cinq puces longues, pour forcer le retour à la ligne à 200 %.
final longTags = [
  emotion('frustration'),
  emotion('gratitude'),
  emotion('tristesse'),
  theme('famille'),
  theme('travail'),
];
const longTagLabels = [
  'frustration',
  'gratitude',
  'tristesse',
  'famille',
  'travail',
];

/// Les sept états du détail, par nom.
const stateNames = [
  'étiquetée',
  'analyse en cours',
  'en attente de son tour',
  'modèle absent',
  'modèle en cours de téléchargement',
  'modèle impossible à charger',
  'sans étiquette',
];

Future<({UiEnv env, Entry entry})> scenario(String name) async {
  final at = DateTime(2026, 10, 14, 21, 40);
  switch (name) {
    case 'étiquetée':
      final env = UiEnv();
      return (
        env: env,
        entry: await env.tagged(at, bodyText, fatigueCalmeTravail),
      );
    case 'analyse en cours':
      final env = UiEnv();
      final e = env.pending(at, bodyText);
      env.queue.setCurrent(e.id);
      return (env: env, entry: e);
    case 'en attente de son tour':
      final env = UiEnv();
      final e = env.pending(at, bodyText);
      return (env: env, entry: e);
    case 'modèle absent':
      final env = UiEnv(model: const ModelAbsent());
      return (env: env, entry: env.pending(at, bodyText));
    case 'modèle en cours de téléchargement':
      final env = UiEnv(model: loading);
      return (env: env, entry: env.pending(at, bodyText));
    case 'modèle impossible à charger':
      final env = UiEnv();
      final e = env.pending(at, bodyText);
      env.queue.setState(AnalysisQueueState.unavailable);
      return (env: env, entry: e);
    case 'sans étiquette':
      final env = UiEnv();
      return (env: env, entry: await env.untagged(at, bodyText));
  }
  throw ArgumentError(name);
}

void main() {
  group('liste : CA19, CA20, CA27', () {
    testWidgets('CA19 : l\'entrée étiquetée montre ses puces sous le texte, '
        'émotions puis thèmes, sans la mention du détail', (tester) async {
      usePhoneScreen(tester);
      final env = UiEnv();
      await env.tagged(DateTime(2026, 10, 14, 21, 40), bodyText, [
        emotion('fatigue'),
        emotion('calme'),
        theme('travail'),
        theme('nature'),
      ]);

      await show(tester, env.app());

      for (final label in ['fatigue', 'calme', 'travail', 'nature']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      final textBottom = tester
          .getBottomLeft(find.textContaining('Longue journée'))
          .dy;
      Offset at(String label) => tester.getTopLeft(find.text(label));
      for (final label in ['fatigue', 'calme', 'travail', 'nature']) {
        expect(
          at(label).dy,
          greaterThanOrEqualTo(textBottom),
          reason: '$label sous le texte',
        );
      }
      // Émotions puis thèmes : lecture de gauche à droite, rangée par rangée.
      final order = ['fatigue', 'calme', 'travail', 'nature'];
      final sorted = [...order]
        ..sort((a, b) {
          // Même rangée à 8 points près : les autocollants pivotent
          // légèrement (spec 008, CA12).
          final dy = at(a).dy - at(b).dy;
          final byRow = dy.abs() < 8 ? 0 : dy.sign.toInt();
          return byRow != 0 ? byRow : at(a).dx.compareTo(at(b).dx);
        });
      expect(sorted, order);
      expect(find.text(analysedMention), findsNothing);
      expect(find.text('Étiquettes'), findsNothing);
    });

    testWidgets('CA20 : l\'entrée en cours d\'analyse montre « Analyse en '
        'cours… » à la place des puces ; les autres cartes sans étiquette ne '
        'montrent ni puce ni mention', (tester) async {
      usePhoneScreen(tester);
      final env = UiEnv();
      await env.tagged(
        DateTime(2026, 10, 14, 21, 40),
        'Texte étiqueté',
        fatigueCalmeTravail,
      );
      final running = env.pending(
        DateTime(2026, 10, 14, 18, 5),
        'Texte en cours',
      );
      env.pending(DateTime(2026, 10, 14, 12), 'Texte en attente');
      await env.untagged(DateTime(2026, 10, 14, 10), 'Texte sans étiquette');
      env.skipped(DateTime(2026, 10, 14, 8, 15));
      env.queue.setCurrent(running.id);

      await show(tester, env.app());

      expect(find.text(analysingText), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final note = top(tester, find.text(analysingText));
      expect(note, greaterThan(top(tester, find.text('Texte en cours'))));
      expect(note, lessThan(top(tester, find.text('Texte en attente'))));
      // Les trois puces de l'entrée étiquetée, et aucune autre.
      expect(find.text('fatigue'), findsOneWidget);
      expect(find.text('calme'), findsOneWidget);
      expect(find.text('travail'), findsOneWidget);
      // Aucune autre mention de l'analyse.
      expect(find.textContaining(RegExp('nalys')), findsOneWidget);
      expect(find.textContaining('En attente'), findsNothing);
      expect(find.textContaining('Pas encore'), findsNothing);
      expect(find.textContaining('Aucune étiquette'), findsNothing);
      expect(find.text(analysedMention), findsNothing);
    });

    testWidgets('CA20 : la mention suit la file : elle disparaît à la fin de '
        'l\'analyse et passe à l\'entrée suivante', (tester) async {
      usePhoneScreen(tester);
      final env = UiEnv();
      final first = env.pending(DateTime(2026, 10, 14, 18), 'Première');
      final second = env.pending(DateTime(2026, 10, 14, 12), 'Seconde');
      env.queue.setCurrent(first.id);
      await show(tester, env.app());
      expect(find.text(analysingText), findsOneWidget);
      expect(
        top(tester, find.text(analysingText)),
        lessThan(top(tester, find.text('Seconde'))),
      );

      env.queue.setCurrent(second.id);
      await settle(tester);
      expect(find.text(analysingText), findsOneWidget);
      expect(
        top(tester, find.text(analysingText)),
        greaterThan(top(tester, find.text('Seconde'))),
      );

      env.queue.setCurrent(null);
      await settle(tester);
      expect(find.text(analysingText), findsNothing);
    });

    semanticsTestWidgets(
      'CA27 : le libellé de la carte étiquetée se termine par '
      '« étiquettes : fatigue, calme, travail » ; les autres n\'en ont '
      'pas',
      (tester) async {
        usePhoneScreen(tester);
        final env = UiEnv();
        await env.tagged(
          DateTime(2026, 10, 14, 21, 40),
          "Balade au bord de l'eau.",
          fatigueCalmeTravail,
        );
        await env.untagged(DateTime(2026, 10, 14, 10), 'Sans étiquette');
        env.pending(DateTime(2026, 10, 14, 9), 'En attente');

        await show(tester, env.app());

        expect(
          find.bySemanticsLabel(
            RegExp(
              r'^Bien, humeur 4 sur 5, 21:40.*étiquettes : fatigue, calme, travail$',
            ),
          ),
          findsOneWidget,
        );
        expect(find.bySemanticsLabel(RegExp('étiquettes')), findsOneWidget);
      },
    );
  });

  group('mise à jour sans action de la personne : CA18', () {
    testWidgets('CA18 : la liste montre les puces dès que l\'analyse se '
        'termine', (tester) async {
      usePhoneScreen(tester);
      final env = UiEnv();
      final entry = env.pending(DateTime(2026, 10, 14, 21, 40), bodyText);
      await show(tester, env.app());
      expect(find.text('fatigue'), findsNothing);

      await env.repo.saveAnalysis(entry.id, Tagged(fatigueCalmeTravail));
      await settle(tester);

      expect(find.text('fatigue'), findsOneWidget);
      expect(find.text('calme'), findsOneWidget);
      expect(find.text('travail'), findsOneWidget);
    });

    testWidgets('CA18 : le détail ouvert se met à jour dès que l\'analyse se '
        'termine', (tester) async {
      usePhoneScreen(tester);
      final env = UiEnv();
      final entry = env.pending(DateTime(2026, 10, 14, 21, 40), bodyText);
      await show(tester, env.app());
      await tester.tap(find.textContaining('Longue journée'));
      await settle(tester);
      expect(find.text(queuedText), findsOneWidget);
      expect(find.text(analysedMention), findsNothing);

      await env.repo.saveAnalysis(entry.id, Tagged(fatigueCalmeTravail));
      await settle(tester);

      expect(find.text(queuedText), findsNothing);
      expect(find.text('fatigue'), findsOneWidget);
      expect(find.text('travail'), findsOneWidget);
      expect(find.text(analysedMention), findsOneWidget);
    });

    testWidgets('CA18 : le détail ouvert passe à « Aucune étiquette » quand '
        'l\'analyse ne donne rien', (tester) async {
      usePhoneScreen(tester);
      final env = UiEnv();
      final entry = env.pending(DateTime(2026, 10, 14, 21, 40), bodyText);
      await show(tester, env.app());
      await tester.tap(find.textContaining('Longue journée'));
      await settle(tester);

      await env.repo.saveAnalysis(entry.id, const Untagged());
      await settle(tester);

      expect(find.text(noTagText), findsOneWidget);
      expect(find.text(queuedText), findsNothing);
    });
  });

  group('détail : CA21 à CA26', () {
    testWidgets('CA21 : l\'entrée étiquetée montre, sous le texte, la section '
        '« Étiquettes », les lignes « Émotions » et « Thèmes » avec leurs '
        'puces, puis « Analysé sur ton téléphone »', (tester) async {
      usePhoneScreen(tester);
      final s = await scenario('étiquetée');

      await show(tester, s.env.detail(s.entry));

      final order = [
        find.textContaining('Longue journée'),
        find.text('Étiquettes'),
        find.text('Émotions'),
        find.text('fatigue'),
        find.text('calme'),
        find.text('Thèmes'),
        find.text('travail'),
        find.text(analysedMention),
      ];
      for (final finder in order) {
        expect(finder, findsOneWidget);
      }
      for (var i = 1; i < order.length; i++) {
        final previous = tester.getTopLeft(order[i - 1]);
        final next = tester.getTopLeft(order[i]);
        // Même rangée à 8 points près : les autocollants pivotent
        // légèrement (spec 008, CA12).
        final sameRow = (next.dy - previous.dy).abs() < 8;
        final inOrder = sameRow ? next.dx > previous.dx : next.dy > previous.dy;
        expect(inOrder, isTrue, reason: 'élément $i après l\'élément ${i - 1}');
      }
      expect(find.text(analysingText), findsNothing);
      expect(find.text(queuedText), findsNothing);
      expect(find.text(noTagText), findsNothing);
    });

    testWidgets('CA21 : une ligne sans étiquette n\'est pas affichée (que des '
        'thèmes)', (tester) async {
      usePhoneScreen(tester);
      final env = UiEnv();
      final entry = await env.tagged(DateTime(2026, 10, 14, 21, 40), bodyText, [
        theme('maison'),
      ]);

      await show(tester, env.detail(entry));

      expect(find.text('Étiquettes'), findsOneWidget);
      expect(find.text('Thèmes'), findsOneWidget);
      expect(find.text('maison'), findsOneWidget);
      expect(find.text('Émotions'), findsNothing);
      expect(find.text(analysedMention), findsOneWidget);
    });

    testWidgets('CA21 : une ligne sans étiquette n\'est pas affichée (que des '
        'émotions)', (tester) async {
      usePhoneScreen(tester);
      final env = UiEnv();
      final entry = await env.tagged(DateTime(2026, 10, 14, 21, 40), bodyText, [
        emotion('joie'),
      ]);

      await show(tester, env.detail(entry));

      expect(find.text('Émotions'), findsOneWidget);
      expect(find.text('joie'), findsOneWidget);
      expect(find.text('Thèmes'), findsNothing);
      expect(find.text(analysedMention), findsOneWidget);
    });

    testWidgets('CA22 : entrée en attente, modèle prêt, analysée par la file : '
        '« Analyse en cours… » avec son indicateur', (tester) async {
      usePhoneScreen(tester);
      final s = await scenario('analyse en cours');

      await show(tester, s.env.detail(s.entry));

      expect(find.text('Étiquettes'), findsOneWidget);
      expect(find.text(analysingText), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(queuedText), findsNothing);
      expect(find.text(analysedMention), findsNothing);
    });

    testWidgets('CA22 : entrée en attente de son tour : « En attente '
        'd\'analyse… », sans indicateur', (tester) async {
      usePhoneScreen(tester);
      final s = await scenario('en attente de son tour');

      await show(tester, s.env.detail(s.entry));

      expect(find.text('Étiquettes'), findsOneWidget);
      expect(find.text(queuedText), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text(analysingText), findsNothing);
    });

    testWidgets('CA22 : si la file analyse une autre entrée, celle-ci attend '
        'son tour, puis passe en cours quand son tour vient', (tester) async {
      usePhoneScreen(tester);
      final s = await scenario('en attente de son tour');
      final other = s.env.pending(DateTime(2026, 10, 13, 9), 'Autre texte');
      s.env.queue.setCurrent(other.id);

      await show(tester, s.env.detail(s.entry));
      expect(find.text(queuedText), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      s.env.queue.setCurrent(s.entry.id);
      await settle(tester);
      expect(find.text(analysingText), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(queuedText), findsNothing);
    });

    testWidgets('CA31 : file « indisponible » et entrée en attente : le détail '
        'dit que le modèle n\'a pas pu être chargé, sans bouton', (
      tester,
    ) async {
      usePhoneScreen(tester);
      final s = await scenario('modèle impossible à charger');

      await show(tester, s.env.detail(s.entry));

      expect(find.text('Étiquettes'), findsOneWidget);
      expect(find.text(unavailableText), findsOneWidget);
      expect(find.text(queuedText), findsNothing);
      expect(find.text(analysingText), findsNothing);
      expect(find.textContaining('Télécharger'), findsNothing);
      expect(find.textContaining('Réessayer'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      // Le seul bouton de l'écran est « Supprimer cette entrée » (et le retour).
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('CA23 : modèle absent : le message, le bouton « Télécharger le '
        'modèle (1,1 Go) », qui ouvre l\'écran du modèle sur la proposition '
        'sans lancer le téléchargement', (tester) async {
      usePhoneScreen(tester);
      final s = await scenario('modèle absent');
      await show(tester, s.env.detail(s.entry));

      expect(find.text(absentText), findsOneWidget);
      expect(find.text(downloadButton), findsOneWidget);
      expect(find.text(queuedText), findsNothing);

      await tester.tap(find.text(downloadButton));
      await settle(tester);

      expect(find.byType(ModelDownloadScreen), findsOneWidget);
      expect(find.text(offerTitle), findsOneWidget);
      expect(s.env.downloader.startCalls, 0);
    });

    testWidgets('CA23 : modèle en cours de téléchargement : le message, sans '
        'bouton', (tester) async {
      usePhoneScreen(tester);
      final s = await scenario('modèle en cours de téléchargement');

      await show(tester, s.env.detail(s.entry));

      expect(find.text(downloadingText), findsOneWidget);
      expect(find.text(downloadButton), findsNothing);
      expect(find.textContaining('Télécharger'), findsNothing);
      expect(find.text(absentText), findsNothing);
    });

    testWidgets('CA23, CA22 : le détail suit le modèle sans action : absent, '
        'téléchargement, prêt (en attente), puis analyse en cours', (
      tester,
    ) async {
      usePhoneScreen(tester);
      final s = await scenario('modèle absent');
      await show(tester, s.env.detail(s.entry));
      expect(find.text(absentText), findsOneWidget);

      s.env.downloader.emit(loading);
      await settle(tester);
      expect(find.text(downloadingText), findsOneWidget);
      expect(find.text(downloadButton), findsNothing);

      s.env.downloader.emit(readyModel);
      await settle(tester);
      expect(find.text(queuedText), findsOneWidget);
      expect(find.text(downloadingText), findsNothing);

      s.env.queue.setCurrent(s.entry.id);
      await settle(tester);
      expect(find.text(analysingText), findsOneWidget);
      expect(find.text(queuedText), findsNothing);
    });

    testWidgets(
      'CA24 : entrée « sans étiquette » : seulement « Aucune étiquette '
      'n\'a été proposée… », en ink-muted, sans danger ni puce',
      (tester) async {
        usePhoneScreen(tester);
        final s = await scenario('sans étiquette');

        await show(tester, s.env.detail(s.entry));

        expect(find.text('Étiquettes'), findsOneWidget);
        expect(find.text(noTagText), findsOneWidget);
        final painted = paintedColors(tester, find.text(noTagText));
        expect(painted, contains(light.inkMuted));
        expect(painted, isNot(contains(light.danger)));
        expect(find.text('Émotions'), findsNothing);
        expect(find.text('Thèmes'), findsNothing);
        expect(find.text(analysedMention), findsNothing);
        expect(find.text(queuedText), findsNothing);
        expect(find.text(analysingText), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsNothing);
      },
    );

    final skippedEntries = <String, Entry Function(UiEnv)>{
      'sans texte': (env) => env.skipped(DateTime(2026, 10, 14, 8, 15)),
      'en détresse': (env) => env.skipped(
        DateTime(2026, 10, 14, 8, 15),
        text: distressText,
        mood: 1,
      ),
    };
    final models = <String, ModelState>{
      'prêt': readyModel,
      'absent': const ModelAbsent(),
      'en cours de téléchargement': loading,
    };
    for (final entry in skippedEntries.entries) {
      for (final model in models.entries) {
        for (final unavailable in [false, true]) {
          testWidgets('CA25 : entrée « non analysée » (${entry.key}), modèle '
              '${model.key}${unavailable ? ', file indisponible' : ''} : '
              'aucune section « Étiquettes », aucune mention de l\'analyse', (
            tester,
          ) async {
            usePhoneScreen(tester);
            final env = UiEnv(model: model.value);
            if (unavailable) env.queue.setState(AnalysisQueueState.unavailable);
            final skipped = entry.value(env);

            await show(tester, env.detail(skipped));

            expect(find.text('Étiquettes'), findsNothing);
            expect(
              find.textContaining(RegExp('analys', caseSensitive: false)),
              findsNothing,
            );
            expect(find.textContaining('Télécharger'), findsNothing);
            expect(find.textContaining('étiquette'), findsNothing);
            expect(find.byType(CircularProgressIndicator), findsNothing);
            expect(find.text('Supprimer cette entrée'), findsOneWidget);
          });
        }
      }
    }

    semanticsTestWidgets(
      'CA26 : toucher une puce ne fait rien : l\'écran ne change '
      'pas, rien ne s\'ouvre, la puce n\'est pas un bouton',
      (tester) async {
        usePhoneScreen(tester);
        final env = UiEnv();
        final entry = await env.tagged(
          DateTime(2026, 10, 14, 21, 40),
          bodyText,
          [emotion('fatigue'), emotion('joie'), theme('travail')],
        );
        await show(tester, env.detail(entry));
        final before = find.byType(Text).evaluate().length;

        for (final label in ['fatigue', 'joie', 'travail']) {
          final node = tester.getSemantics(find.text(label));
          expect(
            node.getSemanticsData().hasAction(SemanticsAction.tap),
            isFalse,
            reason: label,
          );
          expect(node.flagsCollection.isButton, isFalse, reason: label);
          await tester.tap(find.text(label));
          await settle(tester);
        }

        expect(find.byType(EntryDetailScreen), findsOneWidget);
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byType(BottomSheet), findsNothing);
        expect(find.byType(EditableText), findsNothing);
        expect(find.byType(Text).evaluate().length, before);
        expect(find.text('fatigue'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('CA26 : toutes les puces ont la même couleur (tide-soft), '
        'quelle que soit l\'émotion', (tester) async {
      usePhoneScreen(tester);
      final env = UiEnv();
      final entry = await env.tagged(DateTime(2026, 10, 14, 21, 40), bodyText, [
        emotion('joie'),
        emotion('tristesse'),
        emotion('colère'),
        theme('sport'),
        theme('argent'),
      ]);
      await show(tester, env.detail(entry));

      for (final label in ['joie', 'tristesse', 'colère', 'sport', 'argent']) {
        expect(chipColor(tester, label), light.tideSoft, reason: label);
      }
    });

    testWidgets('CA26 : dans la liste aussi, les puces sont toutes en '
        'tide-soft', (tester) async {
      usePhoneScreen(tester);
      final env = UiEnv();
      await env.tagged(DateTime(2026, 10, 14, 21, 40), 'Texte.', [
        emotion('joie'),
        emotion('colère'),
        theme('sport'),
      ]);
      await show(tester, env.app());

      for (final label in ['joie', 'colère', 'sport']) {
        expect(chipColor(tester, label), light.tideSoft, reason: label);
      }
    });
  });

  group('accessibilité : CA28', () {
    semanticsTestWidgets(
      'CA28 : chaque ligne s\'annonce « Émotions : fatigue, calme » '
      'et « Thèmes : travail », sans lire les puces une à une',
      (tester) async {
        usePhoneScreen(tester);
        final s = await scenario('étiquetée');

        await show(tester, s.env.detail(s.entry));

        final reading = readingOrder(tester);
        expect(reading, contains('Émotions : fatigue, calme'));
        expect(reading, contains('Thèmes : travail'));
        expect(reading, isNot(contains('fatigue')));
        expect(reading, isNot(contains('calme')));
        expect(reading, isNot(contains('travail')));
      },
    );

    semanticsTestWidgets(
      'CA28 : « Analyse en cours… » s\'annonce comme un statut',
      (tester) async {
        usePhoneScreen(tester);
        final s = await scenario('analyse en cours');

        await show(tester, s.env.detail(s.entry));

        expect(isAnnounced(tester, find.text(analysingText)), isTrue);
      },
    );

    semanticsTestWidgets(
      'CA28 : un changement de statut de l\'analyse est annoncé '
      '(région vive sur le nouveau statut, ou annonce explicite)',
      (tester) async {
        usePhoneScreen(tester);
        final announcements = captureAnnouncements(tester);
        final s = await scenario('en attente de son tour');
        await show(tester, s.env.detail(s.entry));

        s.env.queue.setCurrent(s.entry.id);
        await settle(tester);

        final announced =
            isAnnounced(tester, find.text(analysingText)) ||
            announcements.any((m) => m.contains('Analyse en cours'));
        expect(announced, isTrue);
      },
    );

    // Fin de l'analyse (CA28, issue #29) : iOS par annonce explicite, Android par
    // région vive sur le nouveau statut, jamais les deux.
    platformSemanticsTestWidgets(
      'CA28 : iOS, de « en attente » à « étiquetée » : une seule annonce '
      'explicite, sans région vive',
      TargetPlatform.iOS,
      (tester) async {
        final announcements = captureAnnouncements(tester);
        final s = await scenario('analyse en cours');
        await show(tester, s.env.detail(s.entry));

        await finishAnalysis(tester, s, Tagged(fatigueCalmeTravail));

        expect(find.text('fatigue'), findsOneWidget);
        expect(finishedAnnouncements(announcements), [finishedTaggedText]);
        expect(isAnnounced(tester, find.text('fatigue')), isFalse);
      },
    );

    platformSemanticsTestWidgets(
      'CA28 : iOS, de « en attente » à « sans étiquette » : une seule '
      'annonce explicite, sans région vive',
      TargetPlatform.iOS,
      (tester) async {
        final announcements = captureAnnouncements(tester);
        final s = await scenario('analyse en cours');
        await show(tester, s.env.detail(s.entry));

        await finishAnalysis(tester, s, const Untagged());

        expect(find.text(noTagText), findsOneWidget);
        expect(finishedAnnouncements(announcements), [finishedUntaggedText]);
        expect(isAnnounced(tester, find.text(noTagText)), isFalse);
      },
    );

    platformSemanticsTestWidgets(
      'CA28 : Android, de « en attente » à « étiquetée » : région vive sur '
      'les étiquettes, aucune annonce explicite',
      TargetPlatform.android,
      (tester) async {
        final announcements = captureAnnouncements(tester);
        final s = await scenario('analyse en cours');
        await show(tester, s.env.detail(s.entry));

        await finishAnalysis(tester, s, Tagged(fatigueCalmeTravail));

        expect(find.text('fatigue'), findsOneWidget);
        expect(isAnnounced(tester, find.text('fatigue')), isTrue);
        expect(finishedAnnouncements(announcements), isEmpty);
      },
    );

    platformSemanticsTestWidgets(
      'CA28 : Android, de « en attente » à « sans étiquette » : région vive '
      'sur le nouveau statut, aucune annonce explicite',
      TargetPlatform.android,
      (tester) async {
        final announcements = captureAnnouncements(tester);
        final s = await scenario('analyse en cours');
        await show(tester, s.env.detail(s.entry));

        await finishAnalysis(tester, s, const Untagged());

        expect(find.text(noTagText), findsOneWidget);
        expect(isAnnounced(tester, find.text(noTagText)), isTrue);
        expect(finishedAnnouncements(announcements), isEmpty);
      },
    );

    // Android : le libellé de la région vive est le texte de fin d'analyse ; les
    // lignes « Émotions » et « Thèmes » restent lues séparément (non fusionnées).
    platformSemanticsTestWidgets(
      'CA28 : Android, de « en attente » à « étiquetée » : la région vive a '
      'pour libellé « Analyse terminée. Émotions : fatigue, calme. Thèmes : '
      'travail. », et les lignes restent lues séparément',
      TargetPlatform.android,
      (tester) async {
        final s = await scenario('analyse en cours');
        await show(tester, s.env.detail(s.entry));

        await finishAnalysis(tester, s, Tagged(fatigueCalmeTravail));

        final label = liveRegionLabel(tester, find.text('fatigue'));
        expect(
          label,
          isNotNull,
          reason: 'aucune région vive sur les étiquettes',
        );
        expect(label, contains(finishedTaggedText));
        expect(
          find.bySemanticsLabel('Émotions : fatigue, calme'),
          findsOneWidget,
        );
        expect(find.bySemanticsLabel('Thèmes : travail'), findsOneWidget);
      },
    );

    platformSemanticsTestWidgets(
      'CA28 : Android, de « en attente » à « sans étiquette » : la région vive '
      'a pour libellé « Analyse terminée. Aucune étiquette n\'a été proposée '
      'pour cette entrée. »',
      TargetPlatform.android,
      (tester) async {
        final s = await scenario('analyse en cours');
        await show(tester, s.env.detail(s.entry));

        await finishAnalysis(tester, s, const Untagged());

        final label = liveRegionLabel(tester, find.text(noTagText));
        expect(label, isNotNull, reason: 'aucune région vive sur le statut');
        expect(label, contains(finishedUntaggedText));
      },
    );

    // Rien à l'ouverture, même si l'entrée transmise par la liste était « en
    // attente » alors que le journal la donne déjà étiquetée.
    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      platformSemanticsTestWidgets(
        'CA28 : ${platform.name}, ouverture d\'un détail dont l\'entrée transmise '
        'est « en attente » alors que le journal la donne déjà étiquetée : '
        'rien n\'est annoncé',
        platform,
        (tester) async {
          final announcements = captureAnnouncements(tester);
          final env = UiEnv();
          final stale = env.pending(DateTime(2026, 10, 14, 21, 40), bodyText);
          expect(stale.analysisStatus, AnalysisStatus.pending);
          await env.repo.saveAnalysis(stale.id, Tagged(fatigueCalmeTravail));

          await show(tester, env.detail(stale));

          expect(find.text('fatigue'), findsOneWidget);
          expect(finishedAnnouncements(announcements), isEmpty);
          expect(isAnnounced(tester, find.text('fatigue')), isFalse);
        },
      );
    }

    // Revue de sécurité de la PR : rien n'est dit à voix haute quand le détail
    // n'est plus à l'écran (feuille ou écran ouvert par-dessus).
    platformSemanticsTestWidgets(
      'CA28 : iOS, la fin d\'analyse n\'est pas annoncée quand un autre écran '
      'couvre le détail',
      TargetPlatform.iOS,
      (tester) async {
        final announcements = captureAnnouncements(tester);
        final s = await scenario('analyse en cours');
        await show(tester, s.env.detail(s.entry));
        unawaited(
          tester
              .state<NavigatorState>(find.byType(Navigator).last)
              .push(
                MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(body: Text('Par-dessus')),
                ),
              ),
        );
        await settle(tester);
        expect(find.text('Par-dessus'), findsOneWidget);

        await finishAnalysis(tester, s, Tagged(fatigueCalmeTravail));

        expect(finishedAnnouncements(announcements), isEmpty);
      },
    );

    platformSemanticsTestWidgets(
      'CA28 : iOS, la fin d\'analyse n\'est pas annoncée quand l\'app n\'est '
      'pas au premier plan (état inactive : appel entrant, centre de contrôle)',
      TargetPlatform.iOS,
      (tester) async {
        final announcements = captureAnnouncements(tester);
        final s = await scenario('analyse en cours');
        await show(tester, s.env.detail(s.entry));
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        addTearDown(
          () => tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          ),
        );

        await finishAnalysis(tester, s, Tagged(fatigueCalmeTravail));

        expect(finishedAnnouncements(announcements), isEmpty);
      },
    );

    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      platformSemanticsTestWidgets(
        'CA28 : ${platform.name}, l\'ouverture du détail d\'une entrée déjà '
        'étiquetée n\'annonce rien (ni annonce explicite, ni région vive)',
        platform,
        (tester) async {
          final announcements = captureAnnouncements(tester);
          final s = await scenario('étiquetée');

          await show(tester, s.env.detail(s.entry));

          expect(find.text('fatigue'), findsOneWidget);
          expect(finishedAnnouncements(announcements), isEmpty);
          expect(isAnnounced(tester, find.text('fatigue')), isFalse);
        },
      );

      platformSemanticsTestWidgets(
        'CA28 : ${platform.name}, l\'ouverture du détail d\'une entrée déjà '
        '« sans étiquette » n\'annonce rien',
        platform,
        (tester) async {
          final announcements = captureAnnouncements(tester);
          final s = await scenario('sans étiquette');

          await show(tester, s.env.detail(s.entry));

          expect(find.text(noTagText), findsOneWidget);
          expect(finishedAnnouncements(announcements), isEmpty);
          expect(isAnnounced(tester, find.text(noTagText)), isFalse);
        },
      );
    }
  });

  group('texte du système à 200 % : CA29', () {
    testWidgets('CA29 : la liste, avec des puces longues, ne déborde pas et '
        'les puces passent à la ligne', (tester) async {
      usePhoneScreen(tester);
      final env = UiEnv();
      await env.tagged(
        DateTime(2026, 10, 14, 21, 40),
        'Journée calme.',
        longTags,
      );
      final running = env.pending(DateTime(2026, 10, 14, 18), 'Appel du soir.');
      env.queue.setCurrent(running.id);

      await show(tester, env.list(textScale: 2.0));

      expect(tester.takeException(), isNull);
      expectChipsWrapped(tester, longTagLabels);
      expectNoTruncatedText(tester, find.byType(Scaffold), 'liste à 200 %');
      // La liste ne construit que les cartes proches de l'écran : à 200 %, la
      // deuxième carte est plus bas, on y défile.
      await tester.scrollUntilVisible(find.text(analysingText), 200);
      expect(find.text(analysingText), findsOneWidget);
      expect(tester.takeException(), isNull);
      // Test modifié (issue #30) : la vérification porte aussi sur ce qui n'est
      // construit qu'après le défilement.
      expectNoTruncatedText(
        tester,
        find.byType(Scaffold),
        'liste à 200 %, après défilement',
      );
    });

    testWidgets('CA29 : le détail étiqueté, avec des puces longues, ne déborde '
        'pas et les puces passent à la ligne', (tester) async {
      usePhoneScreen(tester);
      final env = UiEnv();
      final entry = await env.tagged(
        DateTime(2026, 10, 14, 21, 40),
        'Journée calme.',
        longTags,
      );

      await show(tester, env.detail(entry, textScale: 2.0));

      expect(tester.takeException(), isNull);
      expect(find.text(analysedMention), findsOneWidget);
      expectChipsWrapped(tester, longTagLabels);
      expectNoTruncatedText(tester, find.byType(Scaffold), 'détail à 200 %');
    });

    for (final name in stateNames) {
      testWidgets('CA29 : détail « $name » à 200 %, sans débordement ni texte '
          'tronqué', (tester) async {
        usePhoneScreen(tester);
        final s = await scenario(name);

        await show(tester, s.env.detail(s.entry, textScale: 2.0));

        expect(tester.takeException(), isNull);
        expect(find.text('Étiquettes'), findsOneWidget);
        expectNoTruncatedText(tester, find.byType(Scaffold), name);
      });
    }
  });

  group('thème sombre : CA30', () {
    // `ink` clair vaut `on-mood`, la couleur du texte sur les fonds d'humeur
    // dans les deux thèmes (spec 008, CA12, CA13) : il n'est plus une couleur
    // « claire seulement ».
    final lightOnly = [
      light.surface,
      light.surfaceRaised,
      light.inkMuted,
      light.tideSoft,
    ];

    /// Une carte de la liste garde les jetons clairs sur son fond `mood-n-soft`,
    /// clair dans les deux thèmes (spec 008, CA12).
    final softCard = {light.inkMuted, light.tideSoft};

    /// `on-hero` vaut blanc dans les deux thèmes, comme `surface-raised` clair :
    /// texte de l'en-tête de l'accueil (spec 009, CA7).
    final heroText = {TidemarkColors.dark.onHero};

    void expectDark(
      WidgetTester tester,
      Set<Color> expected,
      String where, {
      Set<Color> allowed = const {},
    }) {
      final painted = paintedColors(tester, find.byType(Scaffold));
      for (final color in expected) {
        expect(
          painted,
          contains(color),
          reason: '$where : couleur sombre absente',
        );
      }
      for (final color in lightOnly.where((c) => !allowed.contains(c))) {
        expect(
          painted,
          isNot(contains(color)),
          reason: '$where : couleur claire $color',
        );
      }
    }

    testWidgets('CA30 : la liste, avec puces et analyse en cours, utilise les '
        'couleurs sombres de la charte', (tester) async {
      usePhoneScreen(tester);
      useDarkTheme(tester);
      final env = UiEnv();
      await env.tagged(
        DateTime(2026, 10, 14, 21, 40),
        'Journée calme.',
        fatigueCalmeTravail,
      );
      final running = env.pending(DateTime(2026, 10, 14, 18), 'Appel du soir.');
      env.queue.setCurrent(running.id);

      await show(tester, env.app());

      // Fond d'écran et cartes de l'accueil sombres ; la carte d'entrée, sur
      // son fond `mood-n-soft` clair, garde des puces `tide-soft` claires
      // (spec 008, CA12).
      expectDark(
        tester,
        {dark.surface, dark.surfaceRaised},
        'liste',
        allowed: {...softCard, ...heroText},
      );
      expect(chipColor(tester, 'fatigue'), light.tideSoft);
    });

    testWidgets('CA30 : le détail étiqueté utilise les couleurs sombres, puces '
        'en tide-soft sombre', (tester) async {
      usePhoneScreen(tester);
      useDarkTheme(tester);
      final s = await scenario('étiquetée');

      await show(tester, s.env.detail(s.entry));

      expectDark(tester, {dark.tideSoft, dark.inkMuted}, 'détail étiqueté');
      for (final label in ['fatigue', 'calme', 'travail']) {
        expect(chipColor(tester, label), dark.tideSoft, reason: label);
      }
    });

    for (final name in stateNames.where((n) => n != 'étiquetée')) {
      testWidgets('CA30 : détail « $name » en thème sombre', (tester) async {
        usePhoneScreen(tester);
        useDarkTheme(tester);
        final s = await scenario(name);

        await show(tester, s.env.detail(s.entry));

        expect(find.text('Étiquettes'), findsOneWidget);
        expectDark(tester, {dark.inkMuted}, name);
      });
    }
  });
}
