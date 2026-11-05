// Sujets et garde-fou (spec 010, CA4, CA6, cas limites) : `saveEntryWithGuard` transmet
// les sujets au dépôt, et seulement à lui ; le détecteur de détresse et le modèle
// n'en reçoivent aucun. Sur des faux : aucune base, aucun écran, aucun vrai modèle.
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/analysis/analysis_queue.dart';
import 'package:tidemark/analysis/mood_analyzer.dart';
import 'package:tidemark/distress/distress_detector.dart';
import 'package:tidemark/distress/guarded_save.dart';
import 'package:tidemark/entries/entry.dart';
import 'package:tidemark/entries/topic.dart';

import '../support/analysis_harness.dart' show until;
import '../support/fake_entry_repository.dart';
import '../support/fake_model_downloader.dart';
import '../support/fake_mood_analyzer.dart';
import '../support/fake_settings_repository.dart';

final t0 = DateTime.utc(2026, 10, 14, 20);

/// Détecteur qui garde tout ce qu'il reçoit.
class RecordingDetector extends DistressDetector {
  RecordingDetector();

  final List<String> texts = [];
  final List<List<Entry>> series = [];

  @override
  bool detectInText(String text) {
    texts.add(text);
    return super.detectInText(text);
  }

  @override
  bool detectLowMoodSeries(List<Entry> latest, LowMoodSensitivity sensitivity) {
    series.add(latest);
    return super.detectLowMoodSeries(latest, sensitivity);
  }
}

void main() {
  late FakeEntryRepository repo;
  late FakeSettingsRepository settings;
  late RecordingDetector detector;

  setUp(() {
    repo = FakeEntryRepository(clock: () => t0);
    settings = FakeSettingsRepository();
    detector = RecordingDetector();
  });

  Future<SaveOutcome> save(int mood, {String? text, List<Topic>? topics}) =>
      topics == null
      ? saveEntryWithGuard(
          repository: repo,
          settings: settings,
          mood: mood,
          text: text,
          detector: detector,
          clock: () => t0,
        )
      : saveEntryWithGuard(
          repository: repo,
          settings: settings,
          mood: mood,
          text: text,
          topics: topics,
          detector: detector,
          clock: () => t0,
        );

  group('transmission des sujets au dépôt (CA4)', () {
    test('CA4 : les sujets choisis sont transmis à addEntry et enregistrés '
        'avec l\'entrée, dans l\'ordre de la liste', () async {
      final outcome = await save(
        4,
        text: 'Belle journée.',
        topics: [Topic.nature, Topic.amis],
      );

      expect(repo.addCalls.single.topics, [Topic.nature, Topic.amis]);
      expect(outcome.entry.topics, [Topic.amis, Topic.nature]);
      expect(repo.entries.single.topics, [Topic.amis, Topic.nature]);
      expect(outcome.showHelp, isFalse);
    });

    test('CA4 : sans sujet, aucun n\'est transmis', () async {
      final outcome = await save(4, text: 'Belle journée.');

      expect(repo.addCalls.single.topics, isEmpty);
      expect(outcome.entry.topics, isEmpty);
    });

    test('CA4 : des sujets sans texte : entrée enregistrée « non analysée » '
        '(RM24), avec ses sujets', () async {
      final outcome = await save(3, topics: [Topic.sommeil]);

      expect(outcome.entry.text, isNull);
      expect(outcome.entry.analysisStatus, AnalysisStatus.skipped);
      expect(outcome.entry.topics, [Topic.sommeil]);
    });

    test(
      'CA4 : des sujets avec texte : le statut reste « en attente »',
      () async {
        final outcome = await save(3, text: 'Un texte.', topics: Topic.values);

        expect(outcome.entry.analysisStatus, AnalysisStatus.pending);
        expect(outcome.entry.topics, Topic.values);
      },
    );
  });

  group('le détecteur de détresse ne reçoit que le texte (CA6)', () {
    test(
      'CA6 : il reçoit le texte tel quel, sans les libellés des sujets',
      () async {
        await save(
          4,
          text: 'Belle journée.',
          topics: [Topic.sommeil, Topic.travail, Topic.nature],
        );

        expect(detector.texts, ['Belle journée.']);
      },
    );

    test('CA6 : l\'entrée candidate de la série d\'humeurs basses n\'a aucun '
        'sujet', () async {
      await save(1, text: 'Triste.', topics: [Topic.travail, Topic.famille]);

      expect(detector.series, hasLength(1));
      final candidate = detector.series.single.first;
      expect(candidate.mood, 1);
      expect(candidate.topics, isEmpty);
    });

    test(
      'CA6 : des sujets seuls ne déclenchent jamais l\'écran d\'aide',
      () async {
        final outcome = await save(
          3,
          text: 'Rien à dire.',
          topics: Topic.values,
        );

        expect(outcome.showHelp, isFalse);
        expect(outcome.entry.analysisStatus, AnalysisStatus.pending);
      },
    );

    test('CA6 : un texte en détresse ouvre l\'écran d\'aide, quels que soient '
        'les sujets', () async {
      final withTopics = await save(
        3,
        text: 'J’ai envie de mourir.',
        topics: [Topic.amis],
      );
      final without = await save(3, text: 'J’ai envie de mourir.');

      expect(withTopics.showHelp, isTrue);
      expect(without.showHelp, isTrue);
    });

    test('CA6 : une série d\'humeurs basses ouvre l\'écran d\'aide, avec ou '
        'sans sujets', () async {
      repo.seed(mood: 1, createdAt: DateTime.utc(2026, 10, 8, 20));
      repo.seed(mood: 1, createdAt: DateTime.utc(2026, 10, 12, 20));

      final outcome = await save(1, topics: [Topic.sport]);

      expect(outcome.showHelp, isTrue);
    });
  });

  group('sujets et détresse (cas limite)', () {
    test('une entrée en détresse garde ses sujets, enregistrés avec elle, '
        'et reste « non analysée »', () async {
      final outcome = await save(
        2,
        text: 'envie de mourir',
        topics: [Topic.travail, Topic.sommeil],
      );

      expect(outcome.showHelp, isTrue);
      expect(outcome.entry.analysisStatus, AnalysisStatus.skipped);
      expect(repo.entries.single.topics, [Topic.sommeil, Topic.travail]);
    });

    test('si l\'enregistrement échoue, l\'erreur remonte et rien n\'est '
        'enregistré, sujets compris', () async {
      repo.beforeAdd = () async => throw StateError('stockage plein');

      await expectLater(
        save(3, text: 'Texte.', topics: [Topic.amis]),
        throwsStateError,
      );

      expect(repo.entries, isEmpty);
    });
  });

  group('le modèle ne reçoit que le texte (CA6, RM36)', () {
    test('CA6 : l\'analyse d\'une entrée avec sujets ne transmet que son '
        'texte', () async {
      final analyzer = FakeMoodAnalyzer(
        fallback: const Tagged([Tag('calme', TagKind.emotion)]),
      );
      final queue = AnalysisQueue(
        repository: repo,
        analyzer: analyzer,
        downloader: FakeModelDownloader(readyModel),
        timeout: const Duration(seconds: 30),
      );
      addTearDown(queue.stop);
      repo.seed(
        mood: 4,
        text: 'Balade calme.',
        createdAt: DateTime.utc(2026, 10, 14, 8),
        topics: [Topic.nature, Topic.sport],
      );

      queue.start();
      await until(() => analyzer.received.isNotEmpty);
      await queue.whenIdle.timeout(const Duration(seconds: 5));

      expect(analyzer.received, ['Balade calme.']);
      final analysed = repo.entries.single;
      expect(analysed.analysisStatus, AnalysisStatus.tagged);
      expect(analysed.topics, [Topic.sport, Topic.nature]);
    });
  });
}
