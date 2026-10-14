import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'distress/startup_screening.dart';
import 'entries/entry_repository.dart';
import 'settings/settings_repository.dart';
import 'storage/app_database.dart';
import 'storage/database_key.dart';
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
  const Journal({required this.entries, required this.settings});

  final EntryRepository entries;
  final SettingsRepository settings;
}

/// Application de démarrage : le journal ouvert, ou l'écran d'erreur qui
/// correspond à la cause (CA35). [open] est injectable pour les tests.
Future<Widget> startApp({Future<Journal> Function() open = openJournal}) async {
  try {
    final journal = await open();
    // Avant tout affichage ; n'échoue jamais (CA16).
    await screenPendingEntries(journal.entries);
    return TidemarkApp(repository: journal.entries, settings: journal.settings);
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
  );
}

class TidemarkApp extends StatelessWidget {
  const TidemarkApp({
    super.key,
    required this.repository,
    required this.settings,
    this.dialer = const UrlLauncherDialer(),
    this.clock,
  });

  final EntryRepository repository;
  final SettingsRepository settings;
  final PhoneDialer dialer;

  /// Date et heure locales ; [DateTime.now] par défaut.
  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tidemark',
      theme: buildTidemarkTheme(Brightness.light),
      darkTheme: buildTidemarkTheme(Brightness.dark),
      home: EntryListScreen(
        repository: repository,
        settings: settings,
        dialer: dialer,
        clock: clock ?? DateTime.now,
      ),
    );
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
