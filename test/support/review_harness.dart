// Outils communs aux tests de la spec 006 (bilan de la semaine) : entrées datées,
// bilans construits à la main, faux avec sondes de concurrence, environnement
// d'écran. Aucun modèle d'IA, aucun réseau, données fictives.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/analysis/mood_analyzer.dart';
import 'package:tidemark/entries/entry.dart';
import 'package:tidemark/model/model_state.dart';
import 'package:tidemark/review/local_week.dart';
import 'package:tidemark/review/review_narrator.dart';
import 'package:tidemark/review/review_writer.dart';
import 'package:tidemark/review/weekly_review.dart';
import 'package:tidemark/review/weekly_review_calculator.dart';
import 'package:tidemark/ui/screens/entry_list_screen.dart';
import 'package:tidemark/ui/screens/weekly_review_screen.dart';

import 'fake_entry_repository.dart';
import 'fake_model_downloader.dart';
import 'fake_mood_analyzer.dart';
import 'fake_review_writer.dart';
import 'fake_settings_repository.dart';
import 'ui_harness.dart';

/// Chemin de la spec, relatif à la racine du dépôt (dossier courant de `flutter test`).
const reviewSpecPath = 'docs/specs/006-bilan-de-la-semaine.md';

String readReviewSpec() => File(reviewSpecPath).readAsStringSync();

/// Horloge des tests d'écran : dimanche 18 octobre 2026, 21:40 (comme la maquette).
/// Semaine en cours : du lundi 12 au dimanche 18 octobre.
final reviewNow = DateTime(2026, 10, 18, 21, 40);

/// Semaine du lundi 12 au dimanche 18 octobre 2026. À appeler dans un test, jamais
/// à l'enregistrement d'un groupe.
LocalWeek get weekOct12 => LocalWeek.containing(DateTime(2026, 10, 14));

const distressText = 'J’ai envie de mourir.';
const neutralText = 'Une journée ordinaire.';

/// Tout caractère de la catégorie Unicode « nombre » (N), plus « % » et « ‰ ».
final numericPattern = RegExp(r'[\p{N}%‰]', unicode: true);

bool hasNumeric(String text) => numericPattern.hasMatch(text);

/// Faits d'exemple, ceux de la maquette.
const defaultFacts = ReviewFacts(
  averageMoodLabel: 'Bien',
  regularity: WeekRegularity.mostDays,
  topTagLabels: ['fatigue', 'travail', 'calme'],
  trend: ReviewTrend.up,
);

/// Bilan construit à la main, sans passer par le calculateur : les tests du
/// narrateur et du rédacteur ne dépendent pas du calcul.
ComputedWeek computedWeek({
  LocalWeek? week,
  ReviewFacts facts = defaultFacts,
  bool sensitive = false,
}) => ComputedWeek(
  week: week ?? weekOct12,
  entryCount: 7,
  averageMoodTenths: 36,
  moodCounts: const [0, 1, 2, 3, 1],
  notedDays: const [1, 2, 4, 6, 7],
  topTags: const [],
  comparison: null,
  isSensitive: sensitive,
  facts: facts,
);

/// Entrée saisie à l'heure murale [wall] dans un fuseau de décalage [offset] : la
/// date enregistrée est en UTC, le décalage est conservé (spec 001).
Entry localEntry(
  int id,
  DateTime wall, {
  Duration offset = Duration.zero,
  int mood = 3,
  String? text,
  AnalysisStatus? status,
  List<Tag> tags = const [],
}) => Entry(
  id: id,
  mood: mood,
  text: text,
  createdAt: DateTime.utc(
    wall.year,
    wall.month,
    wall.day,
    wall.hour,
    wall.minute,
  ).subtract(offset),
  utcOffset: offset,
  analysisStatus:
      status ??
      (text == null ? AnalysisStatus.skipped : AnalysisStatus.pending),
  tags: tags,
);

/// Journal de test pour le calculateur : entrées rangées par jour de la semaine du
/// 12 octobre 2026 (1 = lundi, 7 = dimanche), `weeksBack` semaines plus tôt.
class EntryBook {
  final List<Entry> entries = [];
  final Map<int, List<Tag>> tagsByEntry = {};
  int _nextId = 1;

  /// Ajoute une entrée. Avec [tags], elle est « étiquetée » (sauf si [status] dit
  /// autre chose : les étiquettes restent alors dans la table, pour vérifier que
  /// seules les entrées « étiquetées » comptent).
  Entry add(
    int day,
    int mood, {
    int weeksBack = 0,
    String? text,
    AnalysisStatus? status,
    List<Tag>? tags,
    int hour = 12,
  }) {
    final at = DateTime(2026, 10, 12 + (day - 1) - 7 * weeksBack, hour);
    final effectiveStatus =
        status ?? (tags != null ? AnalysisStatus.tagged : null);
    final entry = localEntry(
      _nextId++,
      at,
      mood: mood,
      text: text ?? (tags != null ? 'Texte fictif' : null),
      status: effectiveStatus,
      tags: effectiveStatus == AnalysisStatus.tagged
          ? (tags ?? const [])
          : const [],
    );
    entries.add(entry);
    if (tags != null) tagsByEntry[entry.id] = tags;
    return entry;
  }

  /// Une entrée par humeur de [moods], les jours donnés (par défaut le lundi, puis
  /// chaque jour suivant en boucle).
  void addMoods(List<int> moods, {int weeksBack = 0, List<int>? days}) {
    for (var i = 0; i < moods.length; i++) {
      add(days?[i] ?? (i % 7) + 1, moods[i], weeksBack: weeksBack);
    }
  }

  void remove(Entry entry) => entries.removeWhere((e) => e.id == entry.id);

  WeeklyReview compute({LocalWeek? week}) =>
      const WeeklyReviewCalculator().compute(
        week: week ?? weekOct12,
        entries: List.of(entries),
        tagsByEntry: Map.of(tagsByEntry),
      );

  ComputedWeek computed({LocalWeek? week}) {
    final review = compute(week: week);
    expect(review, isA<ComputedWeek>(), reason: 'bilan calculé attendu');
    return review as ComputedWeek;
  }
}

// ---------------------------------------------------------------------------
// Faux
// ---------------------------------------------------------------------------

/// Rédacteur dont la mise en mots ne se termine que quand le test le décide
/// ([complete]) ; `cancel()` est compté mais n'interrompt rien, comme un moteur qui
/// finit sa génération malgré l'abandon (le résultat arrive « en retard »).
class ControlledReviewWriter implements ReviewWriter {
  final List<ReviewFacts> received = [];
  int cancelCalls = 0;
  final List<Completer<ReviewDraft>> _pending = [];
  final List<Completer<ReviewDraft>> _all = [];

  int get writeCalls => received.length;

  @override
  Future<ReviewDraft> write(ReviewFacts facts) {
    received.add(facts);
    final completer = Completer<ReviewDraft>();
    _pending.add(completer);
    _all.add(completer);
    return completer.future;
  }

  @override
  Future<void> cancel() async => cancelCalls++;

  /// Termine toutes les mises en mots en attente avec [draft].
  void complete(ReviewDraft draft) {
    for (final pending in _pending) {
      if (!pending.isCompleted) pending.complete(draft);
    }
    _pending.clear();
  }

  /// Termine la [index]-ième mise en mots reçue (à partir de 0) avec [draft], si
  /// elle est encore en attente.
  void completeAt(int index, ReviewDraft draft) {
    final pending = _all[index];
    if (!pending.isCompleted) pending.complete(draft);
  }

  /// Termine toutes les mises en mots en attente avec la sortie [text], conforme
  /// au schéma.
  void completeWithText(String text) => complete(RawReview(jsonText(text)));
}

/// Compte, toutes sources confondues, les générations en cours et les « modèles
/// chargés » : l'analyseur de `prepare` à `release`, le rédacteur le temps d'une
/// mise en mots (ADR-005 : une génération à la fois, un seul modèle en mémoire).
class ConcurrencyProbe {
  int generating = 0;
  int maxGenerating = 0;
  int loaded = 0;
  int maxLoaded = 0;

  void startGeneration() {
    generating++;
    if (generating > maxGenerating) maxGenerating = generating;
  }

  void endGeneration() => generating--;

  void load() {
    loaded++;
    if (loaded > maxLoaded) maxLoaded = loaded;
  }

  void unload() => loaded--;
}

class ProbeAnalyzer extends FakeMoodAnalyzer {
  ProbeAnalyzer(this.probe, {super.delays, super.prepareResult});

  final ConcurrencyProbe probe;
  bool _loaded = false;

  @override
  Future<bool> prepare() async {
    final ok = await super.prepare();
    if (ok && !_loaded) {
      _loaded = true;
      probe.load();
    }
    return ok;
  }

  @override
  Future<AnalysisResult> analyze(String text) async {
    probe.startGeneration();
    try {
      return await super.analyze(text);
    } finally {
      probe.endGeneration();
    }
  }

  @override
  Future<void> release() async {
    if (_loaded) {
      _loaded = false;
      probe.unload();
    }
    await super.release();
  }
}

class ProbeWriter extends FakeReviewWriter {
  ProbeWriter(this.probe, {super.delay});

  final ConcurrencyProbe probe;

  @override
  Future<ReviewDraft> write(ReviewFacts facts) async {
    probe.startGeneration();
    probe.load();
    try {
      return await super.write(facts);
    } finally {
      probe.unload();
      probe.endGeneration();
    }
  }
}

// ---------------------------------------------------------------------------
// Environnement d'écran
// ---------------------------------------------------------------------------

const absentModel = ModelAbsent();
const downloadingModel = ModelDownloading(receivedBytes: 1, totalBytes: 10);

/// Dépôt, téléchargeur, rédacteur et narrateur factices, et les écrans du bilan et
/// de la liste branchés dessus.
class ReviewEnv {
  ReviewEnv({
    ModelState model = readyModel,
    ReviewWriter? writer,
    this.timeout = const Duration(seconds: 30),
    DateTime? now,
  }) : downloader = FakeModelDownloader(model),
       writer = writer ?? FakeReviewWriter(),
       now = now ?? reviewNow {
    repo = FakeEntryRepository(clock: () => this.now);
    narrator = ReviewNarrator(
      writer: this.writer,
      downloader: downloader,
      timeout: timeout,
    );
  }

  final FakeModelDownloader downloader;
  final ReviewWriter writer;
  final Duration timeout;
  DateTime now;
  late final FakeEntryRepository repo;
  late final ReviewNarrator narrator;

  FakeReviewWriter get fakeWriter => writer as FakeReviewWriter;
  ControlledReviewWriter get controlledWriter =>
      writer as ControlledReviewWriter;

  int get writeCalls => switch (writer) {
    FakeReviewWriter(:final writeCalls) => writeCalls,
    ControlledReviewWriter(:final writeCalls) => writeCalls,
    _ => throw StateError('rédacteur sans compteur'),
  };

  Widget screen({double textScale = 1.0}) => testApp(
    WeeklyReviewScreen(repository: repo, narrator: narrator, clock: () => now),
    textScale: textScale,
  );

  Widget list({double textScale = 1.0}) => testApp(
    EntryListScreen(
      repository: repo,
      settings: FakeSettingsRepository(),
      downloader: downloader,
      clock: () => now,
      narrator: narrator,
    ),
    textScale: textScale,
  );

  /// Entrée saisie à l'heure murale [at]. Avec [tags], elle est « étiquetée ».
  Future<Entry> addAt(
    DateTime at,
    int mood, {
    String? text,
    AnalysisStatus? status,
    List<Tag>? tags,
  }) async {
    final seeded = repo.seed(
      mood: mood,
      text: text ?? (tags != null ? 'Texte fictif' : null),
      createdAt: at,
      status: tags == null ? status : AnalysisStatus.pending,
    );
    if (tags != null) await repo.saveAnalysis(seeded.id, Tagged(tags));
    return repo.entries.firstWhere((e) => e.id == seeded.id);
  }

  /// Entrée du jour [day] (1 = lundi 12 octobre, 7 = dimanche 18), `weeksBack`
  /// semaines plus tôt.
  Future<Entry> add(
    int day,
    int mood, {
    int weeksBack = 0,
    String? text,
    AnalysisStatus? status,
    List<Tag>? tags,
  }) => addAt(
    DateTime(2026, 10, 12 + (day - 1) - 7 * weeksBack, 12),
    mood,
    text: text,
    status: status,
    tags: tags,
  );

  /// Semaine de la maquette : 7 entrées d'humeurs 4, 3, 2, 4, 5, 3, 4 sur cinq
  /// jours (lundi, mardi, jeudi, samedi, dimanche), moyenne 3,6, répartition
  /// 0, 1, 2, 3, 1 ; avec [tags], « fatigue » 3, « travail » 3, « calme » 2,
  /// « joie » 1. Aucune entrée sensible.
  Future<void> nominalWeek({bool tags = true, int weeksBack = 0}) async {
    await add(
      1,
      4,
      weeksBack: weeksBack,
      tags: tags ? [emotionTag('fatigue'), themeTag('travail')] : null,
    );
    await add(
      1,
      3,
      weeksBack: weeksBack,
      tags: tags
          ? [emotionTag('fatigue'), emotionTag('calme'), themeTag('travail')]
          : null,
    );
    await add(
      2,
      2,
      weeksBack: weeksBack,
      tags: tags
          ? [emotionTag('fatigue'), emotionTag('calme'), themeTag('travail')]
          : null,
    );
    await add(
      4,
      4,
      weeksBack: weeksBack,
      tags: tags ? [emotionTag('joie')] : null,
    );
    await add(6, 5, weeksBack: weeksBack);
    await add(6, 3, weeksBack: weeksBack);
    await add(7, 4, weeksBack: weeksBack);
  }

  /// Une entrée par humeur de [moods], du lundi au dimanche en boucle.
  Future<void> moods(List<int> moods, {int weeksBack = 0}) async {
    for (var i = 0; i < moods.length; i++) {
      await add((i % 7) + 1, moods[i], weeksBack: weeksBack);
    }
  }

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    // Laisse expirer d'éventuels délais restants (horloge simulée).
    await tester.pump(const Duration(seconds: 40));
  }
}

Tag emotionTag(String label) => Tag(label, TagKind.emotion);
Tag themeTag(String label) => Tag(label, TagKind.theme);

/// `testWidgets` avec la sémantique activée et un écran de téléphone : haut
/// ([tall], par défaut) pour que tout l'écran du bilan soit construit sans
/// défiler, au format iPhone (393 x 852) sinon.
void reviewWidgets(
  String description,
  Future<void> Function(WidgetTester tester) body, {
  bool tall = true,
}) {
  testWidgets(description, (tester) async {
    usePhoneScreen(tester);
    if (tall) tester.view.physicalSize = const Size(393, 2600);
    final handle = tester.ensureSemantics();
    try {
      await body(tester);
    } finally {
      handle.dispose();
    }
  });
}

/// Affiche [env].screen() et laisse les lectures se terminer.
Future<void> showReview(
  WidgetTester tester,
  ReviewEnv env, {
  double textScale = 1.0,
}) async {
  await tester.pumpWidget(env.screen(textScale: textScale));
  await settle(tester);
}

/// Affiche la liste de [env].
Future<void> showList(
  WidgetTester tester,
  ReviewEnv env, {
  double textScale = 1.0,
}) async {
  await tester.pumpWidget(env.list(textScale: textScale));
  await settle(tester);
}

/// Titre de la plage de la liste (spec 009, CA14), qui remplace la carte « Bilan de
/// la semaine » (spec 006, CA1).
const reviewCardTitle = 'Ta plage cette semaine';

/// Touche la plage de la liste : le bilan s'ouvre par-dessus (`EntryListScreen` seul,
/// sans `onOpenWeek`).
Future<void> openReview(WidgetTester tester) async {
  await tester.tap(find.text(reviewCardTitle));
  await settle(tester);
}

/// Touche le retour « Journal » du bilan.
Future<void> goBack(WidgetTester tester) async {
  await tester.tap(find.text('Journal'));
  await settle(tester);
}

Future<void> tapPreviousWeek(WidgetTester tester) async {
  await tester.tap(find.bySemanticsLabel('Semaine précédente'));
  await settle(tester);
}

Future<void> tapNextWeek(WidgetTester tester) async {
  await tester.tap(find.bySemanticsLabel('Semaine suivante'));
  await settle(tester);
}

// Textes de la spec et de la maquette.
const writingText = 'Mise en mots sur ton téléphone…';
const figuresCompleteText = 'Les chiffres ci-dessous sont déjà complets.';
const writtenMention =
    'Mis en mots sur ton téléphone, à partir des chiffres ci-dessous';
const withheldText =
    "Pas de texte pour cette semaine : le bilan s'en tient aux chiffres.";
const noModelText =
    "Pas de texte : le modèle local n'est pas sur ce téléphone. Les chiffres "
    'sont calculés sans lui.';
const insufficientTitle = 'Pas encore de bilan pour cette semaine';
const loadingText = 'Calcul du bilan sur ton téléphone…';
const errorTitle = "Ton bilan n'a pas pu être calculé";
const errorBody =
    "Tes entrées sont toujours sur le téléphone. Rien n'a été effacé. Réessaie.";
const retryLabel = 'Réessayer';
const evolutionTitle = 'Par rapport à la semaine précédente';
const distributionTitle = 'Répartition des humeurs';
const daysTitle = 'Jours notés';
const tagsTitle = 'Étiquettes fréquentes';
const tagsMention = 'Analysé sur ton téléphone';
const noTagsText = 'Aucune étiquette cette semaine.';

String insufficientBody(int count) => switch (count) {
  0 =>
    "Le bilan demande au moins 3 entrées dans la semaine ; celle-ci n'en "
        'compte aucune.',
  _ =>
    'Le bilan demande au moins 3 entrées dans la semaine ; celle-ci en '
        'compte $count.',
};
