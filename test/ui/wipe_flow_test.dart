// Parcours complets de la suppression totale (spec 005 ; CA17 à CA19, CA22, CA23, CA27,
// CA28, CA33) : Réglages, confirmation, puis liste vide avec le message de fin, sur la
// vraie base chiffrée d'un dossier temporaire, sous `AppHost` et `startApp`.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/distress/distress_detector.dart';
import 'package:tidemark/entries/entry.dart';
import 'package:tidemark/main.dart';
import 'package:tidemark/storage/app_database.dart';
import 'package:tidemark/ui/app_host.dart';

import '../support/fake_share_sheet.dart';
import '../support/ui_harness.dart';
import '../support/wipe_harness.dart';

const doneTitle = 'Toutes tes données ont été supprimées';
const doneBody = 'Ton journal repart de zéro, sur ce téléphone.';
const emptyTitle = 'Ta première entrée apparaîtra ici';
const confirmLabel = 'Tout supprimer définitivement';
const wipeFromScratch = 'Tout supprimer et repartir de zéro';

class Flow {
  Flow() : env = WipeEnv();

  final WipeEnv env;
  final sheet = FakeShareSheet();
  final List<Widget> opened = [];

  Future<Widget> start({bool wiped = false}) async {
    final app = await startApp(
      storage: env.storage(),
      shareSheet: sheet,
      wiped: wiped,
    );
    opened.add(app);
    return app;
  }

  Widget host(Widget initial) => AppHost(
    initial: initial,
    restart: ({required wiped}) => start(wiped: wiped),
  );

  /// Un vrai journal de [count] entrées avec texte et le degré « Haute » ; rend la
  /// clé de la base. Les entrées sont « non analysées » : aucune analyse ne démarre.
  Future<String> seed({int count = 2}) async {
    final journal = await openJournal(
      folder: env.folder,
      keyStore: env.keyStore,
    );
    for (var i = 0; i < count; i++) {
      await journal.entries.addEntry(
        mood: 3,
        text: 'Entrée de l\'ancien journal $i.',
        status: AnalysisStatus.skipped,
      );
    }
    await journal.settings.setLowMoodSensitivity(LowMoodSensitivity.high);
    await (journal.entries as DriftEntryRepository).db.close();
    env.log.clear();
    return env.keyStore.stored!;
  }

  /// Marqueur d'installation, modèle (même partiel) et fichiers temporaires.
  void writeAuxiliaryFiles() {
    File('${env.folder.path}/installed').writeAsStringSync('');
    Directory('${env.folder.path}/models').createSync(recursive: true);
    File('${env.folder.path}/models/modele.gguf.part').writeAsStringSync('xx');
    Directory('${env.cache.path}/tidemark-export').createSync(recursive: true);
    File('${env.cache.path}/tidemark-export/reste.json')
        .writeAsStringSync('{}');
    Directory('${env.cache.path}/share_plus').createSync(recursive: true);
    File('${env.cache.path}/share_plus/copie.json').writeAsStringSync('{}');
  }

  Future<void> closeAll() async {
    for (final app in opened) {
      if (app is TidemarkApp) {
        try {
          // La file d'analyse de l'app rouverte écoute encore la base : sans
          // l'arrêter, la fermeture attend un minuteur du temps simulé. Celle
          // de l'app effacée est déjà arrêtée par la suppression.
          if (identical(app, opened.last)) await app.analysisQueue?.stop();
          await (app.repository as DriftEntryRepository).db.close();
        } catch (_) {}
      }
    }
  }
}

void flowTest(
  String description,
  Future<void> Function(WidgetTester tester, Flow flow) body,
) {
  testWidgets(description, (tester) async {
    useTallScreen(tester);
    final semantics = tester.ensureSemantics();
    final flow = Flow();
    try {
      await body(tester, flow);
    } finally {
      // Comme DbEnv.dispose : laisser les flux de la base se fermer avant de la
      // fermer, sinon la fermeture attend un minuteur du temps simulé.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      // La base rouverte par `AppHost` l'a été dans le temps simulé : sa
      // fermeture (et l'arrêt de sa file) se fait aussi dans le temps simulé,
      // en alternant temps réel (isolat de la base) et temps simulé.
      var closed = false;
      unawaited(flow.closeAll().whenComplete(() => closed = true));
      for (var i = 0; i < 200 && !closed; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pump(const Duration(seconds: 1));
      flow.env.dispose();
      semantics.dispose();
    }
  });
}

bool shown(String text) => find.text(text).evaluate().isNotEmpty;

/// Application affichée en ce moment (celle qui vient d'être rouverte).
TidemarkApp currentApp(WidgetTester tester) =>
    tester.widget<TidemarkApp>(find.byType(TidemarkApp));

Future<List<Entry>> entriesOf(WidgetTester tester) async => (await tester
    .runAsync(() => currentApp(tester).repository.watchEntries().first))!;

void main() {
  flowTest('CA17, CA18 : Réglages, confirmation, puis liste vide avec le '
      'message de fin ; tout l\'ancien journal est parti', (
    tester,
    flow,
  ) async {
    final oldKey = (await tester.runAsync(flow.seed))!;
    flow.writeAuxiliaryFiles();
    final initial = (await tester.runAsync(flow.start))!;
    await tester.pumpWidget(flow.host(initial));
    await pumpUntil(tester, () => shown('Nouvelle entrée'));
    expect(shown(doneTitle), isFalse);

    await tester.tap(find.bySemanticsLabel('Réglages').first);
    await settle(tester);
    await tester.tap(find.text('Tout supprimer'));
    await settle(tester);
    await typeConfirmation(tester, 'supprimer');
    await tester.tap(find.text(confirmLabel));
    await pumpUntil(tester, () => shown(doneTitle), rounds: 600);
    await settleIo(tester);

    // Le message de fin, au-dessus de l'état vide habituel.
    expect(find.text(doneBody), findsOneWidget);
    expect(find.text(emptyTitle), findsOneWidget);
    expect(
      tester.getTopLeft(find.text(doneTitle)).dy,
      lessThan(tester.getTopLeft(find.text(emptyTitle)).dy),
    );
    expect(isAnnounced(tester, doneTitle), isTrue);
    expect(currentApp(tester).wiped, isTrue);
    // L'ancien journal n'existe plus ; le nouveau est vide, avec une clé neuve.
    expect(await entriesOf(tester), isEmpty);
    expect(flow.env.keyStore.stored, isNotNull);
    expect(flow.env.keyStore.stored, isNot(oldKey));
    expect(flow.env.exists('tidemark/models'), isFalse);
    expect(flow.env.exportLeftovers(), isEmpty);
    expect(flow.env.exists('tidemark/wipe-pending'), isFalse);
    expect(flow.env.exists('tidemark/installed'), isTrue);
    expect(
      (await tester.runAsync(
        () => currentApp(tester).settings.watchLowMoodSensitivity().first,
      )),
      LowMoodSensitivity.normal,
    );
    expect(flow.sheet.shared, isEmpty);
  });

  flowTest('CA17 : les étapes ont eu lieu dans l\'ordre, la base fermée '
      'avant l\'effacement de ses fichiers', (tester, flow) async {
    await tester.runAsync(flow.seed);
    final initial = (await tester.runAsync(flow.start))!;
    flow.env.log.clear();
    await tester.pumpWidget(flow.host(initial));
    await pumpUntil(tester, () => shown('Nouvelle entrée'));
    await tester.tap(find.bySemanticsLabel('Réglages').first);
    await settle(tester);
    await tester.tap(find.text('Tout supprimer'));
    await settle(tester);
    await typeConfirmation(tester, 'SUPPRIMER');

    await tester.tap(find.text(confirmLabel));
    await pumpUntil(tester, () => shown(doneTitle), rounds: 600);

    final log = flow.env.log;
    final firstDelete = log.indexOf('deleteFile tidemark/journal.db-wal');
    final key = log.indexOf('deleteAll');
    final newKey = log.indexOf('writeKey');
    expect(log.first, 'createFile tidemark/wipe-pending');
    expect(firstDelete, greaterThan(0));
    expect(log.indexOf('deleteFile tidemark/journal.db'), lessThan(key));
    expect(key, lessThan(log.indexOf('deleteDirectory tidemark/models')));
    expect(
      log.indexOf('deleteFile tidemark/wipe-pending'),
      lessThan(newKey),
      reason: 'la base neuve et sa clé viennent après la fin de la suppression',
    );
  });

  flowTest('CA19 : après la suppression, une nouvelle entrée est la seule '
      'de la liste', (tester, flow) async {
    await tester.runAsync(() => flow.seed(count: 3));
    final initial = (await tester.runAsync(flow.start))!;
    await tester.pumpWidget(flow.host(initial));
    await pumpUntil(tester, () => shown('Nouvelle entrée'));
    await tester.tap(find.bySemanticsLabel('Réglages').first);
    await settle(tester);
    await tester.tap(find.text('Tout supprimer'));
    await settle(tester);
    await typeConfirmation(tester, 'SUPPRIMER');
    await tester.tap(find.text(confirmLabel));
    await pumpUntil(tester, () => shown(doneTitle), rounds: 600);
    await settleIo(tester);

    await openForm(tester);
    await pickMood(tester, 4);
    await tester.tap(find.text('Enregistrer'));
    await settleIo(tester);

    final entries = await entriesOf(tester);
    expect(entries, hasLength(1));
    expect(entries.single.mood, 4);
    expect(find.text(emptyTitle), findsNothing);
    expect(find.textContaining('ancien journal'), findsNothing);
  });

  flowTest('CA22 : app fermée pendant une suppression, le démarrage la '
      'reprend et affiche directement la liste vide avec le message', (
    tester,
    flow,
  ) async {
    final oldKey = (await tester.runAsync(flow.seed))!;
    flow.writeAuxiliaryFiles();
    File('${flow.env.folder.path}/wipe-pending').writeAsStringSync('');
    final initial = (await tester.runAsync(flow.start))!;

    await tester.pumpWidget(flow.host(initial));
    await pumpUntil(tester, () => shown(doneTitle));

    expect(find.text(doneBody), findsOneWidget);
    expect(find.text(emptyTitle), findsOneWidget);
    expect(flow.env.exists('tidemark/wipe-pending'), isFalse);
    expect(flow.env.exists('tidemark/models'), isFalse);
    expect(flow.env.keyStore.stored, isNot(oldKey));
    expect(await entriesOf(tester), isEmpty);
  });

  flowTest('CA23 : reprise en échec au démarrage, puis « Réessayer » finit la '
      'suppression et affiche le message de fin', (tester, flow) async {
    final oldKey = (await tester.runAsync(flow.seed))!;
    flow.writeAuxiliaryFiles();
    File('${flow.env.folder.path}/wipe-pending').writeAsStringSync('');
    flow.env.failAt('deleteAll');
    final initial = (await tester.runAsync(flow.start))!;
    expect(initial, isA<StartupErrorApp>());

    await tester.pumpWidget(flow.host(initial));
    await settle(tester);
    expect(find.text("La suppression n'est pas terminée"), findsOneWidget);
    expect(shown(doneTitle), isFalse);
    expect(flow.env.keyStore.stored, oldKey);

    flow.env.repair();
    await tester.tap(find.text('Réessayer'));
    await pumpUntil(tester, () => shown(doneTitle), rounds: 600);

    expect(find.text(emptyTitle), findsOneWidget);
    expect(flow.env.exists('tidemark/wipe-pending'), isFalse);
    expect(flow.env.keyStore.stored, isNotNull);
    expect(flow.env.keyStore.stored, isNot(oldKey));
    expect(await entriesOf(tester), isEmpty);
  });

  flowTest('CA27, CA28 : clé introuvable, rien n\'est effacé avant la '
      'confirmation, puis « Tout supprimer et repartir de zéro » mène à la '
      'liste vide avec le message de fin', (tester, flow) async {
    final oldKey = (await tester.runAsync(flow.seed))!;
    flow.writeAuxiliaryFiles();
    flow.env.keyStore.stored = null;
    final dbBefore = File('${flow.env.folder.path}/journal.db')
        .readAsBytesSync();
    final initial = (await tester.runAsync(flow.start))!;
    expect(initial, isA<StartupErrorApp>());

    await tester.pumpWidget(flow.host(initial));
    await settle(tester);
    await tester.tap(find.text(wipeFromScratch));
    await settle(tester);
    await settleIo(tester);

    // CA28 : confirmation ouverte, rien n'est encore effacé.
    expect(find.text('Retour'), findsOneWidget);
    expect(
      File('${flow.env.folder.path}/journal.db').readAsBytesSync(),
      dbBefore,
    );
    expect(flow.env.exists('tidemark/models/modele.gguf.part'), isTrue);
    expect(flow.env.log, isNot(contains('deleteAll')));
    expect(flow.env.keyStore.stored, isNull);

    await typeConfirmation(tester, 'Supprimer');
    await tester.tap(find.text(confirmLabel));
    await pumpUntil(tester, () => shown(doneTitle), rounds: 600);
    await settleIo(tester);

    expect(find.text(doneBody), findsOneWidget);
    expect(find.text(emptyTitle), findsOneWidget);
    expect(flow.env.exists('tidemark/models'), isFalse);
    expect(flow.env.keyStore.stored, isNotNull);
    expect(flow.env.keyStore.stored, isNot(oldKey));
    expect(await entriesOf(tester), isEmpty);
    expect(flow.env.exists('tidemark/wipe-pending'), isFalse);
  });
}
