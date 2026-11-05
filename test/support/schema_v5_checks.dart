// Vérifications communes aux tests de migration depuis les versions 1 à 4 : ce que
// la version 5 ajoute (spec 009, CA2 ; spec 010, CA9) existe et part à vide.
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/storage/app_database.dart';

/// Après la migration vers la version 5 : la colonne `welcome_shown` existe, vaut
/// faux sur toute ligne de réglages déjà présente et à la lecture, et la table
/// `entry_topics` existe et est vide.
Future<void> expectSchema5Additions(AppDatabase db) async {
  final columns = await db.customSelect('PRAGMA table_info(settings)').get();
  expect(columns.map((c) => c.read<String>('name')), contains('welcome_shown'));
  final rows = await db
      .customSelect('SELECT welcome_shown FROM settings')
      .get();
  expect(rows.map((r) => r.read<int>('welcome_shown')), everyElement(0));
  expect(await DriftSettingsRepository(db).readWelcomeShown(), isFalse);

  final topics = await db
      .customSelect('SELECT count(*) AS n FROM entry_topics')
      .getSingle();
  expect(topics.read<int>('n'), 0);
  final entries = await DriftEntryRepository(db).watchEntries().first;
  expect(entries.expand((e) => e.topics), isEmpty);
}
