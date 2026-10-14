import 'dart:ui' show CheckedState, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/entries/entry.dart';
import 'package:tidemark/main.dart';
import 'package:tidemark/storage/app_database.dart';
import 'package:tidemark/ui/theme/tidemark_theme.dart';

/// Horloge fixe des tests d'interface : mercredi 14 octobre 2026, 21:40 (heure locale).
final fixedNow = DateTime(2026, 10, 14, 21, 40);

const earlyText =
    'Encore une nuit trop courte. Je traîne toute la journée et je repousse tout '
    'à demain.';
const seasideText =
    'Week-end à la mer avec Léa. Pas de téléphone, juste le bruit des vagues.';

/// Texte de plus de deux lignes, avec un saut de ligne.
const longText =
    "Longue journée au travail, mais la balade du soir au bord de l'eau m'a fait du "
    'bien.\nLe vent était tombé, la lumière était belle. J\'ai pensé à rien pendant '
    'une heure. Ensuite je suis rentré, j\'ai préparé une soupe, j\'ai appelé ma '
    'sœur et nous avons parlé longtemps de nos vacances de l\'été prochain.';

/// Nom d'accessibilité d'une pastille d'humeur (CA26).
String moodSemantics(int mood) => 'Humeur $mood sur 5 : ${moodLabel(mood)}';

/// Écran de téléphone (393 x 852), pour que les mises en page soient réalistes.
void usePhoneScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Application de test autour d'un écran, avec les thèmes de la charte et, au besoin,
/// une taille de texte du système.
Widget testApp(Widget home, {double textScale = 1.0}) {
  return MaterialApp(
    theme: buildTidemarkTheme(Brightness.light),
    darkTheme: buildTidemarkTheme(Brightness.dark),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: home,
  );
}

/// Laisse tourner la vraie boucle d'événements (base) et le temps simulé (animations,
/// transitions de page). Pas de `pumpAndSettle` : un indicateur de progression
/// (« Enregistrement… ») ne se stabilise jamais.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }
}

/// Base en mémoire, dépôt réel sur cette base et horloge réglable.
class DbEnv {
  DbEnv() {
    db = AppDatabase.memory();
    repo = DriftEntryRepository(db, clock: () => now);
  }

  late final AppDatabase db;
  late final DriftEntryRepository repo;
  DateTime now = fixedNow;

  /// L'application entière sur cette base, l'horloge de la liste suivant [now].
  Widget app() => TidemarkApp(repository: repo, clock: () => now);

  /// Enregistre une entrée comme si elle avait été saisie à [at] (heure locale).
  Future<Entry> add(
    WidgetTester tester,
    DateTime at,
    int mood, [
    String? text,
  ]) async {
    now = at;
    final entry = await tester.runAsync(
      () => repo.addEntry(mood: mood, text: text),
    );
    now = fixedNow;
    return entry!;
  }

  /// Le journal de la maquette (Liste.dc.html), enregistré dans le désordre.
  Future<void> seedJournal(WidgetTester tester) async {
    await add(tester, DateTime(2026, 10, 13, 22, 5), 2, earlyText);
    await add(tester, DateTime(2026, 10, 12, 19, 30), 5, seasideText);
    await add(tester, DateTime(2026, 10, 14, 8, 15), 3);
    await add(tester, DateTime(2026, 10, 14, 21, 40), 4, longText);
  }

  Future<List<Entry>> entries(WidgetTester tester) async =>
      (await tester.runAsync(() => repo.watchEntries().first))!;

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 25));
      await db.close();
    });
    await tester.pump(const Duration(seconds: 1));
  }
}

/// `testWidgets` avec une base en mémoire fermée en fin de test, la sémantique activée
/// et un écran de téléphone.
void dbTestWidgets(
  String description,
  Future<void> Function(WidgetTester tester, DbEnv env) body,
) {
  testWidgets(description, (tester) async {
    usePhoneScreen(tester);
    final semantics = tester.ensureSemantics();
    final env = DbEnv();
    try {
      await body(tester, env);
    } finally {
      try {
        await env.dispose(tester);
      } catch (_) {
        // Le nettoyage ne doit pas masquer l'échec du test.
      }
      semantics.dispose();
    }
  });
}

/// Ouvre l'écran de saisie depuis la liste.
Future<void> openForm(WidgetTester tester) async {
  await tester.tap(find.text('Nouvelle entrée'));
  await settle(tester);
}

Future<void> pickMood(WidgetTester tester, int mood) async {
  await tester.tap(find.bySemanticsLabel(moodSemantics(mood)));
  await tester.pump();
}

Finder get textInput => find.byType(EditableText);

String inputText(WidgetTester tester) =>
    tester.widget<EditableText>(textInput).controller.text;

/// Le bouton portant [label] est-il actif ? Lu dans la sémantique : le test ne dépend
/// pas du type de widget choisi.
bool isEnabled(WidgetTester tester, String label) =>
    tester.getSemantics(find.text(label)).flagsCollection.isEnabled ==
    Tristate.isTrue;

/// La pastille de l'humeur [mood] est-elle annoncée comme choisie ? Accepte
/// « sélectionné », « coché » ou « activé » : la spec ne fixe pas le mécanisme.
bool isChosen(WidgetTester tester, int mood) {
  final flags = tester
      .getSemantics(find.bySemanticsLabel(moodSemantics(mood)))
      .flagsCollection;
  return flags.isSelected == Tristate.isTrue ||
      flags.isChecked == CheckedState.isTrue ||
      flags.isToggled == Tristate.isTrue;
}

/// Un `Text` vide dans l'arbre : une « ligne de texte vide » (CA5, CA16).
Finder get emptyText => find.byWidgetPredicate(
  (w) => w is Text && (w.data ?? w.textSpan?.toPlainText() ?? '').isEmpty,
  description: 'Text vide',
);

/// Nombre de lignes affichées par le texte qui contient [fragment].
({int lines, bool truncated}) paragraphOf(
  WidgetTester tester,
  String fragment,
) {
  final paragraph = tester.renderObject<RenderParagraph>(
    find.textContaining(fragment),
  );
  return (
    lines: paragraph
        .getBoxesForSelection(
          TextSelection(
            baseOffset: 0,
            extentOffset: paragraph.text.toPlainText().length,
          ),
        )
        .map((box) => box.top.round())
        .toSet()
        .length,
    truncated: paragraph.didExceedMaxLines,
  );
}
