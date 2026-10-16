import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'analysis/analysis_queue.dart';
import 'analysis/llama_mood_analyzer.dart';
import 'analysis/mood_analyzer.dart';
import 'distress/startup_screening.dart';
import 'entries/entry_repository.dart';
import 'model/gated_mood_analyzer.dart';
import 'model/model_downloader.dart';
import 'model/model_gate.dart';
import 'model/model_source.dart';
import 'model/model_transport.dart';
import 'export/journal_export.dart';
import 'export/share_sheet.dart';
import 'review/gated_review_writer.dart';
import 'review/llama_review_writer.dart';
import 'review/review_narrator.dart';
import 'review/review_writer.dart';
import 'settings/settings_repository.dart';
import 'storage/app_database.dart';
import 'storage/app_storage.dart';
import 'storage/database_key.dart';
import 'ui/analysis_scope.dart';
import 'ui/app_host.dart';
import 'ui/phone_dialer.dart';
import 'ui/screens/entry_list_screen.dart';
import 'ui/theme/tidemark_colors.dart';
import 'ui/theme/tidemark_theme.dart';
import 'ui/theme/tidemark_tokens.dart';
import 'ui/screens/wipe_confirmation_screen.dart';
import 'ui/theme/tidemark_typography.dart';
import 'ui/widgets/action_buttons.dart';
import 'ui/widgets/my_data_section.dart';
import 'wipe/install_marker.dart';
import 'wipe/journal_wiper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = await AppStorage.system();
  // Un flux neuf à chaque ouverture : il n'accepte qu'un abonné, la file
  // d'analyse de l'app précédente.
  runApp(
    AppHost(
      initial: await startApp(
        storage: storage,
        lifecycle: appLifecycleStates(),
      ),
      restart: ({required wiped}) => startApp(
        storage: storage,
        lifecycle: appLifecycleStates(),
        wiped: wiped,
      ),
    ),
  );
}

/// Cycle de vie de l'app, observé par la file d'analyse (spec 004, CA32, CA33).
/// L'écoute commence avec le premier abonné et s'arrête avec lui.
Stream<AppLifecycleState> appLifecycleStates() {
  AppLifecycleListener? listener;
  late final StreamController<AppLifecycleState> controller;
  controller = StreamController<AppLifecycleState>(
    onListen: () =>
        listener = AppLifecycleListener(onStateChange: controller.add),
    onCancel: () => listener?.dispose(),
  );
  return controller.stream;
}

/// Journal ouvert : ses entrées et les réglages, sur la même base chiffrée.
class Journal {
  const Journal({
    required this.entries,
    required this.settings,
    required this.downloader,
    this.analyzer,
    this.close,
    this.reviewWriter,
  });

  final EntryRepository entries;
  final SettingsRepository settings;

  /// Analyseur du modèle local (spec 004) ; `null` : aucune analyse.
  final MoodAnalyzer? analyzer;

  /// Rédacteur du bilan (spec 006) ; `null` : bilan sans texte.
  final ReviewWriter? reviewWriter;

  /// Modèle local, dans le dossier `models/` à côté de la base (spec 003).
  final ModelDownloader downloader;

  /// Ferme la base (suppression totale, spec 005) ; `null` : rien à fermer.
  final Future<void> Function()? close;
}

/// Application de démarrage : le journal ouvert, ou l'écran d'erreur qui
/// correspond à la cause (CA35). [open] est injectable pour les tests ;
/// [lifecycle] est le cycle de vie de l'app, donné à la file d'analyse (spec 004,
/// CA32, CA33).
///
/// Avec [storage] (spec 005) : purge des fichiers temporaires d'export, reprise
/// d'une suppression totale interrompue, marqueur d'installation, puis ouverture
/// (par défaut [openJournal] sur [storage]) ; export par [shareSheet] et
/// suppression totale proposés dans les Réglages. Sans [storage] ni [open], les
/// emplacements du téléphone. [wiped] : une suppression vient de réussir (CA18).
Future<Widget> startApp({
  Future<Journal> Function()? open,
  AppStorage? storage,
  ShareSheet shareSheet = const SharePlusShareSheet(),
  bool wiped = false,
  Stream<AppLifecycleState>? lifecycle,
}) async {
  if (open == null && storage == null) {
    storage = await AppStorage.system();
  }
  final store = storage;
  final openNow =
      open ??
      () => openJournal(folder: store!.folder, keyStore: store.keyStore);
  if (store != null) {
    // Fichier d'export resté d'un partage interrompu (CA10).
    try {
      await purgeExportTemporaryFiles(store.cacheFolder);
    } catch (_) {}
    // Suppression interrompue : reprise avant toute ouverture de la base, jamais
    // ouverte tant que `wipe-pending` existe (RM43, CA22, CA23).
    final wiper = _wiperFor(store);
    if (wiper.isPending) {
      try {
        await wiper.resume();
      } catch (_) {
        return const StartupErrorApp(keyMissing: false, wipeIncomplete: true);
      }
      wiped = true;
    }
    // Nouvelle installation : clé orpheline effacée ; n'échoue jamais (RM45).
    await checkInstallMarker(
      folder: store.folder,
      keyStore: store.keyStore,
      files: store.files,
    );
  }
  try {
    final journal = await openNow();
    // Avant tout affichage ; n'échoue jamais (CA16).
    await screenPendingEntries(journal.entries);
    // État du modèle déduit des fichiers ; une erreur laisse le modèle absent
    // (spec 003, CA21, CA22).
    try {
      await journal.downloader.checkAtStartup();
    } catch (_) {}
    final analyzer = journal.analyzer;
    final queue = analyzer == null
        ? null
        : (AnalysisQueue(
            repository: journal.entries,
            analyzer: analyzer,
            downloader: journal.downloader,
            lifecycle: lifecycle,
          )..start());
    var queueStopped = false;
    final writer = journal.reviewWriter;
    final narrator = writer == null
        ? null
        : ReviewNarrator(writer: writer, downloader: journal.downloader);
    return TidemarkApp(
      repository: journal.entries,
      reviewNarrator: narrator,
      settings: journal.settings,
      downloader: journal.downloader,
      analysisQueue: queue,
      wiped: wiped,
      data: store == null
          ? null
          : DataActions(
              export: JournalExport(
                entries: journal.entries,
                settings: journal.settings,
                shareSheet: shareSheet,
                cacheFolder: store.cacheFolder,
              ),
              wiper: _wiperFor(
                store,
                // Plus rien n'écrit la base ni ne lit le modèle pendant
                // l'effacement : file arrêtée et modèle libéré, téléchargement
                // annulé, base fermée.
                closeJournal: () async {
                  // Une seule fois, même si la fermeture de la base échoue et
                  // que la suppression est reprise : `AnalysisQueue.stop` n'est
                  // pas prévu pour être appelé deux fois.
                  if (!queueStopped) {
                    queueStopped = true;
                    try {
                      await queue?.stop();
                    } catch (_) {}
                  }
                  try {
                    await journal.downloader.cancel();
                  } catch (_) {}
                  await journal.close?.call();
                },
              ),
            ),
    );
  } on DatabaseKeyMissingError {
    // Aucune perte silencieuse : ni nouvelle clé, ni base recréée (spec 001) ;
    // la suppression est proposée, jamais lancée d'elle-même (RM44, CA28).
    return StartupErrorApp(
      keyMissing: true,
      wiper: store == null ? null : _wiperFor(store),
    );
  } catch (_) {
    return const StartupErrorApp(keyMissing: false);
  }
}

/// Suppression totale sur les emplacements de [storage].
JournalWiper _wiperFor(
  AppStorage storage, {
  Future<void> Function()? closeJournal,
}) => JournalWiper(
  folder: storage.folder,
  cacheFolder: storage.cacheFolder,
  keyStore: storage.keyStore,
  files: storage.files,
  closeJournal: closeJournal,
);

/// Ouvre la base chiffrée `journal.db` dans [folder] (par défaut
/// Application Support/tidemark, exclu des sauvegardes : AppDelegate sur iOS,
/// règles d'extraction sur Android), avec la clé de [keyStore] (par défaut le
/// trousseau ou le Keystore), créée au premier lancement seulement (ADR-002).
Future<Journal> openJournal({Directory? folder, KeyStore? keyStore}) async {
  final dir =
      folder ??
      Directory('${(await getApplicationSupportDirectory()).path}/tidemark');
  await dir.create(recursive: true);
  final file = File('${dir.path}/journal.db');
  final key = await obtainDatabaseKey(
    keyStore ?? SecureKeyStore(),
    databaseExists: file.existsSync(),
  );
  final db = await AppDatabase.openEncrypted(file, key);
  // Vérifie la clé dès le démarrage, plutôt qu'à la première lecture.
  await db.countEntries();
  // Un seul accès au modèle pour l'étiquetage et le bilan : jamais deux
  // générations ni deux modèles en mémoire (ADR-005, proposé).
  final gate = ModelGate();
  final modelFile = File('${dir.path}/models/${qwenModelSource.fileName}');
  return Journal(
    entries: DriftEntryRepository(db),
    settings: DriftSettingsRepository(db),
    downloader: HttpModelDownloader(
      transport: IoModelTransport(),
      folder: Directory('${dir.path}/models'),
    ),
    analyzer: GatedMoodAnalyzer(LlamaMoodAnalyzer(modelFile: modelFile), gate),
    reviewWriter: GatedReviewWriter(
      LlamaReviewWriter(modelFile: modelFile),
      gate,
    ),
    close: db.close,
  );
}

class TidemarkApp extends StatelessWidget {
  const TidemarkApp({
    super.key,
    required this.repository,
    required this.settings,
    required this.downloader,
    this.dialer = const UrlLauncherDialer(),
    this.analysisQueue,
    this.reviewNarrator,
    this.clock,
    this.data,
    this.wiped = false,
  });

  /// Export et suppression totale, dans les Réglages (spec 005) ; `null` : section
  /// « Mes données » absente.
  final DataActions? data;

  /// Une suppression totale vient de réussir : message de fin sur la liste (CA18).
  final bool wiped;

  final EntryRepository repository;
  final SettingsRepository settings;
  final ModelDownloader downloader;
  final PhoneDialer dialer;

  /// File d'analyse (spec 004), visible des écrans par [AnalysisScope] ; `null` :
  /// aucune analyse affichée.
  final AnalysisQueue? analysisQueue;

  /// Mise en mots du bilan de la semaine (spec 006) ; `null` : bilan sans
  /// rédacteur.
  final ReviewNarrator? reviewNarrator;

  /// Date et heure locales ; [DateTime.now] par défaut.
  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context) {
    final app = MaterialApp(
      title: 'Tidemark',
      theme: buildTidemarkTheme(Brightness.light),
      darkTheme: buildTidemarkTheme(Brightness.dark),
      home: EntryListScreen(
        repository: repository,
        settings: settings,
        downloader: downloader,
        dialer: dialer,
        clock: clock ?? DateTime.now,
        data: data,
        wiped: wiped,
        narrator: reviewNarrator,
      ),
    );
    final queue = analysisQueue;
    return queue == null ? app : AnalysisScope(queue: queue, child: app);
  }
}

/// Écran affiché si le journal ne peut pas être ouvert (clé absente, base illisible).
class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({
    super.key,
    required this.keyMissing,
    this.wipeIncomplete = false,
    this.wiper,
  });

  /// La base existe mais sa clé est introuvable ; sinon, autre cause (disque,
  /// moteur sans chiffrement, base illisible).
  final bool keyMissing;

  /// Une suppression totale interrompue n'a pas pu être reprise au démarrage
  /// (spec 005, CA23) : « Réessayer » la rejoue.
  final bool wipeIncomplete;

  /// Suppression totale proposée quand la clé est introuvable (spec 005, CA26) ;
  /// `null` : aucun bouton.
  final JournalWiper? wiper;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tidemark',
      theme: buildTidemarkTheme(Brightness.light),
      darkTheme: buildTidemarkTheme(Brightness.dark),
      home: Builder(builder: _screen),
    );
  }

  Widget _screen(BuildContext context) {
    final wiper = this.wiper;
    final offerWipe = keyMissing && wiper != null;
    return Scaffold(
      body: SafeArea(
        // L'écran défile à 200 % : le bouton reste atteignable (CA34).
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(TidemarkSpacing.space4),
              sliver: SliverFillRemaining(
                hasScrollBody: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: TidemarkSpacing.space8),
                    Semantics(
                      header: true,
                      child: Text(
                        wipeIncomplete
                            ? "La suppression n'est pas terminée"
                            : "Ton journal n'a pas pu être ouvert",
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(color: context.colors.danger),
                      ),
                    ),
                    const SizedBox(height: TidemarkSpacing.space2),
                    Text(
                      wipeIncomplete
                          ? wipeIncompleteMessage
                          : keyMissing
                          ? "Tes entrées sont toujours sur le téléphone, mais la clé "
                                "qui les protège est introuvable. Rien n'a été effacé."
                          : "Rien n'a été effacé. Ferme l'app, puis rouvre-la.",
                    ),
                    if (offerWipe) ...[
                      const SizedBox(height: TidemarkSpacing.space3),
                      Text(
                        'Sans cette clé, elles ne pourront plus être lues. Tu '
                        'peux tout supprimer et commencer un nouveau journal.',
                        style: TidemarkTypography.body.copyWith(
                          color: context.colors.inkMuted,
                        ),
                      ),
                    ],
                    const Spacer(),
                    const SizedBox(height: TidemarkSpacing.space6),
                    if (offerWipe)
                      DangerButton(
                        label: 'Tout supprimer et repartir de zéro',
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => WipeConfirmationScreen(
                              wiper: wiper,
                              keyMissing: true,
                            ),
                          ),
                        ),
                      ),
                    if (wipeIncomplete) const _RetryWipeButton(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// « Réessayer » de l'écran « La suppression n'est pas terminée » (CA23) : rouvre
/// l'app, qui reprend la suppression avant toute ouverture de la base.
class _RetryWipeButton extends StatefulWidget {
  const _RetryWipeButton();

  @override
  State<_RetryWipeButton> createState() => _RetryWipeButtonState();
}

class _RetryWipeButtonState extends State<_RetryWipeButton> {
  bool _busy = false;

  Future<void> _retry() async {
    setState(() => _busy = true);
    try {
      await AppHost.maybeOf(context)?.restart(wiped: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: _busy ? null : _retry,
    child: const Text('Réessayer'),
  );
}
