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
import 'review/review_narrator.dart';
import 'review/review_writer.dart';
import 'settings/settings_repository.dart';
import 'storage/app_database.dart';
import 'storage/database_key.dart';
import 'ui/analysis_scope.dart';
import 'ui/phone_dialer.dart';
import 'ui/screens/entry_list_screen.dart';
import 'ui/theme/tidemark_colors.dart';
import 'ui/theme/tidemark_theme.dart';
import 'ui/theme/tidemark_tokens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(await startApp());
}

/// Journal ouvert : ses entrées et les réglages, sur la même base chiffrée.
class Journal {
  const Journal({
    required this.entries,
    required this.settings,
    required this.downloader,
    this.analyzer,
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
}

/// Application de démarrage : le journal ouvert, ou l'écran d'erreur qui
/// correspond à la cause (CA35). [open] est injectable pour les tests.
Future<Widget> startApp({Future<Journal> Function() open = openJournal}) async {
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
  });

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
        narrator: reviewNarrator,
      ),
    );
    final queue = analysisQueue;
    return queue == null ? app : AnalysisScope(queue: queue, child: app);
  }
}

/// Écran affiché si le journal ne peut pas être ouvert (clé absente, base illisible).
class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key, required this.keyMissing});

  /// La base existe mais sa clé est introuvable ; sinon, autre cause (disque,
  /// moteur sans chiffrement, base illisible).
  final bool keyMissing;

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
