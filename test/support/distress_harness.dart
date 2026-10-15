import 'dart:ui' show CheckedState;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/distress/distress_detector.dart';
import 'package:tidemark/entries/entry.dart';
import 'package:tidemark/main.dart';

import 'fake_entry_repository.dart';
import 'fake_model_downloader.dart';
import 'fake_phone_dialer.dart';
import 'fake_settings_repository.dart';
import 'ui_harness.dart';

/// Textes de la maquette de l'écran d'aide (docs/maquettes/002-garde-fou-detresse,
/// `Main.dc.html`), état nominal.
const helpTitle = 'Parler peut aider';
const helpIntro =
    "Ton entrée est bien enregistrée. Si c'est difficile en ce moment, des "
    "personnes formées peuvent t'écouter, gratuitement, à toute heure.";
const call3114 = 'Appeler le 3114';
const call112 = 'Appeler le 112';
const backToJournal = 'Revenir à mon journal';
const dialFailedTitle = "L'appel n'a pas pu être lancé";
const dialFailedBody =
    'Compose le numéro depuis ton téléphone : 3114, ou 112 en cas de danger '
    'immédiat.';

/// Textes de la maquette des Réglages (`Reglages.dc.html`). Les « d’affilée » portent
/// l'apostrophe typographique de la maquette.
const settingsTitle = 'Réglages';
const settingsBack = 'Journal';
const settingsSection = "Écran d'aide";
const settingsIntro =
    "L'écran d'aide s'ouvre quand tes dernières humeurs sont toutes « Très bas ». "
    'Choisis à partir de quand.';
const settingsNote =
    "L'écran d'aide ne peut pas être désactivé. Les mots qui signalent un danger "
    "ouvrent toujours l'écran d'aide, quel que soit ce choix.";
const settingsSaveFailedTitle = "Le réglage n'a pas été enregistré";
const settingsSaveFailedBody = 'Le réglage précédent reste en place. Réessaie.';
const highLabel = 'Haute';
const highDetail = '2 entrées « Très bas » d’affilée, en 3 jours au plus';
const normalLabel = 'Normale (recommandée)';
const normalDetail = '3 entrées « Très bas » d’affilée, en 7 jours au plus';
const lowLabel = 'Basse';
const lowDetail = '5 entrées « Très bas » d’affilée, en 14 jours au plus';

/// Texte d'un `Text`, qu'il soit simple ou composé.
String textOf(Text text) => text.data ?? text.textSpan?.toPlainText() ?? '';

/// Tous les textes affichés par l'écran de type [screen].
List<String> allTextsOfScreen(WidgetTester tester, Type screen) => tester
    .widgetList<Text>(
      find.descendant(of: find.byType(screen), matching: find.byType(Text)),
    )
    .map(textOf)
    .toList();

/// Couleurs réellement peintes par les widgets sous [root] : fonds, cadres, ombres
/// portées exclues, et couleur de chaque texte ou icône. Sert à vérifier qu'une couleur
/// de la charte est (ou n'est pas) utilisée à l'écran.
Set<Color> paintedColors(WidgetTester tester, Finder root) {
  final colors = <Color>{};

  void addSide(BorderSide side) {
    if (side.style != BorderStyle.none && side.width > 0) {
      colors.add(side.color);
    }
  }

  void addShape(ShapeBorder? shape) {
    if (shape is OutlinedBorder) addSide(shape.side);
  }

  void addBox(Decoration? decoration) {
    if (decoration is! BoxDecoration) return;
    final color = decoration.color;
    if (color != null) colors.add(color);
    final border = decoration.border;
    if (border is Border) {
      for (final side in [
        border.top,
        border.right,
        border.bottom,
        border.left,
      ]) {
        addSide(side);
      }
    }
  }

  final widgets = find
      .descendant(of: root, matching: find.byWidgetPredicate((_) => true))
      .evaluate()
      .map((e) => e.widget);
  for (final widget in widgets) {
    switch (widget) {
      case Material(:final color, :final shape):
        if (color != null) colors.add(color);
        addShape(shape);
      case DecoratedBox(:final decoration):
        addBox(decoration);
      case ColoredBox(:final color):
        colors.add(color);
      case PhysicalModel(:final color):
        colors.add(color);
      case PhysicalShape(:final color):
        colors.add(color);
      case Ink(:final decoration):
        addBox(decoration);
      case RichText(:final text):
        text.visitChildren((span) {
          final color = span.style?.color;
          if (color != null) colors.add(color);
          return true;
        });
        final color = text.style?.color;
        if (color != null) colors.add(color);
      default:
        break;
    }
  }
  return colors;
}

/// Un texte est-il tronqué (points de suspension, lignes en trop) ?
void expectNoTruncatedText(WidgetTester tester, Finder root, String where) {
  final paragraphs = find.descendant(of: root, matching: find.byType(RichText));
  for (final element in paragraphs.evaluate()) {
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

/// Étiquettes non vides lues par un lecteur d'écran, dans l'ordre de parcours.
List<String> readingOrder(WidgetTester tester) => tester.semantics
    .simulatedAccessibilityTraversal()
    .map((node) => node.label)
    .where((label) => label.isNotEmpty)
    .toList();

/// Le degré [label] est-il annoncé comme bouton radio coché ? `null` si le nœud n'est
/// pas un bouton radio (pas de groupe exclusif ou pas d'état coché).
bool? radioChecked(WidgetTester tester, String label) {
  final flags = tester.getSemantics(find.text(label)).flagsCollection;
  if (!flags.isInMutuallyExclusiveGroup) return null;
  return switch (flags.isChecked) {
    CheckedState.isTrue => true,
    CheckedState.isFalse => false,
    _ => null,
  };
}

/// Entrée de test : seule l'humeur et l'instant comptent pour une série.
Entry entryAt(int mood, DateTime at, {int id = 1, String? text}) => Entry(
  id: id,
  mood: mood,
  text: text,
  createdAt: at.toUtc(),
  utcOffset: Duration.zero,
  analysisStatus: AnalysisStatus.skipped,
);

/// L'application entière sur des faux, avec une horloge réglable partagée entre
/// l'application et le dépôt (l'instant de saisie suit [now]).
class GuardEnv {
  GuardEnv([LowMoodSensitivity start = LowMoodSensitivity.normal])
    : settings = FakeSettingsRepository(start),
      dialer = FakePhoneDialer() {
    repo = FakeEntryRepository(clock: () => now);
  }

  late final FakeEntryRepository repo;
  final FakeSettingsRepository settings;
  final FakePhoneDialer dialer;
  DateTime now = fixedNow;

  Widget app() => TidemarkApp(
    repository: repo,
    settings: settings,
    dialer: dialer,
    clock: () => now,
    downloader: FakeModelDownloader(readyModel),
  );

  /// Saisit une entrée par l'interface, à l'instant [at] (heure locale) : ouvre la
  /// saisie, choisit l'humeur, tape le texte, touche « Enregistrer ».
  Future<void> enterEntry(
    WidgetTester tester,
    DateTime at,
    int mood, [
    String? text,
  ]) async {
    now = at;
    await openForm(tester);
    await pickMood(tester, mood);
    if (text != null) {
      await tester.enterText(textInput, text);
      await tester.pump();
    }
    await tester.tap(find.text('Enregistrer'));
    await settle(tester);
  }
}
