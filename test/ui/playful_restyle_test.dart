// Refonte ludique appliquée aux écrans existants (spec 008, CA2, CA11 à CA13, CA15
// à CA19) : bulles de marée, fonds par humeur, autocollants, boutons, 200 %, sombre.
// L'écran d'aide est dans help_screen_calm_test.dart ; la bulle seule dans
// widgets/mood_bubble_test.dart.
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/analysis/mood_analyzer.dart';
import 'package:tidemark/entries/entry.dart';
import 'package:tidemark/model/model_state.dart';
import 'package:tidemark/ui/screens/entry_detail_screen.dart';
import 'package:tidemark/ui/screens/entry_form_screen.dart';
import 'package:tidemark/ui/screens/entry_list_screen.dart';
import 'package:tidemark/ui/screens/model_download_screen.dart';
import 'package:tidemark/ui/screens/settings_screen.dart';
import 'package:tidemark/ui/screens/wipe_confirmation_screen.dart';
import 'package:tidemark/ui/theme/tidemark_colors.dart';
import 'package:tidemark/ui/theme/tidemark_tokens.dart';
import 'package:tidemark/ui/widgets/mood_bubble.dart';

import '../guards/no_hardcoded_colors_test.dart' show offendingLines;
import '../support/distress_harness.dart'
    show allTextsOfScreen, expectNoTruncatedText;
import '../support/fake_entry_repository.dart';
import '../support/fake_model_downloader.dart';
import '../support/fake_settings_repository.dart';
import '../support/model_texts.dart';
import '../support/playful_harness.dart';
import '../support/ui_harness.dart';
import '../support/wipe_harness.dart';

const light = TidemarkColors.light;
const dark = TidemarkColors.dark;

/// `testWidgets` sur un écran de téléphone, avec la sémantique activée.
void uiTest(String description, Future<void> Function(WidgetTester) body) {
  testWidgets(description, (tester) async {
    usePhoneScreen(tester);
    final semantics = tester.ensureSemantics();
    try {
      await body(tester);
    } finally {
      await tester.pumpWidget(const SizedBox());
      semantics.dispose();
    }
  });
}

Widget formScreen({
  FakeEntryRepository? repository,
  double textScale = 1.0,
  bool ambient = false,
}) => ambientApp(
  EntryFormScreen(
    repository: repository ?? FakeEntryRepository(),
    settings: FakeSettingsRepository(),
    downloader: FakeModelDownloader(readyModel),
  ),
  textScale: textScale,
  ambient: ambient,
);

Entry entryOf(int mood, {String? text = longText}) => Entry(
  id: 1,
  mood: mood,
  text: text,
  createdAt: DateTime.utc(2026, 10, 14, 21, 40),
  utcOffset: Duration.zero,
  analysisStatus: AnalysisStatus.pending,
);

Widget detailScreen(Entry entry, {double textScale = 1.0}) => ambientApp(
  EntryDetailScreen(entry: entry, repository: FakeEntryRepository()),
  textScale: textScale,
);

Widget listScreen(FakeEntryRepository repo, {double textScale = 1.0}) =>
    ambientApp(
      EntryListScreen(
        repository: repo,
        settings: FakeSettingsRepository(),
        clock: () => fixedNow,
        downloader: FakeModelDownloader(readyModel),
      ),
      textScale: textScale,
    );

/// Un journal avec une entrée par humeur, un jour chacune.
FakeEntryRepository journalOfAllMoods() {
  final repo = FakeEntryRepository(clock: () => fixedNow);
  for (var mood = 1; mood <= 5; mood++) {
    repo.seed(
      mood: mood,
      text: 'Entrée de l\'humeur $mood.',
      createdAt: DateTime(2026, 10, 9 + mood, 18),
    );
  }
  return repo;
}

/// Une entrée étiquetée (quatre étiquettes fictives).
Future<FakeEntryRepository> taggedJournal() async {
  final repo = FakeEntryRepository(clock: () => fixedNow);
  final e = repo.seed(mood: 4, text: longText, createdAt: fixedNow);
  await repo.saveAnalysis(
    e.id,
    Tagged([
      Tag('fatigue', TagKind.emotion),
      Tag('calme', TagKind.emotion),
      Tag('travail', TagKind.theme),
      Tag('nature', TagKind.theme),
    ]),
  );
  return repo;
}

TextStyle styleOf(WidgetTester tester, Finder text) =>
    tester.renderObject<RenderParagraph>(text).text.style!;

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

/// Premier `DecoratedBox` au-dessus de [target] dont l'ombre est [shadow].
BoxDecoration? decorationWithShadow(
  WidgetTester tester,
  Finder target,
  List<BoxShadow> shadow,
) {
  BoxDecoration? found;
  tester.element(target.first).visitAncestorElements((element) {
    final widget = element.widget;
    if (widget is DecoratedBox && widget.decoration is BoxDecoration) {
      final d = widget.decoration as BoxDecoration;
      if (d.boxShadow != null && _sameShadows(d.boxShadow!, shadow)) {
        found = d;
        return false;
      }
    }
    return true;
  });
  return found;
}

bool _sameShadows(List<BoxShadow> a, List<BoxShadow> b) =>
    a.length == b.length &&
    [for (var i = 0; i < a.length; i++) a[i] == b[i]].every((same) => same);

void main() {
  group('garde-fous (CA2)', () {
    test('CA2 : le peintre des bulles existe et n\'écrit aucune couleur en '
        'dur', () {
      final file = File('lib/ui/widgets/mood_bubble.dart');
      expect(file.existsSync(), isTrue);
      expect(offendingLines(file.readAsStringSync()), isEmpty);
    });

    test('MoodDot disparaît : fichier supprimé, plus aucune référence', () {
      expect(File('lib/ui/widgets/mood_dot.dart').existsSync(), isFalse);
      final users = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) => f.readAsStringSync().contains('MoodDot'));
      expect(users.map((f) => f.path), isEmpty);
    });
  });

  group('saisie (CA11)', () {
    uiTest('CA11 : sans humeur, cinq bulles de 44, un cercle à la place de la '
        'grande bulle, fond surface', (tester) async {
      await tester.pumpWidget(formScreen());
      await tester.pump(const Duration(milliseconds: 400));

      final all = bubbles(tester);
      expect(all, hasLength(5));
      expect({for (final b in all) b.mood}, {1, 2, 3, 4, 5});
      for (final b in all) {
        expect(b.size, TidemarkSize.bubbleSelect, reason: 'humeur ${b.mood}');
        expect(b.ring, isFalse, reason: 'humeur ${b.mood}');
      }
      expect(find.byKey(const Key('mood-placeholder')), findsOneWidget);
      expect(
        scaffoldColor(tester, find.text('Comment ça va ?')),
        light.surface,
      );
    });

    uiTest('CA11 : l\'humeur choisie passe à 52 avec un anneau, une grande '
        'bulle de 150 la montre', (tester) async {
      await tester.pumpWidget(formScreen());
      await tester.pump(const Duration(milliseconds: 400));

      await pickMood(tester, 4);
      await tester.pump(const Duration(milliseconds: 400));

      final all = bubbles(tester);
      expect(all, hasLength(6));
      final selected = all.where((b) => b.size == TidemarkSize.bubbleSelectOn);
      expect(selected, hasLength(1));
      expect(selected.single.mood, 4);
      expect(selected.single.ring, isTrue);
      final others = all.where((b) => b.size == TidemarkSize.bubbleSelect);
      expect({for (final b in others) b.mood}, {1, 2, 3, 5});
      expect(others.every((b) => !b.ring), isTrue);
      final big = all.where((b) => b.size == TidemarkSize.bubbleXl);
      expect(big, hasLength(1));
      expect(big.single.mood, 4);
      expect(find.byKey(const Key('mood-placeholder')), findsNothing);
    });

    uiTest('CA11 : changer d\'humeur déplace l\'anneau et change la grande '
        'bulle', (tester) async {
      await tester.pumpWidget(formScreen());
      await tester.pump(const Duration(milliseconds: 400));

      await pickMood(tester, 4);
      await pickMood(tester, 2);
      await tester.pump(const Duration(milliseconds: 400));

      final all = bubbles(tester);
      expect(
        all.where((b) => b.size == TidemarkSize.bubbleSelectOn).single.mood,
        2,
      );
      expect(all.where((b) => b.ring), hasLength(1));
      expect(all.where((b) => b.size == TidemarkSize.bubbleXl).single.mood, 2);
    });

    uiTest('CA11 : le fond de l\'écran prend mood-n-night de l\'humeur choisie '
        '(clair)', (tester) async {
      await tester.pumpWidget(formScreen());
      await tester.pump(const Duration(milliseconds: 400));
      final title = find.text('Comment ça va ?');

      for (var mood = 1; mood <= 5; mood++) {
        await pickMood(tester, mood);
        await tester.pump(const Duration(milliseconds: 400));
        expect(
          scaffoldColor(tester, title),
          light.moodNightColor(mood),
          reason: 'humeur $mood',
        );
      }
    });

    uiTest('CA11, CA19 : en sombre, le fond prend mood-n-night sombre', (
      tester,
    ) async {
      useDarkPlatform(tester);
      await tester.pumpWidget(formScreen());
      await tester.pump(const Duration(milliseconds: 400));
      final title = find.text('Comment ça va ?');
      expect(scaffoldColor(tester, title), dark.surface);

      for (var mood = 1; mood <= 5; mood++) {
        await pickMood(tester, mood);
        await tester.pump(const Duration(milliseconds: 400));
        expect(
          scaffoldColor(tester, title),
          dark.moodNightColor(mood),
          reason: 'humeur $mood',
        );
      }
    });

    uiTest('CA11 : les libellés, l\'aide et les annonces restent ceux de la '
        'spec 001, sans chiffre dans les bulles', (tester) async {
      await tester.pumpWidget(formScreen());
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Choisis une humeur pour enregistrer.'), findsOneWidget);
      for (var mood = 1; mood <= 5; mood++) {
        expect(find.text('$mood'), findsNothing, reason: 'aucun chiffre');
        expect(
          find.bySemanticsLabel(moodSemantics(mood)),
          findsOneWidget,
          reason: 'annonce de l\'humeur $mood',
        );
      }
      await pickMood(tester, 4);
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Bien'), findsOneWidget);
      expect(isChosen(tester, 4), isTrue);
      expect(find.text('Choisis une humeur pour enregistrer.'), findsNothing);
      // La grande bulle est décorative : une seule annonce par humeur.
      expect(find.bySemanticsLabel(moodSemantics(4)), findsOneWidget);
    });

    uiTest('CA11 : sur 320 points de large, les cinq bulles tiennent et '
        'restent des cibles de 44 points', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      await tester.pumpWidget(formScreen());
      await tester.pump(const Duration(milliseconds: 400));
      await pickMood(tester, 3);
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);
      for (var mood = 1; mood <= 5; mood++) {
        final node = tester.getSemantics(
          find.bySemanticsLabel(moodSemantics(mood)),
        );
        final rect = MatrixUtils.transformRect(
          node.transform ?? Matrix4.identity(),
          node.rect,
        );
        expect(rect.width, greaterThanOrEqualTo(TidemarkSize.tapMin));
        expect(rect.height, greaterThanOrEqualTo(TidemarkSize.tapMin));
      }
      for (final element in find.byType(MoodBubble).evaluate()) {
        final box = element.renderObject! as RenderBox;
        final rect = box.localToGlobal(Offset.zero) & box.size;
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(320));
      }
    });

    uiTest('CA11 : avec animations d\'ambiance, la saisie anime ; réduites, '
        'plus rien ne tourne', (tester) async {
      await tester.pumpWidget(formScreen(ambient: true));
      await tester.pump(const Duration(milliseconds: 400));
      await pickMood(tester, 5);
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.hasRunningAnimations, isTrue);

      await tester.pumpWidget(
        ambientApp(
          EntryFormScreen(
            repository: FakeEntryRepository(),
            settings: FakeSettingsRepository(),
            downloader: FakeModelDownloader(readyModel),
          ),
          ambient: true,
          reduceMotion: true,
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('carte d\'entrée (CA12)', () {
    uiTest('CA12 : la carte montre une bulle de 48 de son humeur, sans '
        'chiffre', (tester) async {
      final repo = FakeEntryRepository(clock: () => fixedNow)
        ..seed(mood: 4, text: longText, createdAt: fixedNow);
      await tester.pumpWidget(listScreen(repo));
      await settle(tester);

      final card = bubbles(tester)
          .where((b) => b.size == TidemarkSize.bubbleMd);
      expect(card, hasLength(1));
      expect(card.single.mood, 4);
      expect(find.text('4'), findsNothing);
      expect(find.text('21:40'), findsOneWidget);
      // Spec 009, CA11 : « Bien » est aussi le libellé de la bulle du check-in.
      expect(find.text('Bien'), findsNWidgets(2));
    });

    uiTest('CA12 : la carte a le fond mood-n-soft, texte en on-mood, pour '
        'chaque humeur', (tester) async {
      tester.view.physicalSize = const Size(393, 3200);
      await tester.pumpWidget(listScreen(journalOfAllMoods()));
      await settle(tester);

      for (var mood = 1; mood <= 5; mood++) {
        final bubble = find.byWidgetPredicate(
          (w) => w is MoodBubble && w.mood == mood && w.size == 48,
        );
        expect(bubble, findsOneWidget, reason: 'humeur $mood');
        expect(
          backgroundBehind(tester, bubble),
          light.moodSoftColor(mood),
          reason: 'fond, humeur $mood',
        );
        final snippet = find.textContaining('Entrée de l\'humeur $mood.');
        expect(
          paintedTextColor(tester, snippet),
          light.onMood,
          reason: '$mood',
        );
        // Spec 009, CA11 : le même libellé est sous la bulle du check-in ; la carte
        // d'entrée est plus bas.
        final label = find.text(moodLabel(mood)).last;
        expect(paintedTextColor(tester, label), light.onMood, reason: '$mood');
      }
    });

    uiTest('CA12 : le texte garde ses deux lignes au plus', (tester) async {
      final repo = FakeEntryRepository(clock: () => fixedNow)
        ..seed(mood: 4, text: longText, createdAt: fixedNow);
      await tester.pumpWidget(listScreen(repo));
      await settle(tester);

      final shown = paragraphOf(tester, 'Longue journée au travail');
      expect(shown.lines, lessThanOrEqualTo(2));
      expect(shown.truncated, isTrue);
    });

    uiTest('CA12 : les étiquettes sont des autocollants : fond plein, ombre '
        'shadow-sticker, arrondi', (tester) async {
      await tester.pumpWidget(listScreen(await taggedJournal()));
      await settle(tester);

      for (final label in ['fatigue', 'calme', 'travail', 'nature']) {
        final decoration = decorationWithShadow(
          tester,
          find.text(label),
          TidemarkShadows.shadowSticker,
        );
        expect(decoration, isNotNull, reason: '$label : ombre d\'autocollant');
        expect(decoration!.color, isNotNull, reason: '$label : fond plein');
        final radius = (decoration.borderRadius! as BorderRadius).topLeft.x;
        expect(
          [TidemarkRadius.radiusPill, TidemarkRadius.radiusLg],
          contains(radius),
          reason: '$label : radius-pill ou radius-lg',
        );
      }
    });

    uiTest('CA12 : chaque autocollant pivote de 3° au plus, de façon fixe', (
      tester,
    ) async {
      await tester.pumpWidget(listScreen(await taggedJournal()));
      await settle(tester);
      const labels = ['fatigue', 'calme', 'travail', 'nature'];
      final first = [
        for (final l in labels) rotationAbove(tester, find.text(l)),
      ];

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpWidget(listScreen(await taggedJournal()));
      await settle(tester);
      final second = [
        for (final l in labels) rotationAbove(tester, find.text(l)),
      ];

      const limit = 3 * math.pi / 180 + 1e-9;
      for (var i = 0; i < labels.length; i++) {
        expect(first[i].abs(), lessThanOrEqualTo(limit), reason: labels[i]);
        expect(
          second[i],
          closeTo(first[i], 1e-9),
          reason: 'fixe : ${labels[i]}',
        );
      }
      expect(
        first.any((angle) => angle.abs() > 1e-6),
        isTrue,
        reason: 'au moins un autocollant est légèrement pivoté',
      );
    });

    uiTest('CA12 : l\'annonce de la carte reste « Bien, humeur 4 sur 5, 21:40, '
        '… » et ne lit pas la bulle', (tester) async {
      final repo = FakeEntryRepository(clock: () => fixedNow)
        ..seed(mood: 4, text: 'Balade au bord de l\'eau.', createdAt: fixedNow);
      await tester.pumpWidget(listScreen(repo));
      await settle(tester);

      expect(
        find.bySemanticsLabel(
          RegExp(r"^Bien, humeur 4 sur 5, 21:40, Balade au bord de l'eau\.$"),
        ),
        findsOneWidget,
      );
    });
  });

  group('détail (CA13)', () {
    uiTest('CA13 : un en-tête mood-n-soft montre la bulle de 120, le libellé '
        'en display et « Humeur 4 sur 5 »', (tester) async {
      await tester.pumpWidget(detailScreen(entryOf(4)));
      await tester.pump(const Duration(milliseconds: 400));

      final big = bubbles(tester);
      expect(big, hasLength(1));
      expect(big.single.mood, 4);
      expect(big.single.size, TidemarkSize.bubbleLg);
      expect(
        backgroundBehind(tester, find.byType(MoodBubble)),
        light.moodSoftColor(4),
      );
      expect(
        backgroundBehind(tester, find.text('Bien')),
        light.moodSoftColor(4),
      );
      expect(styleOf(tester, find.text('Bien')).fontSize, 40);
      expect(find.text('Humeur 4 sur 5'), findsOneWidget);
      expect(find.text('4'), findsNothing, reason: 'plus de chiffre');
    });

    uiTest('CA13 : la date, l\'heure, le texte et la suppression sont '
        'inchangés', (tester) async {
      await tester.pumpWidget(detailScreen(entryOf(4)));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining('Mercredi 14 octobre'), findsOneWidget);
      expect(find.text('21:40'), findsOneWidget);
      expect(
        find.textContaining('nos vacances de l\'été prochain'),
        findsOneWidget,
      );
      expect(find.text('Supprimer cette entrée'), findsOneWidget);
      expect(emptyText, findsNothing);
    });

    uiTest('CA13 : chaque humeur a son en-tête et sa bulle', (tester) async {
      for (var mood = 1; mood <= 5; mood++) {
        await tester.pumpWidget(detailScreen(entryOf(mood)));
        await tester.pump(const Duration(milliseconds: 400));

        expect(bubbles(tester).single.mood, mood);
        expect(
          backgroundBehind(tester, find.byType(MoodBubble)),
          light.moodSoftColor(mood),
          reason: 'humeur $mood',
        );
        expect(find.text('Humeur $mood sur 5'), findsOneWidget);
        expect(find.text(moodLabel(mood)), findsOneWidget);
      }
    });
  });

  group('proposition du modèle (CA15)', () {
    Future<void> showOffer(WidgetTester tester, {double textScale = 1}) async {
      await tester.pumpWidget(
        ambientApp(
          ModelDownloadScreen(
            downloader: FakeModelDownloader(const ModelAbsent()),
          ),
          textScale: textScale,
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
    }

    uiTest('CA15 : une bulle « Neutre » est au-dessus du titre', (
      tester,
    ) async {
      await showOffer(tester);

      final all = bubbles(tester);
      expect(all, hasLength(1));
      expect(all.single.mood, 3);
      expect(
        tester.getBottomLeft(find.byType(MoodBubble)).dy,
        lessThanOrEqualTo(tester.getTopLeft(find.text(offerTitle)).dy),
      );
    });

    uiTest('CA15 : tous les textes de la spec 003 sont là, plus quatre '
        'autocollants d\'étiquettes', (tester) async {
      await showOffer(tester);

      final texts = allTextsOfScreen(tester, ModelDownloadScreen);
      expect(texts, containsAll(offerTexts));
      expect(
        texts.length,
        offerTexts.length + 4,
        reason: 'quatre étiquettes fictives, rien d\'autre',
      );
    });

    uiTest('CA15 : l\'illustration est décorative : ses autocollants ne sont '
        'pas annoncés', (tester) async {
      await showOffer(tester);

      final extras = [
        for (final t in allTextsOfScreen(tester, ModelDownloadScreen))
          if (!offerTexts.contains(t)) t,
      ];
      expect(extras, hasLength(4));
      for (final extra in extras) {
        expect(find.bySemanticsLabel(extra), findsNothing, reason: extra);
      }
    });

    uiTest('CA15 : les quatre autocollants ont l\'ombre shadow-sticker', (
      tester,
    ) async {
      await showOffer(tester);

      final extras = [
        for (final t in allTextsOfScreen(tester, ModelDownloadScreen))
          if (!offerTexts.contains(t)) t,
      ];
      for (final extra in extras) {
        expect(
          decorationWithShadow(
            tester,
            find.text(extra),
            TidemarkShadows.shadowSticker,
          ),
          isNotNull,
          reason: extra,
        );
      }
    });
  });

  group('Réglages et suppression totale (CA16)', () {
    uiTest('CA16 : les Réglages : fond v2, cartes en radius-lg, sans bulle ni '
        'animation', (tester) async {
      await tester.pumpWidget(
        ambientApp(
          SettingsScreen(
            settings: FakeSettingsRepository(),
            downloader: FakeModelDownloader(readyModel),
          ),
          ambient: true,
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(MoodBubble), findsNothing);
      expect(tester.hasRunningAnimations, isFalse);
      expect(scaffoldColor(tester, find.byType(SettingsScreen)), light.surface);
      final rounded = find.byWidgetPredicate((w) {
        if (w is DecoratedBox && w.decoration is BoxDecoration) {
          final r = (w.decoration as BoxDecoration).borderRadius;
          return r is BorderRadius && r.topLeft.x == TidemarkRadius.radiusLg;
        }
        if (w is Material && w.shape is RoundedRectangleBorder) {
          final r = (w.shape! as RoundedRectangleBorder).borderRadius;
          return r is BorderRadius && r.topLeft.x == TidemarkRadius.radiusLg;
        }
        return false;
      });
      expect(rounded, findsWidgets, reason: 'cartes en radius-lg');
    });

    testWidgets('CA16 : la confirmation de suppression : fond v2, sans bulle '
        'ni animation', (tester) async {
      useTallScreen(tester);
      final env = WipeEnv();
      try {
        await tester.pumpWidget(
          ambientApp(
            WipeConfirmationScreen(
              wiper: env.wiper(),
              keyMissing: false,
              onWiped: env.onWiped,
            ),
            ambient: true,
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('Tout supprimer ?'), findsOneWidget);
        expect(find.byType(MoodBubble), findsNothing);
        expect(tester.hasRunningAnimations, isFalse);
        expect(
          scaffoldColor(tester, find.text('Tout supprimer ?')),
          light.surface,
        );
      } finally {
        await tester.pumpWidget(const SizedBox());
        env.dispose();
      }
    });
  });

  group('boutons pleine largeur (CA17)', () {
    Finder buttonOf(String label) => find.ancestor(
      of: find.text(label),
      matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
    );

    uiTest('CA17 : « Enregistrer » mesure 56, en style button, avec '
        'shadow-press', (tester) async {
      await tester.pumpWidget(formScreen());
      await tester.pump(const Duration(milliseconds: 400));
      await pickMood(tester, 4);
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.getSize(buttonOf('Enregistrer')).height, 56);
      final style = styleOf(tester, find.text('Enregistrer'));
      expect(style.fontSize, 17);
      expect(style.fontWeight, FontWeight.w700);
      expect(
        decorationWithShadow(
          tester,
          find.text('Enregistrer'),
          TidemarkShadows.shadowPress,
        ),
        isNotNull,
        reason: 'ombre shadow-press sous le bouton plein',
      );
    });

    uiTest('CA17 : le bouton du modèle mesure 56, en style button, avec '
        'shadow-press', (tester) async {
      await tester.pumpWidget(
        ambientApp(
          ModelDownloadScreen(
            downloader: FakeModelDownloader(const ModelAbsent()),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.getSize(buttonOf(downloadButton)).height, 56);
      final style = styleOf(tester, find.text(downloadButton));
      expect(style.fontSize, 17);
      expect(style.fontWeight, FontWeight.w700);
      expect(
        decorationWithShadow(
          tester,
          find.text(downloadButton),
          TidemarkShadows.shadowPress,
        ),
        isNotNull,
      );
    });
  });

  group('texte à 200 % (CA18)', () {
    void expectNoOverflow(WidgetTester tester, String where) {
      final exception = tester.takeException();
      expect(exception, isNull, reason: '$where : $exception');
    }

    uiTest('CA18 : la saisie avec une humeur choisie ne déborde pas, ses '
        'bulles gardent leur taille', (tester) async {
      await tester.pumpWidget(formScreen(textScale: 2.0));
      await tester.pump(const Duration(milliseconds: 400));
      await pickMood(tester, 5);
      await tester.pump(const Duration(milliseconds: 400));

      expectNoOverflow(tester, 'saisie');
      expectNoTruncatedText(tester, find.byType(EntryFormScreen), 'saisie');
      final sizes = [for (final b in bubbles(tester)) b.size]..sort();
      expect(sizes, [44, 44, 44, 44, 52, 150]);
      for (final element in find.byType(MoodBubble).evaluate()) {
        final widget = element.widget as MoodBubble;
        expect(element.size, Size.square(widget.size));
      }
    });

    uiTest('CA18 : la liste, avec des cartes étiquetées, ne déborde pas', (
      tester,
    ) async {
      await tester.pumpWidget(
        listScreen(await taggedJournal(), textScale: 2.0),
      );
      await settle(tester);

      expectNoOverflow(tester, 'liste');
      // Spec 009 : les bulles du check-in (54) précèdent celle de la carte (48).
      expect(
        tester.getSize(
          find.byWidgetPredicate((w) => w is MoodBubble && w.size == 48),
        ),
        const Size.square(48),
      );
    });

    uiTest('CA18 : le détail ne déborde pas, la bulle garde ses 120 points', (
      tester,
    ) async {
      await tester.pumpWidget(detailScreen(entryOf(4), textScale: 2.0));
      await tester.pump(const Duration(milliseconds: 400));

      expectNoOverflow(tester, 'détail');
      expectNoTruncatedText(tester, find.byType(EntryDetailScreen), 'détail');
      expect(tester.getSize(find.byType(MoodBubble)), const Size.square(120));
    });

    uiTest('CA18 : la proposition du modèle, avec son illustration, ne '
        'déborde pas', (tester) async {
      await tester.pumpWidget(
        ambientApp(
          ModelDownloadScreen(
            downloader: FakeModelDownloader(const ModelAbsent()),
          ),
          textScale: 2.0,
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expectNoOverflow(tester, 'modèle');
      expectNoTruncatedText(tester, find.byType(ModelDownloadScreen), 'modèle');
      expect(find.byType(MoodBubble), findsOneWidget);
    });
  });

  group('thème sombre (CA19)', () {
    uiTest('CA19 : la liste : fond sombre, cartes mood-n-soft, texte on-mood', (
      tester,
    ) async {
      useDarkPlatform(tester);
      tester.view.physicalSize = const Size(393, 3200);
      await tester.pumpWidget(listScreen(journalOfAllMoods()));
      await settle(tester);

      expect(scaffoldColor(tester, find.text('Ton journal')), dark.surface);
      for (var mood = 1; mood <= 5; mood++) {
        final bubble = find.byWidgetPredicate(
          (w) => w is MoodBubble && w.mood == mood && w.size == 48,
        );
        expect(
          backgroundBehind(tester, bubble),
          dark.moodSoftColor(mood),
          reason: 'humeur $mood',
        );
        expect(
          paintedTextColor(tester, find.text(moodLabel(mood)).last),
          dark.onMood,
          reason: 'humeur $mood',
        );
      }
    });

    uiTest('CA19 : le détail : en-tête mood-n-soft, titre et texte aux valeurs '
        'sombres', (tester) async {
      useDarkPlatform(tester);
      await tester.pumpWidget(detailScreen(entryOf(4)));
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        scaffoldColor(tester, find.text('Supprimer cette entrée')),
        dark.surface,
      );
      expect(
        backgroundBehind(tester, find.byType(MoodBubble)),
        dark.moodSoftColor(4),
      );
      expect(
        paintedTextColor(tester, find.text('Supprimer cette entrée')),
        dark.danger,
      );
    });

    uiTest('CA19 : la proposition du modèle : fond et textes sombres', (
      tester,
    ) async {
      useDarkPlatform(tester);
      await tester.pumpWidget(
        ambientApp(
          ModelDownloadScreen(
            downloader: FakeModelDownloader(const ModelAbsent()),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(scaffoldColor(tester, find.text(offerTitle)), dark.surface);
    });
  });
}
