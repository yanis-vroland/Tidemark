// Suppression totale et modèle local partagé (spec 005, étape 4 « Modèle local » ;
// spec 004 et spec 006, ADR-005) : avant d'effacer le dossier du modèle, la
// suppression arrête la file d'analyse (modèle libéré), abandonne la mise en mots
// du bilan, et attend que le verrou du modèle soit libre ; elle oublie aussi les
// textes du bilan gardés en mémoire. Tests de non-régression ajoutés après
// l'intégration des PR #26 et #27, en échec avant la correction.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/main.dart';
import 'package:tidemark/model/gated_mood_analyzer.dart';
import 'package:tidemark/model/model_gate.dart';
import 'package:tidemark/review/gated_review_writer.dart';
import 'package:tidemark/review/review_narrator.dart';
import 'package:tidemark/wipe/journal_wiper.dart';

import '../support/fake_entry_repository.dart';
import '../support/fake_model_downloader.dart';
import '../support/fake_mood_analyzer.dart';
import '../support/fake_review_writer.dart';
import '../support/fake_settings_repository.dart';
import '../support/fake_share_sheet.dart';
import '../support/review_harness.dart' show computedWeek;
import '../support/wipe_harness.dart';

const pendingText = 'Une longue journée, à analyser.';
const modelsDeletion = 'deleteDirectory tidemark/models';

/// État observé au moment où la suppression efface le dossier du modèle.
class ModelSnapshot {
  ModelSnapshot({
    required this.analyzerRunning,
    required this.analyzerReleases,
    required this.writerRunning,
    required this.gateHeldByOther,
  });

  final int analyzerRunning;
  final int analyzerReleases;
  final int writerRunning;
  final bool gateHeldByOther;
}

class Rig {
  Rig({this.withQueue = true}) : env = WipeEnv(), gate = ModelGate() {
    fakeAnalyzer = FakeMoodAnalyzer(delays: {pendingText: null});
    repo = FakeEntryRepository();
    if (withQueue) {
      repo.seed(mood: 3, text: pendingText, createdAt: DateTime.now());
    }
  }

  final WipeEnv env;
  final ModelGate gate;
  final bool withQueue;
  late final FakeMoodAnalyzer fakeAnalyzer;
  late final FakeEntryRepository repo;
  final writer = FakeReviewWriter(hang: true);

  /// Vrai tant que le test lui-même détient le verrou (moteur occupé).
  bool testHoldsGate = false;
  ModelSnapshot? snapshot;

  Journal journal() => Journal(
    entries: repo,
    settings: FakeSettingsRepository(),
    downloader: FakeModelDownloader(readyModelForWipe),
    analyzer: withQueue ? GatedMoodAnalyzer(fakeAnalyzer, gate) : null,
    reviewWriter: GatedReviewWriter(writer, gate),
    gate: gate,
    close: () async {},
  );

  Future<TidemarkApp> start() async {
    env.populate();
    env.files.onCall = (call) {
      if (call == modelsDeletion) {
        snapshot = ModelSnapshot(
          analyzerRunning: fakeAnalyzer.running,
          analyzerReleases: fakeAnalyzer.releaseCalls,
          writerRunning: writer.running,
          gateHeldByOther: testHoldsGate,
        );
      }
    };
    final app = await startApp(
      open: () async => journal(),
      storage: env.storage(),
      shareSheet: FakeShareSheet(),
    );
    return app as TidemarkApp;
  }

  JournalWiper wiperOf(TidemarkApp app) => app.data!.wiper;

  void dispose() => env.dispose();
}

/// Modèle prêt, dans le dossier du modèle de la suppression.
const readyModelForWipe = readyModel;

/// Laisse tourner les flux et les minuteurs réels.
Future<void> settleReal([int rounds = 10]) async {
  for (var i = 0; i < rounds; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  test('la suppression arrête la file d\'analyse et libère le modèle avant '
      'd\'effacer son dossier', () async {
    final rig = Rig();
    addTearDown(rig.dispose);
    final app = await rig.start();
    // La file a chargé le modèle et analyse l'entrée, sans fin.
    for (var i = 0; i < 100 && rig.fakeAnalyzer.running == 0; i++) {
      await settleReal(1);
    }
    expect(rig.fakeAnalyzer.running, 1);

    await rig.wiperOf(app).wipe();

    final snapshot = rig.snapshot!;
    expect(snapshot.analyzerRunning, 0);
    expect(snapshot.analyzerReleases, greaterThan(0));
    expect(rig.env.exists('tidemark/models'), isFalse);
  });

  test('la suppression abandonne la mise en mots du bilan en cours avant '
      'd\'effacer le dossier du modèle', () async {
    final rig = Rig(withQueue: false);
    addTearDown(rig.dispose);
    final app = await rig.start();
    final narration = app.reviewNarrator!.narrate(computedWeek());
    for (var i = 0; i < 100 && rig.writer.running == 0; i++) {
      await settleReal(1);
    }
    expect(rig.writer.running, 1);

    await rig.wiperOf(app).wipe();

    expect(rig.snapshot!.writerRunning, 0);
    expect(rig.writer.cancelCalls, greaterThan(0));
    // La mise en mots abandonnée rend la main, sans texte.
    expect(
      await narration.timeout(const Duration(seconds: 2)),
      isNot(isA<NarrationText>()),
    );
  });

  test('la suppression attend que le verrou du modèle soit libre avant '
      'd\'effacer son dossier', () async {
    final rig = Rig(withQueue: false);
    addTearDown(rig.dispose);
    final app = await rig.start();
    // Un moteur garde le modèle ouvert.
    final release = (await rig.gate.acquire())!;
    rig.testHoldsGate = true;

    final wiping = rig.wiperOf(app).wipe();
    await settleReal(20);

    expect(rig.env.log, isNot(contains(modelsDeletion)));
    expect(rig.env.exists('tidemark/models'), isTrue);

    rig.testHoldsGate = false;
    release();
    await wiping.timeout(const Duration(seconds: 5));

    expect(rig.snapshot!.gateHeldByOther, isFalse);
    expect(rig.env.exists('tidemark/models'), isFalse);
  });

  test('après la suppression, plus aucun moteur ne peut reprendre le modèle '
      'de l\'ancien journal', () async {
    final rig = Rig(withQueue: false);
    addTearDown(rig.dispose);
    final app = await rig.start();

    await rig.wiperOf(app).wipe();

    // Le verrou reste pris par la suppression : une mise en mots de l'ancien
    // journal ne charge plus rien.
    expect(rig.gate.isHeld, isTrue);
  });

  test('la suppression oublie les textes du bilan gardés en mémoire', () async {
    final rig = Rig(withQueue: false);
    addTearDown(rig.dispose);
    rig.writer.hang = false;
    final app = await rig.start();
    final narrator = app.reviewNarrator!;
    final week = computedWeek();
    expect(await narrator.narrate(week), isA<NarrationText>());
    expect(narrator.immediate(week), isA<NarrationText>());

    await rig.wiperOf(app).wipe();

    expect(narrator.immediate(week), isNot(isA<NarrationText>()));
  });

  test('ReviewNarrator.forget : abandonne la mise en mots et oublie les '
      'textes gardés', () async {
    final writer = FakeReviewWriter();
    final narrator = ReviewNarrator(
      writer: writer,
      downloader: FakeModelDownloader(readyModel),
    );
    final week = computedWeek();
    await narrator.narrate(week);
    expect(narrator.immediate(week), isA<NarrationText>());

    await narrator.forget();

    expect(narrator.immediate(week), isNot(isA<NarrationText>()));
    expect(writer.cancelCalls, greaterThan(0));
  });

  test('le modèle de l\'ancien journal n\'est pas effacé tant que la base n\'a '
      'pas été effacée (ordre inchangé)', () async {
    final rig = Rig(withQueue: false);
    addTearDown(rig.dispose);
    final app = await rig.start();

    await rig.wiperOf(app).wipe();

    final log = rig.env.log;
    expect(
      log.indexOf('deleteFile tidemark/journal.db'),
      lessThan(log.indexOf(modelsDeletion)),
    );
    expect(File('${rig.env.folder.path}/installed').existsSync(), isTrue);
  });
}
