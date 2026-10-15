import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'analysis/analysis_queue.dart';
import 'analysis/llama_mood_analyzer.dart';
import 'analysis/mood_analyzer.dart';
import 'distress/startup_screening.dart';
import 'entries/entry_repository.dart';
import 'model/model_downloader.dart';
import 'model/model_source.dart';
import 'model/model_transport.dart';
import 'export/share_sheet.dart';
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
import 'ui/widgets/my_data_section.dart';
import 'wipe/journal_wiper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = await AppStorage.system();
  runApp(
    AppHost(
      initial: await startApp(storage: storage),
      restart: ({required wiped}) => startApp(storage: storage, wiped: wiped),
    ),
  );
}

/// Journal ouvert : ses entrées et les réglages, sur la même base chiffrée.
class Journal {
  const Journal({
    required this.entries,
    required this.settings,
    required this.downloader,
    this.analyzer,
    this.close,
  });

  final EntryRepository entries;
  final SettingsRepository settings;

  /// Analyseur du modèle local (spec 004) ; `null` : aucune analyse.
  final MoodAnalyzer? analyzer;

  /// Modèle local, dans le dossier `models/` à côté de la base (spec 003).
  final ModelDownloader downloader;

  /// Ferme la base (suppression totale, spec 005) ; `null` : rien à fermer.
  final Future<void> Function()? close;
}

/// Application de démarrage : le journal ouvert, ou l'écran d'erreur qui
/// correspond à la cause (CA35). [open] est injectable pour les tests.
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
}) async {
  if (open == null && storage == null) {
    storage = await AppStorage.system();
  }
  final store = storage;
  open ??= () => openJournal(folder: store!.folder, keyStore: store.keyStore);
  try {
    final journal = await open();
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
          )..start());
    return TidemarkApp(
      repository: journal.entries,
      settings: journal.settings,
      downloader: journal.downloader,
      analysisQueue: queue,
    );
  } on DatabaseKeyMissingError {
    // Aucune perte silencieuse : ni nouvelle clé, ni base recréée (spec 001).
    return const StartupErrorApp(keyMissing: true);
  } catch (_) {
    return const StartupErrorApp(keyMissing: false);
  }
}

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
  return Journal(
    entries: DriftEntryRepository(db),
    settings: DriftSettingsRepository(db),
    downloader: HttpModelDownloader(
      transport: IoModelTransport(),
      folder: Directory('${dir.path}/models'),
    ),
    analyzer: LlamaMoodAnalyzer(
      modelFile: File('${dir.path}/models/${qwenModelSource.fileName}'),
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
      home: Builder(
        builder: (context) => Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(TidemarkSpacing.space4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: TidemarkSpacing.space8),
                  Text(
                    "Ton journal n'a pas pu être ouvert",
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(color: context.colors.danger),
                  ),
                  const SizedBox(height: TidemarkSpacing.space2),
                  Text(
                    keyMissing
                        ? "Tes entrées sont toujours sur le téléphone, mais la clé "
                              "qui les protège est introuvable. Rien n'a été effacé."
                        : "Rien n'a été effacé. Ferme l'app, puis rouvre-la.",
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
