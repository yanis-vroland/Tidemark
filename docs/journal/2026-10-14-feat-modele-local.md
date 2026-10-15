# Journal : téléchargement du modèle local (spec 003)

Branche `feat/modele-local`.

## 2026-10-14 21:43

### Fait

- Valeurs de `ModelSource` relevées sur Hugging Face, révision `91cad51170dc346986eccefdc2dd33a9da36ead9` du dépôt `Qwen/Qwen2.5-1.5B-Instruct-GGUF` :
  - taille : 1 117 320 736 octets, soit « 1,1 Go » ;
  - SHA-256 : `6a1a2eb6d15622bf3c96857206351ba97e1af16c30d7a74ee38970e434e9407e`.
  - Vérifiées par un téléchargement complet (`curl -L`, puis `shasum -a 256`), fichier effacé ensuite.
  - Première redirection : `302` vers `https://us.aws.cdn.hf.co/xet-bridge-us/…`, hôte admis par le suffixe `.hf.co`.
- Squelette de la spec 003, sans comportement :
  - `ModelSource`, `ModelState`, `ModelTransport`, `IoModelTransport`, `ModelDownloader`, `HttpModelDownloader` ;
  - écran `ModelDownloadScreen` vide ;
  - réglage « proposition affichée » dans `SettingsRepository` ;
  - téléchargeur passé à `TidemarkApp`, à la liste, à la saisie et aux Réglages ;
  - `checkAtStartup` appelé au démarrage.
- Faux : `FakeModelDownloader`, `FakeModelTransport` ; `FakeSettingsRepository` complété.
- Dépendance directe `crypto` 3.0.7 (déjà présente comme dépendance transitive) : calcul du SHA-256 au fil de l'eau.

### Décisions

- Téléchargeur obligatoire dans les écrans, comme les réglages au lot F : aucun repli silencieux en production (agent).

### Corrections et limites

- Tests modifiés, à signaler : 35 constructeurs des tests des specs 001 et 002 reçoivent `downloader: FakeModelDownloader()`, et les imports relatifs des tests touchés sont triés. Changement mécanique, aucune vérification retirée.

### Prochaine étape

Tests de la spec 003 par le subagent `test-writer`, committés seuls et rouges ; puis implémentation.

## 2026-10-15 08:52

### Fait

- Tests de la spec 003, écrits à partir de la spec et de la maquette, sans toucher à `lib/` ni aux tests existants : 308 tests dans 9 fichiers, plus deux fichiers de support (`test/support/model_fixtures.dart`, `test/support/model_texts.dart`).
  - `test/model/` : `http_model_downloader_test.dart` (CA6 à CA10, CA13 à CA18, CA20 à CA22, CA32, `deleteModel`), `io_model_transport_test.dart` (CA31, serveur local sur 127.0.0.1), `model_source_test.dart` (CA27, `isAllowed`, formats CA4 et CA9).
  - `test/guards/no_network_outside_model_test.dart` (CA25, avec détection testée jeton par jeton et portée du balayage testée sur un dossier temporaire).
  - `test/platform/model_download_config_test.dart` (CA26, permission `INTERNET`, pas d'exception ATS).
  - `test/storage/model_offer_storage_test.dart` (réglage « proposition affichée », migration 2 vers 3 et 1 vers 3).
  - `test/ui/` : `model_download_screen_test.dart` (CA4, CA5, CA7, CA9 à CA15, CA17 à CA20, CA28 à CA30), `settings_model_section_test.dart` (CA10, CA23, CA24, CA29, CA30), `model_offer_flow_test.dart` (CA1 à CA3, CA5, CA6, CA11, CA13, CA21).
- Résultat avant implémentation : 438 tests existants verts, 308 nouveaux dont 238 en échec (`UnimplementedError` ou widget absent), 70 qui passent déjà (voir limites).
- Mutations couvertes par un test chacune : suffixe d'hôte avec le point, refus de `http` et de tout port explicite, limite de 5 redirections, empreinte, taille (trop long et trop court), arrêt de la lecture dès le dépassement, effacement du `.part`, délai sans octet (valeur par défaut de 30 s et remise à zéro à chaque octet), absence d'en-tête `Range`.

### Décisions

- CA33 (relecture des PR) n'est pas testé : il porte sur la revue, pas sur le code (agent).
- Le test de `IoModelTransport` admet seulement `host`, `user-agent`, `accept-encoding` et `content-length: 0` sur le fil ; c'est la liste que la spec demande de fixer, à ajuster à l'implémentation si `dart:io` en ajoute un autre, avec justification (agent).

### Corrections et limites

- À corriger à l'implémentation : `test/storage/distress_storage_test.dart` affirme `schemaVersion == 2`. Il contredit la migration vers la version 3 et devra être mis à jour par l'implémentation, en le signalant (test existant, non modifié ici).
- Passent sans implémentation : CA27 (forme de la constante, déjà posée par le squelette), CA26 pour l'emplacement de `models/`, exclusion iOS et ATS, le balayage CA25 de `lib/` et les tests d'absence (CA2, CA3, CA5 côté liste) ; chacun est tenu par un test voisin qui échoue, sauf CA27 et le balayage CA25, qui sont des garde-fous.
- Ambiguïtés de la spec laissées à l'humain, sans trancher : voir la réponse de fin de tâche (statuts de redirection, `hf.co` nu, taille au-delà de 1 000 Mo, « 1,0 Go », délai avant les en-têtes, retour de `start()`).

### Prochaine étape

Relire les tests, puis implémenter jusqu'au vert : `ModelSource.isAllowed` et formats, `HttpModelDownloader`, `IoModelTransport`, `ModelDownloadScreen`, section des Réglages, ouverture de la proposition après la saisie, `DriftSettingsRepository` et migration 3, permission `INTERNET`, jeton `progress-height`.
