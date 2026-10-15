// Garde-fou RM1 et RM23 (spec 005, CA13 ; ADR-003) : le fichier d'export ne sort de
// l'app que par la feuille de partage, ouverte sur l'appui de la personne.
//
// Deux contrôles :
// - statique : seul lib/export/share_sheet.dart importe `package:share_plus`, et
//   `shareFile` n'est appelé dans lib/ que par lib/export/journal_export.dart ;
// - dans l'app : démarrer, enregistrer une entrée et ouvrir les Réglages n'ouvre
//   pas la feuille ; un appui sur « Exporter mes données » l'ouvre une seule fois.
//
// Limite assumée : ce garde-fou ne voit pas le code des dépendances (voir le
// garde-fou réseau, no_network_outside_model_test.dart).
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/main.dart';
import 'package:tidemark/storage/app_database.dart';

import '../support/fake_share_sheet.dart';
import '../support/ui_harness.dart';
import '../support/wipe_harness.dart';

const shareSheetFile = 'lib/export/share_sheet.dart';
const journalExportFile = 'lib/export/journal_export.dart';

/// Remplace les commentaires par des espaces, en gardant les retours à la ligne.
String withoutComments(String source) => source.replaceAllMapped(
  RegExp(r'/\*[\s\S]*?\*/|//[^\n]*'),
  (m) => m[0]!.replaceAll(RegExp(r'[^\n]'), ' '),
);

/// Les infractions d'un ensemble de fichiers [sources] (chemin relatif à la racine du
/// dépôt, contenu) : import de `share_plus` hors de [shareSheetFile], appel (ou
/// référence) de `.shareFile` hors de [journalExportFile].
List<String> violations(Map<String, String> sources) {
  final found = <String>[];
  for (final MapEntry(key: path, value: source) in sources.entries) {
    final code = withoutComments(source);
    if (path != shareSheetFile &&
        RegExp(r'package:share_plus\b').hasMatch(code)) {
      found.add('$path importe share_plus');
    }
    if (path != journalExportFile &&
        RegExp(r'\.\s*shareFile\b').hasMatch(code)) {
      found.add('$path appelle shareFile');
    }
  }
  return found;
}

Map<String, String> readLib() => {
  for (final file in Directory('lib').listSync(recursive: true))
    if (file is File && file.path.endsWith('.dart'))
      file.path.replaceAll(r'\', '/'): file.readAsStringSync(),
};

void main() {
  group('CA13 : garde-fou statique (RM23)', () {
    test('CA13 : seul share_sheet.dart importe share_plus, et seul '
        'journal_export.dart appelle shareFile', () {
      expect(violations(readLib()), isEmpty);
    });

    test('CA13 : share_sheet.dart est bien le seul lieu de share_plus', () {
      final sources = readLib();

      expect(
        withoutComments(sources[shareSheetFile]!),
        contains('package:share_plus'),
      );
    });

    test('CA13 : journal_export.dart appelle bien la feuille de partage, une '
        'seule fois', () {
      final code = withoutComments(readLib()[journalExportFile]!);

      expect(RegExp(r'\.\s*shareFile\s*\(').allMatches(code), hasLength(1));
    });

    test('CA13 : le garde-fou repère un import de share_plus ailleurs', () {
      expect(
        violations({
          shareSheetFile: "import 'package:share_plus/share_plus.dart';",
          'lib/ui/autre.dart': "import 'package:share_plus/share_plus.dart';",
        }),
        ['lib/ui/autre.dart importe share_plus'],
      );
    });

    test('CA13 : le garde-fou repère un appel de shareFile ailleurs', () {
      expect(
        violations({
          journalExportFile: 'await shareSheet.shareFile(file, mimeType: m);',
          'lib/ui/autre.dart': 'sheet.shareFile(file, mimeType: m);',
          'lib/ui/encore.dart': 'final f = sheet\n    .shareFile;',
        }),
        [
          'lib/ui/autre.dart appelle shareFile',
          'lib/ui/encore.dart appelle shareFile',
        ],
      );
    });

    test('CA13 : le garde-fou ignore les commentaires et la déclaration', () {
      expect(
        violations({
          'lib/ui/note.dart':
              "// import 'package:share_plus/share_plus.dart';\n"
              '/* sheet.shareFile(file) */',
          shareSheetFile:
              'Future<void> shareFile(File file, {required String mimeType});',
        }),
        isEmpty,
      );
    });
  });

  group('CA13 : dans l\'app', () {
    testWidgets('CA13 : démarrer, enregistrer une entrée et ouvrir les '
        'Réglages n\'ouvre pas la feuille ; un appui sur « Exporter mes '
        'données » l\'ouvre une seule fois, avec ce seul fichier', (
      tester,
    ) async {
      useTallScreen(tester);
      final env = WipeEnv();
      final sheet = FakeShareSheet();
      final app = (await tester.runAsync(
        () => startApp(storage: env.storage(), shareSheet: sheet),
      ))!;
      try {
        await tester.pumpWidget(app);
        await pumpUntil(
          tester,
          () => find.text('Nouvelle entrée').evaluate().isNotEmpty,
        );
        expect(sheet.shared, isEmpty, reason: 'au démarrage');

        await openForm(tester);
        await pickMood(tester, 3);
        await tester.tap(find.text('Enregistrer'));
        await settleIo(tester);
        final entries = await tester.runAsync(
          () => (app as TidemarkApp).repository.watchEntries().first,
        );
        expect(entries, hasLength(1), reason: 'l\'entrée est enregistrée');
        expect(
          sheet.shared,
          isEmpty,
          reason: 'à l\'enregistrement d\'une entrée',
        );

        await tester.tap(find.bySemanticsLabel('Réglages').first);
        await settle(tester);
        await settleIo(tester);
        expect(find.text('Exporter mes données'), findsOneWidget);
        expect(sheet.shared, isEmpty, reason: 'à l\'ouverture des Réglages');
        expect(env.exportLeftovers(), isEmpty);

        await tester.tap(find.text('Exporter mes données'));
        await pumpUntil(tester, () => sheet.shared.isNotEmpty);
        await pumpUntil(
          tester,
          () => find.text('Exporter mes données').evaluate().isNotEmpty,
        );
        await settleIo(tester);

        expect(sheet.shared, hasLength(1));
        final shared = sheet.shared.single;
        expect(shared.path.startsWith(env.cache.path), isTrue);
        expect(shared.mimeType, 'application/json');
        expect(
          shared.name,
          matches(RegExp(r'^tidemark-export-\d{4}-\d{2}-\d{2}-\d{4}\.json$')),
        );
        expect(
          (jsonDecode(shared.content) as Map)['entries'] as List,
          hasLength(1),
        );
        expect(env.exportLeftovers(), isEmpty, reason: 'fichier effacé');
      } finally {
        // Comme DbEnv.dispose : laisser les flux de la base se fermer avant de la
        // fermer, sinon la fermeture attend un minuteur du temps simulé.
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 25));
          await ((app as TidemarkApp).repository as DriftEntryRepository).db
              .close();
        });
        await tester.pump(const Duration(seconds: 1));
        env.dispose();
      }
    });
  });
}
