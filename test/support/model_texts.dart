// Textes de la maquette du téléchargement du modèle
// (docs/maquettes/003-telechargement-du-modele, `Main.dc.html` et `Reglages.dc.html`),
// et outils communs aux tests d'écran de la spec 003.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tidemark/model/model_downloader.dart';
import 'package:tidemark/model/model_state.dart';
import 'package:tidemark/ui/screens/model_download_screen.dart';

import 'ui_harness.dart';

/// Taille exacte de `qwenModelSource`, utilisée par les écrans.
const totalBytes = 1117320736;

/// 312 999 999 octets sur [totalBytes] : 28,01 %, soit « 28 % » et « 312 Mo ».
const receivedAt28 = 312999999;

/// Titre commun à la progression, à la vérification et à l'échec.
const modelTitle = 'Téléchargement du modèle';

// Proposition.
const offerTitle = 'Des étiquettes pour ton journal';
const offerIntro =
    "Tidemark peut proposer des émotions et des thèmes pour chaque entrée. L'analyse "
    'se fait sur ton téléphone, par un modèle à télécharger une seule fois.';
const offerSizeTitle = '1,1 Go, une seule fois';
const offerSizeDetail = 'Le modèle reste ensuite sur ton téléphone.';
const offerPrivacyTitle = "Rien de ton journal n'est envoyé";
const offerPrivacyDetail =
    'Le téléchargement ne transmet aucune de tes entrées.';
const offerOfflineTitle = 'Ensuite, tout se fait sans réseau';
const offerOfflineDetail = 'Tes entrées sont analysées sur ton téléphone.';
const offerWifiNote =
    'Préfère le Wi-Fi : sur données mobiles, 1,1 Go compte dans ton forfait. Garde '
    'Tidemark ouvert pendant le téléchargement.';
const downloadButton = 'Télécharger le modèle (1,1 Go)';
const later = 'Plus tard';

const offerTexts = [
  offerTitle,
  offerIntro,
  offerSizeTitle,
  offerSizeDetail,
  offerPrivacyTitle,
  offerPrivacyDetail,
  offerOfflineTitle,
  offerOfflineDetail,
  offerWifiNote,
  downloadButton,
  later,
];

// Progression et vérification.
const progressPercent = '28 %';
const progressReceived = '312 Mo sur 1,1 Go';
const progressAdvice =
    "Tu peux revenir à ton journal pendant ce temps. Garde Tidemark ouvert : si tu "
    "quittes l'app, le téléphone peut interrompre le téléchargement, qui repartirait "
    'de zéro.';
const cancelButton = 'Annuler le téléchargement';
const backToJournalButton = 'Revenir à mon journal';
const progressBarLabel = 'Téléchargement du modèle, 28 %';

const progressTexts = [
  modelTitle,
  progressPercent,
  progressReceived,
  progressAdvice,
  cancelButton,
  backToJournalButton,
];

const verifyingText = 'Vérification du fichier…';
const verifyingTexts = [
  modelTitle,
  '100 %',
  '1,1 Go sur 1,1 Go',
  verifyingText,
  backToJournalButton,
];

// Confirmation d'annulation.
const confirmTitle = 'Annuler le téléchargement ?';
const confirmBody = 'Ce qui a déjà été téléchargé sera effacé.';
const confirmKeep = 'Continuer';

// Échecs.
const failNetworkTitle = "Le téléchargement s'est interrompu";
const failNetworkBody =
    "La connexion a été perdue ou le serveur n'a pas répondu. Vérifie ta connexion, "
    'puis réessaie.';
const failChecksumTitle = "Le fichier reçu n'est pas le bon";
const failChecksumBody =
    'Il ne correspond pas au modèle attendu et a été effacé. Réessaie.';
const failStorageTitle = 'Pas assez de place sur le téléphone';
const failStorageBody =
    'Le modèle demande 1,1 Go libres. Libère de la place, puis réessaie.';
const failNothingKept =
    "Rien n'a été gardé : le téléchargement repartira de zéro.";
const retryButton = 'Réessayer (1,1 Go)';

/// Cause d'échec, titre et phrase du bandeau.
const failures = {
  DownloadFailure.network: (failNetworkTitle, failNetworkBody),
  DownloadFailure.checksum: (failChecksumTitle, failChecksumBody),
  DownloadFailure.storage: (failStorageTitle, failStorageBody),
};

List<String> failureTexts(DownloadFailure failure) => [
  modelTitle,
  failures[failure]!.$1,
  failures[failure]!.$2,
  failNothingKept,
  retryButton,
  later,
];

// Prêt.
const readyTitle = 'Le modèle est prêt';
const readyBody =
    'Tes entrées avec du texte vont être analysées sur ton téléphone, une à la fois. '
    'Leurs étiquettes apparaîtront dans ton journal.';
const readyOffline = "L'analyse fonctionne maintenant sans réseau.";
const readyTexts = [readyTitle, readyBody, readyOffline, backToJournalButton];

// Réglages.
const settingsModelSection = 'Analyse sur le téléphone';
const settingsModelRow = "Modèle d'analyse";
const settingsAbsent = 'Non téléchargé · 1,1 Go';
const settingsAbsentNote =
    'Sans lui, tes entrées sont enregistrées sans étiquettes.';
const settingsDownloading = 'Téléchargement : 28 %';
const settingsSeeDownload = 'Voir le téléchargement';
const settingsReady = 'Prêt · 1,1 Go sur ton téléphone';
const settingsReadyNote =
    'Tes entrées sont analysées sur ton téléphone, sans réseau.';

// États types.
const downloading28 = ModelDownloading(
  receivedBytes: receivedAt28,
  totalBytes: totalBytes,
);
const verifying = ModelDownloading(
  receivedBytes: totalBytes,
  totalBytes: totalBytes,
  verifying: true,
);
const ready = ModelReady(path: '/models/qwen2.5-1.5b-instruct-q4_k_m.gguf');

/// Couleur effective du texte [text] (celle qui est peinte).
Color? colorOfText(WidgetTester tester, String text) {
  final finder = find.text(text);
  expect(finder, findsOneWidget, reason: 'texte « $text » absent');
  final paragraph = tester.renderObject<RenderParagraph>(finder);
  return paragraph.text.style?.color;
}

/// Le nœud de [finder], ou l'un de ses parents, est-il annoncé comme région vive ou
/// avec le rôle `status` / `alert` (CA28) ?
bool isAnnounced(WidgetTester tester, Finder finder, {bool alert = false}) {
  SemanticsNode? node = tester.getSemantics(finder);
  while (node != null) {
    final role = node.role;
    if (node.flagsCollection.isLiveRegion ||
        role == SemanticsRole.alert ||
        (!alert && role == SemanticsRole.status)) {
      return true;
    }
    node = node.parent;
  }
  return false;
}

/// Écran du modèle seul, ouvert depuis une page d'accueil repérable : « Revenir »
/// ou « Plus tard » y ramènent. [home] est le texte de cette page.
const homeMarker = 'Accueil de test';

Future<void> showModelScreen(
  WidgetTester tester,
  ModelDownloader downloader, {
  double textScale = 1.0,
}) async {
  await tester.pumpWidget(
    testApp(
      Builder(
        builder: (context) => Scaffold(
          body: Column(
            children: [
              const Text(homeMarker),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ModelDownloadScreen(downloader: downloader),
                  ),
                ),
                child: const Text('Ouvrir le modèle'),
              ),
            ],
          ),
        ),
      ),
      textScale: textScale,
    ),
  );
  await tester.tap(find.text('Ouvrir le modèle'));
  await settle(tester);
}

void useDarkSystem(WidgetTester tester) {
  tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
}
