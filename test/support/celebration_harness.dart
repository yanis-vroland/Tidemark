// Outils communs aux tests de la spec 010 (ce qui a compté, coquillage ramassé) :
// textes exacts de la célébration, parcours « saisie → Enregistrer → célébration »,
// lecture des pixels et de la sémantique de la célébration.
//
// L'application de test des écrans de saisie est celle des harnais existants
// (`testApp`, `ambientApp`) : aucune animation d'ambiance n'y tourne par défaut.
import 'dart:ui' show CheckedState, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/entries/topic.dart';
import 'package:tidemark/ui/motion/ambient_motion.dart';
import 'package:tidemark/ui/theme/tidemark_theme.dart';

import 'home_harness.dart';
import 'playful_harness.dart';
import 'ui_harness.dart';

/// Titre, phrases et boutons de la célébration (spec 010, CA12, CA13, CA17).
const celebrationTitle = 'Coquillage ramassé';
const softCelebrationTitle = 'Entrée enregistrée';
const softCelebrationLine = 'Elle rejoint ta plage.';
const fallbackCelebrationLine = 'Il rejoint ta plage.';
const firstShellLine = 'Ton 1er de la semaine. Il ouvre ta plage.';
const continueLabel = 'Continuer';

/// « Ton 3e de la semaine. Il rejoint ta plage, à côté des autres. »
String nthShellLine(int rank) =>
    'Ton ${rank}e de la semaine. Il rejoint ta plage, à côté des autres.';

/// Annonce de la rangée des coquillages (CA18).
String shellRowLabel(int count) => count == 1
    ? '1 coquillage cette semaine'
    : '$count coquillages cette semaine';

const topicsTitle = 'Ce qui a compté';

/// Le sujet [topic] est-il le libellé d'un bouton de la saisie ? Les six sujets
/// sont cherchés par leur libellé exact.
Finder topicButton(Topic topic) => find.bySemanticsLabel(topic.label);

/// Le sujet est-il annoncé comme choisi ? Accepte `toggled` ou `selected` : la
/// spec 010 (CA3) ne fixe pas le mécanisme.
bool isTopicOn(WidgetTester tester, Topic topic) {
  final flags = tester.getSemantics(topicButton(topic)).flagsCollection;
  return flags.isToggled == Tristate.isTrue ||
      flags.isSelected == Tristate.isTrue ||
      flags.isChecked == CheckedState.isTrue;
}

/// Touche le sujet [topic] dans la saisie.
Future<void> tapTopic(WidgetTester tester, Topic topic) async {
  await tester.tap(find.text(topic.label));
  await tester.pump();
}

/// La célébration est-elle à l'écran ? (titre de la version complète ou douce)
bool celebrationShown() =>
    find.text(celebrationTitle).evaluate().isNotEmpty ||
    find.text(softCelebrationTitle).evaluate().isNotEmpty;

/// Touche « Continuer » sur la célébration et laisse la navigation se terminer.
/// Échoue si la célébration n'est pas à l'écran.
Future<void> continueFromCelebration(WidgetTester tester) async {
  expect(
    find.text(continueLabel),
    findsOneWidget,
    reason: 'la célébration doit être à l\'écran (spec 010, CA16)',
  );
  await tester.tap(find.text(continueLabel));
  await settle(tester);
}

/// Transition de page sans aucun effet visuel : un changement de pixels pendant un
/// test vient alors de l'écran lui-même, pas du passage d'une page à l'autre.
class _InstantTransitions extends PageTransitionsBuilder {
  const _InstantTransitions();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}

ThemeData _instant(ThemeData theme) => theme.copyWith(
  pageTransitionsTheme: PageTransitionsTheme(
    builders: {
      for (final platform in TargetPlatform.values)
        platform: const _InstantTransitions(),
    },
  ),
);

/// L'accueil de [env] dans une application de test dont toutes les pages sont
/// capturées par [boundary] (les pages poussées comprises), avec des transitions de
/// page instantanées si [instant]. [ambient] allume les animations d'ambiance :
/// n'utiliser alors ni `pumpAndSettle` ni `settle` jusqu'au repos.
Widget celebrationApp(
  HomeEnv env, {
  double? textScale,
  bool ambient = false,
  bool reduceMotion = false,
  bool instant = false,
  GlobalKey? boundary,
}) {
  ThemeData theme(Brightness b) {
    final base = buildTidemarkTheme(b);
    return instant ? _instant(base) : base;
  }

  return MaterialApp(
    theme: theme(Brightness.light),
    darkTheme: theme(Brightness.dark),
    builder: (context, child) {
      final body = AmbientMotion(enabled: ambient, child: child!);
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(
          // Sans `textScale`, la taille de texte du système (réglable par
          // [useSystemTextScale]) s'applique.
          textScaler: textScale == null ? null : TextScaler.linear(textScale),
          disableAnimations: reduceMotion,
        ),
        child: boundary == null
            ? body
            : RepaintBoundary(key: boundary, child: body),
      );
    },
    home: env.shell(),
  );
}

/// Ouvre la saisie depuis l'accueil, choisit l'humeur [mood], écrit [text] et choisit
/// [topics] s'ils sont donnés, puis touche « Enregistrer » ; ne laisse PAS le temps
/// passer après l'appui (voir [saveAndSettle] pour le faire).
Future<void> fillAndSave(
  WidgetTester tester, {
  required int mood,
  String? text,
  List<Topic> topics = const [],
}) async {
  // À 200 % le bouton peut être sous le pli de l'accueil.
  await tester.ensureVisible(find.text('Nouvelle entrée'));
  await tester.tap(find.text('Nouvelle entrée'));
  await settle(tester);
  await pickMood(tester, mood);
  if (text != null) {
    await tester.enterText(textInput, text);
    await tester.pump();
  }
  for (final topic in topics) {
    await tapTopic(tester, topic);
  }
  await tester.tap(find.text('Enregistrer'));
}

/// [fillAndSave], puis laisse l'enregistrement et la navigation se terminer.
Future<void> saveAndSettle(
  WidgetTester tester, {
  required int mood,
  String? text,
  List<Topic> topics = const [],
}) async {
  await fillAndSave(tester, mood: mood, text: text, topics: topics);
  await settle(tester);
}

/// Fait avancer le temps par pas de [step] jusqu'à ce que la célébration soit à
/// l'écran, et s'arrête à la première image où elle l'est.
Future<void> pumpUntilCelebrated(
  WidgetTester tester, {
  Duration step = const Duration(milliseconds: 16),
}) async {
  for (var i = 0; i < 200 && !celebrationShown(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump(step);
  }
  expect(celebrationShown(), isTrue, reason: 'la célébration doit s\'afficher');
}

/// Nombre de pixels de [color] dans la capture, ligne [fromY] comprise et au-dessous.
int countColorFrom(Pixels pixels, Color color, int fromY) {
  var n = 0;
  for (var y = fromY; y < pixels.height; y++) {
    for (var x = 0; x < pixels.width; x++) {
      if (isColor(pixels.at(x, y), color)) n++;
    }
  }
  return n;
}

/// Abscisse du pixel de [color] le plus à gauche, ligne [fromY] comprise et
/// au-dessous ; `null` s'il n'y en a aucun.
int? leftmostFrom(Pixels pixels, Color color, int fromY) {
  int? found;
  for (var y = fromY; y < pixels.height; y++) {
    for (var x = 0; x < pixels.width; x++) {
      if (isColor(pixels.at(x, y), color) && (found == null || x < found)) {
        found = x;
      }
    }
  }
  return found;
}

/// Un texte du sous-arbre [root] est-il coupé (lignes en trop, points de
/// suspension) ?
void expectNothingTruncated(WidgetTester tester, Finder root, String where) {
  for (final element
      in find
          .descendant(of: root, matching: find.byType(RichText))
          .evaluate()) {
    final render = element.renderObject;
    if (render is RenderParagraph) {
      expect(
        render.didExceedMaxLines,
        isFalse,
        reason: '$where : « ${render.text.toPlainText()} » est tronqué',
      );
    }
  }
}

/// [after] se lit après [before] : plus bas, ou sur la même ligne et plus à droite.
/// Les autocollants tournent d'un ou deux degrés : deux positions à moins de
/// [lineTolerance] points de hauteur comptent pour la même ligne.
bool readsAfter(Offset before, Offset after, {double lineTolerance = 14}) =>
    after.dy > before.dy + lineTolerance ||
    ((after.dy - before.dy).abs() <= lineTolerance && after.dx > before.dx);

/// Règle la taille de texte du système à [scale] pour la suite du test (comme le
/// réglage « taille de texte » du téléphone), rétablie en fin de test.
Future<void> useSystemTextScale(WidgetTester tester, double scale) async {
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pump();
}
