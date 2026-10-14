import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'entries/entry_repository.dart';
import 'storage/app_database.dart';
import 'storage/database_key.dart';
import 'ui/screens/entry_list_screen.dart';
import 'ui/theme/tidemark_colors.dart';
import 'ui/theme/tidemark_theme.dart';
import 'ui/theme/tidemark_tokens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final repository = await openJournal();
    runApp(TidemarkApp(repository: repository));
  } catch (_) {
    // Aucune perte silencieuse : la base n'est ni recréée ni effacée (spec 001).
    runApp(const StartupErrorApp());
  }
}

/// Ouvre la base chiffrée dans Application Support/tidemark, dossier exclu des
/// sauvegardes (iOS : AppDelegate ; Android : règles d'extraction), avec la clé du
/// trousseau ou du Keystore, créée au premier lancement (ADR-002).
Future<EntryRepository> openJournal() async {
  final support = await getApplicationSupportDirectory();
  final folder = Directory('${support.path}/tidemark');
  await folder.create(recursive: true);
  final key = await obtainDatabaseKey(SecureKeyStore());
  final db = await AppDatabase.openEncrypted(
    File('${folder.path}/journal.db'),
    key,
  );
  // Vérifie la clé dès le démarrage, plutôt qu'à la première lecture.
  await db.countEntries();
  return DriftEntryRepository(db);
}

class TidemarkApp extends StatelessWidget {
  const TidemarkApp({super.key, required this.repository, this.clock});

  final EntryRepository repository;

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
        clock: clock ?? DateTime.now,
      ),
    );
  }
}

/// Écran affiché si le journal ne peut pas être ouvert (clé absente, base illisible).
class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key});

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
                  const Text(
                    "Tes entrées sont toujours sur le téléphone, mais la clé qui les "
                    "protège est introuvable. Rien n'a été effacé.",
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
