// Outils communs aux tests de la spec 009 (accueil, navigation, bilan en onglet) :
// l'accueil `HomeShell` sur un dépôt factice, entrées de la semaine du 12 au 18
// octobre 2026, libellés sémantiques attendus, lecture de la sémantique et des pixels.
import 'dart:math' as math;
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/entries/entry.dart';
import 'package:tidemark/main.dart';
import 'package:tidemark/review/review_narrator.dart';
import 'package:tidemark/ui/screens/home_shell.dart';
import 'package:tidemark/ui/widgets/mood_bubble.dart';

import 'fake_entry_repository.dart';
import 'fake_model_downloader.dart';
import 'fake_review_writer.dart';
import 'fake_settings_repository.dart';
import 'playful_harness.dart';
import 'ui_harness.dart';

/// Mercredi 14 octobre 2026, 21:40 (`fixedNow`) : le soir, semaine du 12 au 18.
final eveningNow = fixedNow;

/// Le même mercredi à 08:15 : le jour.
final morningNow = DateTime(2026, 10, 14, 8, 15);

const dayNames = [
  'lundi',
  'mardi',
  'mercredi',
  'jeudi',
  'vendredi',
  'samedi',
  'dimanche',
];

const dayInitials = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

const checkInEvening = 'Comment va ta marée ce soir ?';
const checkInDay = "Comment va ta marée aujourd'hui ?";
const beachTitle = 'Ta plage cette semaine';
const emptyJournalTitle = 'Ta première entrée apparaîtra ici';

/// Jour de la semaine du 12 au 18 octobre 2026 : [day] vaut 1 (lundi) à 7 (dimanche).
DateTime octoberDay(int day, [int hour = 12, int minute = 0]) =>
    DateTime(2026, 10, 11 + day, hour, minute);

String _dayLabel(int index, int? mood) =>
    '${dayNames[index]} ${mood == null ? "pas d'entrée" : moodLabel(mood)}';

/// Annonce de la plage (CA15) pour les humeurs du jour de lundi à dimanche.
String beachLabel(List<int?> moods) =>
    'Ta plage cette semaine : '
    '${[for (var i = 0; i < 7; i++) _dayLabel(i, moods[i])].join(', ')}. '
    'Ouvre le bilan de la semaine.';

/// Annonce de la marée de l'en-tête du bilan (CA24).
String tideLabel(List<int?> moods) =>
    'Humeur par jour : '
    '${[for (var i = 0; i < 7; i++) _dayLabel(i, moods[i])].join(', ')}.';

/// Annonce d'une bulle du check-in (CA12).
String checkInBubbleLabel(int mood) =>
    'Noter ${moodLabel(mood)}, humeur $mood sur 5';

/// Dépôt factice avec une entrée à midi aux jours donnés : `{1: 4, 3: 2}` = lundi à
/// 4 et mercredi à 2.
FakeEntryRepository weekJournal(Map<int, int> moodByDay, {DateTime? now}) {
  final repo = FakeEntryRepository(clock: () => now ?? eveningNow);
  for (final MapEntry(:key, :value) in moodByDay.entries) {
    repo.seed(mood: value, createdAt: octoberDay(key));
  }
  return repo;
}

/// Écran de téléphone, haut ([tall]) pour que toute la liste soit construite.
void useScreen(WidgetTester tester, {bool tall = true}) {
  usePhoneScreen(tester);
  if (tall) tester.view.physicalSize = const Size(393, 2400);
}

/// `testWidgets` avec la sémantique activée et un écran de téléphone.
void homeTest(
  String description,
  Future<void> Function(WidgetTester tester) body, {
  bool tall = true,
}) {
  testWidgets(description, (tester) async {
    useScreen(tester, tall: tall);
    final semantics = tester.ensureSemantics();
    try {
      await body(tester);
    } finally {
      // Démonte l'app avant la fin : plus aucun minuteur du bilan n'attend.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 40));
      semantics.dispose();
    }
  });
}

/// Réglages, téléchargeur et rédacteur du bilan factices partagés par un test.
class HomeEnv {
  HomeEnv(this.repo, {DateTime? now, FakeModelDownloader? downloader})
    : now = now ?? eveningNow,
      downloader = downloader ?? FakeModelDownloader(readyModel) {
    narrator = ReviewNarrator(writer: writer, downloader: this.downloader);
  }

  final FakeEntryRepository repo;
  final settings = FakeSettingsRepository();
  final FakeModelDownloader downloader;
  final writer = FakeReviewWriter();
  late final ReviewNarrator narrator;

  /// Horloge de l'app ; modifiable en cours de test.
  DateTime now;

  Widget shell() => HomeShell(
    repository: repo,
    settings: settings,
    downloader: downloader,
    clock: () => now,
    narrator: narrator,
  );

  /// L'accueil dans une application de test, texte à [textScale], animations
  /// d'ambiance à [ambient].
  Widget app({
    double textScale = 1.0,
    bool ambient = false,
    bool reduceMotion = false,
    GlobalKey? boundary,
  }) => ambientApp(
    boundary == null ? shell() : RepaintBoundary(key: boundary, child: shell()),
    textScale: textScale,
    ambient: ambient,
    reduceMotion: reduceMotion,
  );

  /// L'application entière sur ce dépôt.
  Widget fullApp({bool showWelcome = false}) => TidemarkApp(
    repository: repo,
    settings: settings,
    downloader: downloader,
    clock: () => now,
    reviewNarrator: narrator,
    showWelcome: showWelcome,
  );
}

/// Affiche l'accueil de [env] et laisse les lectures se terminer.
Future<void> showHome(
  WidgetTester tester,
  HomeEnv env, {
  double textScale = 1.0,
  GlobalKey? boundary,
}) async {
  await tester.pumpWidget(env.app(textScale: textScale, boundary: boundary));
  await settle(tester);
}

/// Bouton de la barre de navigation : « Journal » ou « Semaine ».
Finder tab(String name) => find.bySemanticsLabel(RegExp('^$name\$'));

bool isSelectedTab(WidgetTester tester, String name) =>
    tester.getSemantics(tab(name)).flagsCollection.isSelected ==
    Tristate.isTrue;

Future<void> openTab(WidgetTester tester, String name) async {
  await tester.tap(tab(name));
  await settle(tester);
}

/// La plage de la semaine, annoncée comme un seul bouton (CA15).
Finder get beachCard =>
    find.bySemanticsLabel(RegExp(r'^Ta plage cette semaine : '));

/// Lit la sémantique de [finder] : `button` ?
bool isButtonNode(WidgetTester tester, Finder finder) =>
    tester.getSemantics(finder).flagsCollection.isButton;

/// Au moins un des nœuds de [finder] est annoncé comme un bouton (le libellé peut
/// être porté par plusieurs nœuds voisins selon la construction).
bool anyButtonNode(WidgetTester tester, Finder finder) {
  final count = finder.evaluate().length;
  expect(count, greaterThan(0), reason: 'aucun nœud pour $finder');
  return [
    for (var i = 0; i < count; i++)
      tester.getSemantics(finder.at(i)).flagsCollection.isButton,
  ].any((isButton) => isButton);
}

/// Les bulles de taille [size] à l'écran, dans l'ordre de l'arbre.
List<MoodBubble> bubblesOfSize(WidgetTester tester, double size) =>
    bubbles(tester).where((b) => b.size == size).toList();

Finder bubbleFinder(double size) => find.byWidgetPredicate(
  (w) => w is MoodBubble && w.size == size,
  description: 'MoodBubble de $size',
);

/// Rotation cumulée (radians) des `Transform` au-dessus de [target].
double rotationAbove(WidgetTester tester, Finder target) {
  var angle = 0.0;
  tester.element(target.first).visitAncestorElements((element) {
    final widget = element.widget;
    if (widget is Transform) {
      final m = widget.transform.storage;
      angle += math.atan2(m[1], m[0]);
    }
    return true;
  });
  return angle;
}

/// Tous les libellés de sémantique de l'écran, dans l'ordre de parcours.
List<String> semanticLabels(WidgetTester tester) => tester.semantics
    .simulatedAccessibilityTraversal()
    .map((node) => node.label)
    .where((label) => label.isNotEmpty)
    .toList();

/// Nombre de pixels de [color] au-dessus de l'ordonnée [maxY] de la capture.
int countColorAbove(Pixels pixels, Color color, int maxY) {
  var n = 0;
  final limit = math.min(maxY, pixels.height);
  for (var y = 0; y < limit; y++) {
    for (var x = 0; x < pixels.width; x++) {
      if (isColor(pixels.at(x, y), color)) n++;
    }
  }
  return n;
}

/// Octets de la capture au-dessus de l'ordonnée [maxY], pour comparer deux instants.
List<int> bytesAbove(Pixels pixels, int maxY) =>
    pixels.bytes.sublist(0, math.min(maxY, pixels.height) * pixels.width * 4);

/// Texte situé sous [bubble] (même axe vertical, dans les 40 points qui suivent),
/// ou `null` : le libellé d'une bulle du check-in.
Finder labelBelow(WidgetTester tester, Finder bubble, String label) {
  final rect = tester.getRect(bubble);
  return find.byWidgetPredicate((w) {
    if (w is! Text || (w.data ?? '') != label) return false;
    final element = find.byWidget(w).evaluate().single;
    final box = element.renderObject! as RenderBox;
    final at = box.localToGlobal(Offset.zero) & box.size;
    return (at.center.dx - rect.center.dx).abs() < 6 &&
        at.top >= rect.bottom - 2 &&
        at.top - rect.bottom < 40;
  }, description: 'texte « $label » sous la bulle');
}
