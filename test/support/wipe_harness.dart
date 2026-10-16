// Outils communs aux tests de la spec 005 (export et suppression totale) : dossiers
// temporaires réels, trousseau et accès aux fichiers qui enregistrent leurs appels
// dans un même journal, écrans montés sur ces faux. Aucun modèle d'IA, aucun réseau.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/distress/distress_detector.dart';
import 'package:tidemark/export/journal_export.dart';
import 'package:tidemark/storage/app_storage.dart';
import 'package:tidemark/storage/database_key.dart';
import 'package:tidemark/ui/screens/settings_screen.dart';
import 'package:tidemark/ui/theme/tidemark_colors.dart';
import 'package:tidemark/ui/widgets/my_data_section.dart';
import 'package:tidemark/wipe/journal_wiper.dart';

import 'fake_entry_repository.dart';
import 'fake_model_downloader.dart';
import 'fake_settings_repository.dart';
import 'fake_share_sheet.dart';
import 'ui_harness.dart';

/// Trousseau en mémoire qui range ses appels dans le [log] commun.
class LoggingKeyStore implements KeyStore {
  LoggingKeyStore(this.log, {this.stored});

  final List<String> log;
  String? stored;

  /// Nombre d'écritures de clé (création d'une clé).
  int writes = 0;

  /// Si non nul, [deleteAll] lève cette erreur, sans rien effacer.
  Object? deleteAllError;

  @override
  Future<String?> read() async => stored;

  @override
  Future<void> write(String key) async {
    writes++;
    log.add('writeKey');
    stored = key;
  }

  @override
  Future<void> deleteAll() async {
    log.add('deleteAll');
    if (deleteAllError != null) throw deleteAllError!;
    stored = null;
  }
}

/// [WipeFiles] qui range ses appels dans le [log] commun (chemins relatifs à
/// [root] : `deleteFile tidemark/journal.db`), délègue à [IoWipeFiles], et lève une
/// erreur sur les appels de [failOn] (même forme : `deleteFile tidemark/journal.db`).
class RecordingWipeFiles implements WipeFiles {
  RecordingWipeFiles(this.root, this.log);

  final Directory root;
  final List<String> log;
  final Set<String> failOn = {};
  static const _io = IoWipeFiles();

  String _relative(String path) => path.substring(root.path.length + 1);

  void _record(String operation, String path) {
    final call = '$operation ${_relative(path)}';
    log.add(call);
    if (failOn.contains(call)) {
      throw FileSystemException('échec simulé', path);
    }
  }

  @override
  Future<void> createFile(File file) async {
    _record('createFile', file.path);
    await _io.createFile(file);
  }

  @override
  Future<void> deleteFile(File file) async {
    _record('deleteFile', file.path);
    await _io.deleteFile(file);
  }

  @override
  Future<void> deleteDirectory(Directory directory) async {
    _record('deleteDirectory', directory.path);
    await _io.deleteDirectory(directory);
  }
}

/// Étapes de la suppression totale (spec 005, « Suppression totale »), dans
/// l'ordre. Dans un même groupe, l'ordre n'est pas imposé.
const wipeStepGroups = <List<String>>[
  ['createFile tidemark/wipe-pending'],
  ['closeJournal'],
  [
    'deleteFile tidemark/journal.db-wal',
    'deleteFile tidemark/journal.db-shm',
    'deleteFile tidemark/journal.db-journal',
  ],
  ['deleteFile tidemark/journal.db'],
  ['deleteAll'],
  ['deleteDirectory tidemark/models'],
  ['deleteDirectory cache/tidemark-export', 'deleteDirectory cache/share_plus'],
  ['deleteFile tidemark/wipe-pending'],
];

/// Opérations qui peuvent échouer pendant la suppression : une par étape, chaque
/// fichier de la base comptant pour une étape.
final wipeFailurePoints = [
  for (final group in wipeStepGroups.skip(1)) ...group,
];

/// Le [log] contient exactement les groupes d'étapes [groups], dans l'ordre.
void expectWipeSteps(List<String> log, List<List<String>> groups) {
  var index = 0;
  for (final group in groups) {
    final end = index + group.length;
    expect(
      log.length >= end,
      isTrue,
      reason: 'journal trop court : $log (attendu $group à partir de $index)',
    );
    expect(
      log.sublist(index, end).toList()..sort(),
      ([...group]..sort()),
      reason: 'étapes $index à $end du journal $log',
    );
    index = end;
  }
  expect(log.length, index, reason: 'étapes en trop dans $log');
}

/// Le [log] s'arrête sur [failing] : toutes les étapes avant son groupe ont eu lieu,
/// et aucune étape des groupes suivants.
void expectWipeStoppedAt(List<String> log, String failing) {
  final g = wipeStepGroups.indexWhere((group) => group.contains(failing));
  expect(g >= 0, isTrue, reason: 'étape inconnue : $failing');
  expect(log.last, failing, reason: 'journal : $log');
  final allowed = wipeStepGroups.take(g + 1).expand((x) => x).toSet();
  expect(
    log.every(allowed.contains),
    isTrue,
    reason: 'étape après $failing dans $log',
  );
  for (final group in wipeStepGroups.take(g)) {
    for (final step in group) {
      expect(log, contains(step), reason: 'étape manquante avant $failing');
    }
  }
}

/// Dossier temporaire réel qui contient le dossier de l'app (`tidemark/`) et son
/// cache (`cache/`), avec un [JournalWiper] branché sur des faux.
class WipeEnv {
  WipeEnv() : root = Directory.systemTemp.createTempSync('tidemark_wipe_') {
    folder = Directory('${root.path}/tidemark');
    cache = Directory('${root.path}/cache');
    keyStore = LoggingKeyStore(log);
    files = RecordingWipeFiles(root, log);
  }

  final Directory root;
  late final Directory folder;
  late final Directory cache;
  final List<String> log = [];
  late final LoggingKeyStore keyStore;
  late final RecordingWipeFiles files;

  /// Appelé par `closeJournal` après son enregistrement dans le [log] : peut lever
  /// une erreur ou attendre.
  Future<void> Function()? closeBody;

  /// Nombre d'appels à `closeJournal`.
  int get closeCalls => log.where((e) => e == 'closeJournal').length;

  /// Nombre d'appels à [onWiped] : suppressions terminées avec succès, vues de
  /// l'écran de confirmation.
  int wipedCalls = 0;

  /// À passer à `WipeConfirmationScreen.onWiped`.
  Future<void> onWiped() async => wipedCalls++;

  JournalWiper wiper() => JournalWiper(
    folder: folder,
    cacheFolder: cache,
    keyStore: keyStore,
    files: files,
    closeJournal: () async {
      log.add('closeJournal');
      await closeBody?.call();
    },
  );

  AppStorage storage() => AppStorage(
    folder: folder,
    cacheFolder: cache,
    keyStore: keyStore,
    files: files,
  );

  File file(String relative) => File('${root.path}/$relative');

  bool exists(String relative) =>
      FileSystemEntity.typeSync('${root.path}/$relative') !=
      FileSystemEntityType.notFound;

  /// Une installation avec une base et tout ce que la suppression doit effacer.
  void populate({String key = 'ancienne-cle'}) {
    folder.createSync(recursive: true);
    for (final name in const [
      'journal.db',
      'journal.db-wal',
      'journal.db-shm',
      'journal.db-journal',
      'installed',
    ]) {
      File('${folder.path}/$name').writeAsStringSync('contenu $name');
    }
    Directory('${folder.path}/models/partiel').createSync(recursive: true);
    File('${folder.path}/models/modele.gguf.part').writeAsStringSync('xxxx');
    File('${folder.path}/models/partiel/morceau').writeAsStringSync('yy');
    Directory('${cache.path}/tidemark-export').createSync(recursive: true);
    File('${cache.path}/tidemark-export/reste.json').writeAsStringSync('{}');
    Directory('${cache.path}/share_plus').createSync(recursive: true);
    File('${cache.path}/share_plus/copie.json').writeAsStringSync('{}');
    keyStore.stored = key;
    log.clear();
  }

  /// Fait échouer l'opération [step] (une valeur de [wipeFailurePoints]).
  void failAt(String step) {
    if (step == 'closeJournal') {
      closeBody = () async => throw StateError('fermeture impossible');
    } else if (step == 'deleteAll') {
      keyStore.deleteAllError = StateError('trousseau inaccessible');
    } else {
      files.failOn.add(step);
    }
  }

  /// Retire toute panne injectée.
  void repair() {
    closeBody = null;
    keyStore.deleteAllError = null;
    files.failOn.clear();
  }

  /// Fichiers (et dossiers) sous [directory], chemins relatifs ; vide si le dossier
  /// n'existe pas.
  List<String> contents(Directory directory) => directory.existsSync()
      ? directory
            .listSync(recursive: true)
            .map((e) => e.path.substring(directory.path.length + 1))
            .toList()
      : [];

  /// Fichiers temporaires d'export restants : `tidemark-export/` et `share_plus/`.
  List<String> exportLeftovers() => [
    for (final dir in exportTemporaryFolders(cache))
      for (final path in contents(dir)) '${dir.path.split('/').last}/$path',
  ];

  void dispose() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  }
}

/// Réglages dont la lecture par l'export peut être retenue.
class GatedSettings extends FakeSettingsRepository {
  GatedSettings([super.value]);

  Completer<void>? readGate;

  /// Si non nul, [watchLowMoodSensitivity] n'émet qu'une fois ce `Completer`
  /// complété : la lecture du degré par l'écran Réglages est « en cours » (CA2).
  Completer<void>? watchGate;

  @override
  Stream<LowMoodSensitivity> watchLowMoodSensitivity() async* {
    await watchGate?.future;
    yield* super.watchLowMoodSensitivity();
  }

  @override
  Future<LowMoodSensitivity> readLowMoodSensitivity() async {
    await readGate?.future;
    return super.readLowMoodSensitivity();
  }
}

/// Réglages avec section « Mes données » : export et suppression sur des faux.
class DataEnv {
  DataEnv() : wipe = WipeEnv();

  final WipeEnv wipe;
  final entries = FakeEntryRepository();
  final settings = GatedSettings(LowMoodSensitivity.high);
  final sheet = FakeShareSheet();

  /// Début de l'export : 14 octobre 2026, 21:52:07 (heure locale).
  DateTime Function() clock = () => DateTime(2026, 10, 14, 21, 52, 7);

  JournalExport get export => JournalExport(
    entries: entries,
    settings: settings,
    shareSheet: sheet,
    cacheFolder: wipe.cache,
    clock: () => clock(),
  );

  DataActions get actions => DataActions(export: export, wiper: wipe.wiper());

  /// Une entrée dans le journal factice, pour que l'export soit possible.
  void seedEntry() => entries.seed(
    mood: 2,
    text: 'Encore une nuit trop courte.',
    createdAt: DateTime(2026, 10, 13, 22, 5),
  );

  SettingsScreen settingsWidget() => SettingsScreen(
    settings: settings,
    downloader: FakeModelDownloader(readyModel),
    data: actions,
  );

  /// Les Réglages comme écran racine.
  Widget settingsScreen({double textScale = 1.0}) =>
      testApp(settingsWidget(), textScale: textScale);

  /// Les Réglages ouverts depuis un accueil : un geste de retour peut les fermer.
  Widget settingsOnTop({double textScale = 1.0}) =>
      homeWithPush(settingsWidget(), textScale: textScale);

  void dispose() => wipe.dispose();
}

/// `testWidgets` avec les Réglages, un journal d'une entrée (sauf [seed] faux), la
/// sémantique, et des fichiers temporaires effacés en fin de test. Écran très haut
/// par défaut ([tall]), de téléphone sinon.
void dataTest(
  String description,
  Future<void> Function(WidgetTester tester, DataEnv env) body, {
  bool seed = true,
  bool tall = true,
}) {
  testWidgets(description, (tester) async {
    if (tall) {
      useTallScreen(tester);
    } else {
      usePhoneScreen(tester);
    }
    final semantics = tester.ensureSemantics();
    final env = DataEnv();
    if (seed) env.seedEntry();
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    try {
      await body(tester, env);
    } finally {
      await tester.pumpWidget(const SizedBox());
      env.dispose();
      semantics.dispose();
    }
  });
}

/// Écran de téléphone très haut : toute la page est visible sans défiler.
void useTallScreen(WidgetTester tester, {double height = 3200}) {
  tester.view.physicalSize = Size(393, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Couleurs résolues (état normal) du bouton qui porte [label] : texte, bordure et
/// fond. Le bouton est un `OutlinedButton` stylé comme `_DangerButton`
/// (entry_detail_screen.dart).
({Color? foreground, Color? border, Color? background}) buttonColors(
  WidgetTester tester,
  String label,
) {
  final button = tester.widget<OutlinedButton>(
    find.ancestor(of: find.text(label), matching: find.byType(OutlinedButton)),
  );
  final style = button.style;
  return (
    foreground: style?.foregroundColor?.resolve({}),
    border: style?.side?.resolve({})?.color,
    background: style?.backgroundColor?.resolve({}),
  );
}

/// Le bouton [label] est destructeur : texte et bordure en `danger`, sur
/// `surface-raised`, jamais un fond `danger` plein (CA1, CA26, CA35).
void expectDangerButton(
  WidgetTester tester,
  String label,
  TidemarkColors colors,
) {
  final found = buttonColors(tester, label);
  expect(found.foreground, colors.danger, reason: 'texte de « $label »');
  expect(found.border, colors.danger, reason: 'bordure de « $label »');
  expect(found.background, colors.surfaceRaised, reason: 'fond de « $label »');
}

/// Un écran d'accueil qui ouvre [screen] par « Ouvrir » : l'écran n'est pas la racine,
/// un geste de retour peut donc le fermer.
Widget homeWithPush(Widget screen, {double textScale = 1.0}) => testApp(
  Builder(
    builder: (context) => Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () =>
              Navigator.of(context)
                  .push(MaterialPageRoute<void>(builder: (_) => screen)),
          child: const Text('Ouvrir'),
        ),
      ),
    ),
  ),
  textScale: textScale,
);

/// Fait défiler la page jusqu'à [target], qui doit alors pouvoir recevoir un toucher
/// (CA34 : tous les boutons restent atteignables à 200 %).
Future<void> scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  // `scrollUntilVisible` finit par un `ensureVisible` sans image : quand la cible
  // est déjà construite (écran non paresseux), la mise en page doit suivre avant
  // le test de toucher.
  await tester.pump();
  expect(target.hitTestable(), findsOneWidget, reason: '$target atteignable');
}

/// Laisse tourner les vrais accès aux fichiers (hors temps simulé) et le temps simulé,
/// jusqu'à ce que [condition] soit vraie.
Future<void> pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  int rounds = 300,
}) async {
  for (var i = 0; i < rounds && !condition(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(condition(), isTrue, reason: 'condition jamais remplie');
}

/// Laisse finir tout ce qui est en cours (accès aux fichiers, animations), pour
/// vérifier qu'un état ne change plus.
Future<void> settleIo(WidgetTester tester, {int rounds = 20}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Entrée de texte « SUPPRIMER » dans le champ de la confirmation.
Future<void> typeConfirmation(WidgetTester tester, String value) async {
  await tester.enterText(find.byType(TextField), value);
  await tester.pump();
}

/// Libellés des nœuds de sémantique annoncés dès leur apparition (`liveRegion`).
List<String> liveRegionLabels(WidgetTester tester) {
  final labels = <String>[];
  void visit(SemanticsNode node) {
    if (node.flagsCollection.isLiveRegion) labels.add(node.label);
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(
    tester.binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!,
  );
  return labels;
}

/// Un texte est annoncé dès son apparition : un nœud `liveRegion` le contient.
bool isAnnounced(WidgetTester tester, String text) =>
    liveRegionLabels(tester).any((label) => label.contains(text));
