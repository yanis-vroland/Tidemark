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

## 2026-10-15 09:12

### Fait

- Implémentation de la spec 003 :
  - `HttpModelDownloader` : redirections suivies et vérifiées (au plus 5, hôtes admis), écriture dans le fichier `.part` avec l'empreinte calculée au fil de l'eau, arrêt dès que la taille est dépassée, délai de 30 s sans octet, vérification puis renommage, annulation, démarrage, suppression, revérification après un échec de chargement ;
  - `IoModelTransport` : sans redirection suivie, sans décompression, sans en-tête par défaut de `dart:io` ;
  - `ModelDownloadScreen` dans ses cinq états et sa confirmation d'annulation ; section « Analyse sur le téléphone » des Réglages ; proposition après la première entrée « en attente » ;
  - colonne `model_offer_shown` et schéma en version 3 ;
  - permission `INTERNET` dans le manifeste Android principal.
- Jeton `progress-height` (8) ajouté à la charte : `tokens.json`, `TidemarkSize` et l'artefact en ligne.
- Architecture technique : modèle de données, contrats `ModelDownloader` et `ModelTransport`, section réseau.
- 748 tests verts, en heure de Paris comme en UTC.
- Contrôle par mutation sur 19 protections : 16 détectées d'emblée, et 2 après l'ajout d'un test chacune (`http` sur le port 443, réponse 404 avec les bons octets). La dernière, `userAgent = null`, est équivalente : l'en-tête `User-Agent: Tidemark` remplace de toute façon celui de `dart:io`.

### Décisions

- Un échec récent s'affiche dès l'ouverture de l'écran du modèle (CA19), y compris depuis les Réglages (agent).
- La section « Analyse sur le téléphone » n'apparaît qu'une fois le degré lu, pour tenir CA22 de la spec 002 : pendant le chargement, le retour et le titre seulement (agent).
- Boutons de l'écran du modèle fixés en bas de l'écran, comme sur la saisie (agent).

### Corrections et limites

- Tests modifiés, à signaler :
  - `test/storage/distress_storage_test.dart` : « le schéma est en version 2 » devient « au moins en version 2 », la spec 003 passant à la version 3.
  - `test/ui/settings_screen_test.dart` (spec 002) : défilement avant 8 touchers sur un degré, que la nouvelle section du modèle pousse sous l'écran.
  - Tests des specs 001 et 002 : le faux téléchargeur y est « prêt » (`readyModel`), pour que la proposition du modèle (spec 003, CA1) ne s'ouvre pas. Ce sont les 35 appels ajoutés au squelette ; aucune vérification retirée.
  - Ajoutés après le commit des tests : la réponse 404 avec les bons octets, et `http` sur le port 443.
- Pas encore essayé sur un appareil : téléchargement réel à faire (émulateur Android, puis iPhone par Yanis).

### Prochaine étape

Revues `reviewer` et `security-reviewer`, téléchargement réel sur l'émulateur Android, puis PR.

## 2026-10-15 09:21

### Fait

- Suites des revues `reviewer` (1 point bloquant) et `security-reviewer` (1 point à corriger), même défaut : une annulation pendant la connexion ou les redirections était ignorée, et les 1,1 Go étaient reçus avant d'être effacés. Corrections :
  - annulation immédiate à toute étape : l'attente du transport, les redirections, l'ouverture du fichier, chaque morceau reçu, et juste avant le renommage ;
  - réponses non lues (redirections, erreurs, réponse arrivée après une annulation) refermées sans être lues ;
  - `Content-Length` différent de la taille attendue refusé d'emblée (« Le fichier reçu n'est pas le bon ») ;
  - délai de connexion de 30 s sur le client HTTP ;
  - un échec du renommage s'affiche comme un manque de place ;
  - `watch()` sans perte d'événement (`Stream.multi`) ;
  - proposition automatique seulement si le modèle est absent sans échec récent ;
  - `crypto` épinglé exactement (3.0.7).
- 7 tests ajoutés. 3 échouent avec l'ancien code du téléchargeur (annulation avant la réponse, annulation pendant une redirection, `Content-Length`).
- Essai réel sur l'émulateur Android (Pixel 7, API 35, Wi-Fi du Mac), avant ces corrections :
  - Réglages, puis « Télécharger le modèle (1,1 Go) », proposition, puis téléchargement ;
  - progression affichée (6 % au bout de 15 s, « 67 Mo sur 1,1 Go ») ;
  - « Le modèle est prêt » au bout de 4 minutes environ ;
  - fichier de 1 117 320 736 octets sur l'appareil, `sha256sum` identique à `ModelSource` ;
  - après un arrêt forcé et une relance, les Réglages affichent « Prêt · 1,1 Go sur ton téléphone » (CA22).
  - Aucune boucle négative.
- Chaîne de redirections réelle : `huggingface.co/…/resolve/91cad511…/…` répond `302` vers `us.aws.cdn.hf.co/xet-bridge-us/…`, qui sert le fichier en `200`. Hôte admis par le suffixe `.hf.co`.
- 755 tests verts, en heure de Paris comme en UTC.

### Décisions

- Non suivis (revue de sécurité) :
  - Restreindre les hôtes aux CDN observés : l'hôte réel (`us.aws.cdn.hf.co`) n'est pas dans la liste proposée, et Hugging Face change de stockage sans prévenir. L'empreinte protège l'intégrité ; la spec garde les suffixes (agent).
  - Recalculer l'empreinte avant chaque premier chargement : décision 5 de la spec (plusieurs secondes à chaque lancement). Le fichier est dans le bac à sable de l'app ; CA32 revérifie après un échec de chargement. À revoir au lot G si llama.cpp lit un fichier altéré sans échouer (agent).
- `ErrorBanner` reste en `liveRegion` : Flutter refuse un nœud à la fois `alert` et `liveRegion`, et les tests de CA28 acceptent l'annonce en zone vivante (agent).

### Corrections et limites

- Le téléchargement réel sur l'émulateur a précédé les corrections d'annulation ; elles ne touchent pas au chemin nominal, que les tests couvrent.
- La ligne du cahier des charges sur le téléchargement du modèle est corrigée par la PR #21, encore ouverte.
- Les textes de l'état « Prêt » annoncent l'analyse de la spec 004, livrée dans la PR suivante du lot G.

### Prochaine étape

PR, revue IA, puis spec 004 (étiquetage) sur une nouvelle branche après le merge.

## 2026-10-15 09:29

### Fait

- Suites de la revue IA de la PR #22 (aucun point bloquant) :
  - écriture qui échoue en cours de transfert, et renommage impossible : tous deux affichés « place », désormais testés. L'ouverture du `.part` est injectable (`openPart`) pour simuler un stockage plein ;
  - une annulation confirmée après le début de la vérification est ignorée : le fichier complet n'est pas jeté (CA14) ;
  - garde-fou réseau élargi à toute classe `*Socket`, à `HttpServer` et aux paquets `http2`, `web_socket_channel` et `grpc` ;
  - CA3 complété : pas de proposition automatique après un échec récent ;
  - épaisseur de l'indicateur de vérification sur le jeton `ring-width` ;
  - connexions inactives du client HTTP refermées au bout de 1 s ;
  - ligne de la spec 003 du cahier des charges, alignée sur la PR #21.
- Contrôle par mutation des trois nouvelles protections : toutes détectées. 759 tests verts.

### Décisions

- `openPart` injectable, marqué `@visibleForTesting` : seul moyen simple de simuler un disque plein en cours de route (agent).

### Corrections et limites

- Test ajouté au garde-fou existant `test/guards/no_network_outside_model_test.dart` : des motifs en plus, aucune vérification retirée.
- Test humain sur l'iPhone toujours attendu de Yanis, annulation comprise.

### Prochaine étape

Merge de la PR par Yanis après son test humain ; rebase de `feat/etiquetage` sur `main`.
