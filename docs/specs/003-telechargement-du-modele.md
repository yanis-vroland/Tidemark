# Spec 003 : téléchargement du modèle local

Statut : validée (Yanis, merge de la PR #18, 2026-10-14 ; décisions métier déléguées à l'agent). Complétée le 2026-10-16 par `feat/integrite-moteur-modele` (vérification avant le premier chargement, CA34 à CA36, décision n° 11 ; agent, par délégation de Yanis, 2026-10-16), à valider par Yanis avec sa PR.
Date : 2026-10-14

## Besoin

En tant que personne qui tient son journal, je veux télécharger une seule fois, en connaissant sa taille et en sachant que rien de mon journal n'est envoyé, le modèle qui analyse mes entrées sur mon téléphone, afin d'obtenir des étiquettes sans qu'aucune donnée ne quitte mon téléphone.

Premier volet du lot G du [plan](../plan.md) (branche `feat/modele-local`) ; l'étiquetage est la [spec 004](004-etiquetage-automatique.md). Règles du [cahier des charges](../cahier-des-charges-fonctionnel.md) appliquées : RM1, RM11, RM18, RM26, RM30, RM31, RM32. Moteur et modèle : [ADR-001](../adr/001-moteur-ia-local.md) ; stockage : [ADR-002](../adr/002-stockage-local-chiffre.md). Maquette : voir « Maquette ».

C'est le seul accès réseau de l'app (RM1). Ce lot ne fait encore aucune analyse : il amène le modèle local (`LocalModel`) sur le téléphone, vérifié, et dit à tout moment où il en est.

## Écrans

- **Écran du modèle** (`ModelDownloadScreen`) : un seul écran, dans cinq états.
  - **Proposition** : ce que fait le modèle, sa taille, ce qui n'est pas envoyé ; « Télécharger le modèle (1,1 Go) » et « Plus tard ».
  - **Progression** : pourcentage, barre, mégaoctets reçus ; « Annuler le téléchargement » (avec confirmation) et « Revenir à mon journal ».
  - **Vérification** : barre pleine, « Vérification du fichier… ».
  - **Échec** : bandeau d'erreur selon la cause (réseau, fichier faux, place), « Réessayer (1,1 Go) » et « Plus tard ».
  - **Prêt** : « Le modèle est prêt », « Revenir à mon journal ».
- **Réglages** (`SettingsScreen`, [spec 002](002-garde-fou-detresse.md)) : nouvelle section « Analyse sur le téléphone », au-dessus de la section « Écran d'aide », avec l'état du modèle.
- **Liste des entrées** (spec 001) : inchangée. L'écran du modèle s'ouvre à sa place dans le cas de CA1.

## Règles

### Source du modèle (RM30)

- **Fichier** : Qwen2.5-1.5B-Instruct, GGUF, quantification Q4_K_M (ADR-001), licence Apache-2.0. Taille mesurée au spike : 1 066 Mo (`docs/adr/001-mesures/`), annoncée « 1,1 Go ».
- **Adresse** : une seule URL HTTPS, épinglée sur une révision (commit) du dépôt `Qwen/Qwen2.5-1.5B-Instruct-GGUF` de Hugging Face, de la forme `https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/<commit>/qwen2.5-1.5b-instruct-q4_k_m.gguf`.
- **Empreinte** : SHA-256 du fichier, en constante dans le code.
- L'URL, le commit, l'empreinte et la taille exacte en octets ne figurent ni dans l'ADR-001 ni dans ses mesures. Ils sont **fixés à l'implémentation**, dans une seule constante (`ModelSource`), relevés sur la page du fichier à la révision choisie (empreinte « SHA256 » de Hugging Face), puis vérifiés une fois en téléchargeant le fichier (`shasum -a 256`) ; la PR d'implémentation donne la commande et son résultat. Un test vérifie la forme de la constante (CA27).
- **Hôtes** : Hugging Face répond à `huggingface.co/…/resolve/…` par une redirection vers son stockage de fichiers, sur un autre hôte. « Un seul hôte » (plan, lot G) n'est donc pas tenable avec une URL stable ; la règle devient : **un seul fournisseur** (plan mis à jour). L'app suit elle-même les redirections, au plus 5 :
  - un `Location` relatif (`/api/resolve-cache/…`) est résolu sur l'URL courante, puis soumis à la même règle ;
  - l'adresse obtenue doit être en `https`, sur le port par défaut, et son hôte (en minuscules) égal à `huggingface.co`, ou finir par `.huggingface.co` ou par `.hf.co` : comparaison par suffixe, **point compris**. `cdn-lfs.huggingface.co` et `cas-bridge.xethub.hf.co` sont admis ; `huggingface.co.evil.com`, `evilhf.co`, `hf.co.evil.com` et `http://huggingface.co` sont refusés ;
  - toute autre redirection est un échec réseau, sans requête vers l'adresse refusée.
  La chaîne réelle de redirections de la révision choisie est relevée à l'implémentation et consignée dans la PR.
- **Pourquoi pas d'ADR** : RM1 admet déjà le téléchargement du modèle comme seul accès réseau, et l'ADR-001 fixe déjà la source (révision Hugging Face épinglée, empreinte vérifiée). Cette spec précise les hôtes de ce même téléchargement ; elle n'ouvre pas d'autre accès. Toute autre destination exigerait un ADR.

### Requête (RM1, RM30)

- Une requête `GET` par hôte de la chaîne de redirections, sans corps, sans cookie, sans paramètre ajouté à l'URL, sans en-tête `Range` (un téléchargement repart toujours de zéro, RM26).
- En-têtes demandés par le téléchargeur à `ModelTransport`, et seulement eux : `User-Agent: Tidemark` (sans version ni identifiant) et `Accept-Encoding: identity`.
- Sur le fil, `dart:io` ajoute au moins `Host` (et peut-être `Content-Length: 0`). La liste exacte des en-têtes reçus est fixée par le test de `IoModelTransport` sur la boucle locale (CA31) : tout autre en-tête (`Cookie`, `Authorization`, `Range`, identifiant) le fait échouer.
- Aucune donnée de la personne, aucun identifiant d'appareil ou d'installation : la requête est la même sur tous les téléphones.

### Consentement et proposition (RM11, RM18, RM31)

- Le téléchargement ne commence que sur un appui de la personne sur « Télécharger le modèle (1,1 Go) » ou « Réessayer (1,1 Go) », après l'annonce de la taille. Aucune requête réseau avant.
- La proposition s'ouvre d'elle-même **une seule fois** : après l'enregistrement de la première entrée « en attente » (avec texte, sans détresse), si le modèle est absent. Après « Plus tard », elle ne revient plus d'elle-même ; la personne la retrouve dans les Réglages, et dans le détail d'une entrée en attente (spec 004).
- Le réseau n'est pas consulté (Wi-Fi ou données mobiles, RM18) : la proposition le dit en une phrase, sans bloquer.

### Pendant le téléchargement (RM26, RM32)

- Le téléchargement tourne tant que l'app est ouverte, y compris quand la personne revient à son journal. Il n'y a pas de téléchargement en arrière-plan du système : si l'app passe en arrière-plan, le système peut l'interrompre, et il repart alors de zéro (RM26). L'écran le dit.
- Il est écrit dans un fichier temporaire (`qwen2.5-1.5b-instruct-q4_k_m.gguf.part`), son empreinte calculée au fil de l'eau. Le fichier n'est renommé à son nom définitif qu'après vérification de l'empreinte et de la taille.
- Dossier : `Application Support/tidemark/models/`, exclu des sauvegardes comme la base (ADR-002) : 1,1 Go ne part ni dans iCloud ni dans Google Drive.
- Délai : aucun octet reçu pendant 30 s vaut échec réseau.
- Un seul téléchargement à la fois : un second appui, ou un retour sur la proposition, ne lance rien de plus.

### États du modèle

| État (`LocalModelStatus`) | Sens | Affichage |
| --- | --- | --- |
| `absent` | Aucun fichier vérifié sur le téléphone | Proposition, ou Échec si le dernier essai vient d'échouer |
| `downloading` | Transfert ou vérification en cours | Progression, puis Vérification |
| `ready` | Fichier vérifié, à son nom définitif | Prêt |

Transitions : celles du cahier des charges (« Statuts et transitions »). Un échec ou une annulation ramène à `absent` et efface le fichier temporaire. Au démarrage, l'état se déduit des fichiers : fichier définitif présent et de la bonne taille → `ready` ; sinon → `absent`. L'empreinte n'est pas recalculée au démarrage, mais avant la première lecture du fichier par le moteur (« Vérification avant le premier chargement »).

### Vérification avant le premier chargement ([ADR-004](../adr/004-integrite-du-moteur-et-du-modele.md), option E)

Le lecteur GGUF de llama.cpp est du code natif en C++ : un fichier modifié de même taille pourrait exploiter une faille de ce lecteur avec les droits de l'app. La taille ne suffit donc plus.

- **Une fois par lancement**, avant la première lecture du fichier par le moteur (étiquetage, spec 004, ou bilan, spec 006), `ModelDownloader.verifyBeforeFirstLoad()` recalcule le SHA-256 du fichier définitif et le compare à `ModelSource`. Le résultat juste est gardé en mémoire pour le reste du lancement : les chargements suivants ne recalculent rien.
- **Empreinte juste** : le modèle reste `ready`, le chargement peut avoir lieu.
- **Empreinte fausse, ou fichier illisible** : le fichier est effacé, le modèle repasse à `absent` (sans cause d'échec affichée, comme après CA32), et aucun chargement n'a lieu. La personne peut le retélécharger (CA23).
- **Autre erreur du calcul** (mémoire, isolat interrompu) : aucun chargement, le fichier est gardé, le modèle reste `ready`, et le calcul sera retenté au prochain chargement demandé. Rien n'est gardé en mémoire.
- **Fichier téléchargé pendant ce lancement** : déjà vérifié avant son renommage (CA14) ; il compte comme vérifié, sans nouveau calcul.
- **Hors du fil de l'interface** : le calcul tourne dans un isolat (`Isolate.run`), jamais sur le fil de l'interface : l'écran ne se fige pas. Deux demandes simultanées (étiquetage et bilan) partagent le même calcul.
- **Modèle effacé pendant le calcul** (suppression totale, spec 005) : le résultat est ignoré, le modèle reste `absent`.
- Coût : mesuré le 2026-10-16 sur un Mac M3, avec le calcul de l'app dans un isolat, sur un vrai fichier de 1,1 Go : 9,4 à 14,8 s (l'ADR-004 annonçait 6,7 à 7,0 s, mesurés sur un fichier creux, sans lecture du disque). Sur l'iPhone 15 Pro, **estimé** à 10 à 15 s, à mesurer au test humain, comme sur l'émulateur Android. Seule la première analyse (ou le premier bilan) du lancement est retardée d'autant. Le seuil de 10 s qui ferait passer à l'option F (calcul par la bibliothèque du système) sera probablement dépassé.
- **Calcul orphelin** : un arrêt de la file ou une suppression totale pendant le calcul n'attend pas sa fin (spec 004, CA37), mais l'isolat continue de lire le fichier, déjà délié, jusqu'au bout (une dizaine de secondes) ; la place n'est rendue qu'à la fin. Limite assumée.

## Critères d'acceptation

### Proposition

- CA1 : Étant donné le modèle absent et la proposition jamais affichée, quand la personne enregistre une entrée qui prend le statut « en attente », alors l'écran du modèle s'ouvre sur la proposition à la place de la liste, et la proposition est marquée comme affichée.
- CA2 : Étant donné le modèle absent et la proposition jamais affichée, quand la personne enregistre une entrée sans texte, ou une entrée qui ouvre l'écran d'aide (spec 002, texte ou série), alors la proposition ne s'ouvre pas : l'écran d'aide (ou la liste) s'affiche, et la proposition reste « jamais affichée ».
- CA3 : Étant donné la proposition déjà affichée une fois, le modèle `downloading` ou `ready`, ou le modèle `absent` après un échec récent (téléchargement lancé depuis les Réglages : l'écran s'ouvrirait sur l'échec), quand la personne enregistre une entrée « en attente », alors la liste s'affiche, sans proposition.
- CA4 : Étant donné la proposition, quand elle s'affiche, alors elle montre exactement les textes de la maquette, dont la taille « 1,1 Go » dans le texte et dans le bouton. La taille affichée est calculée depuis la taille exacte de `ModelSource`, en gigaoctets (10⁹ octets), arrondie au dixième le plus proche, avec une virgule ; si elle ne donne pas « 1,1 Go », c'est la constante qui fait foi, et les textes de la maquette suivent.
- CA5 : Étant donné la proposition, quand la personne touche « Plus tard » ou fait un geste de retour, alors la liste s'affiche, le modèle reste `absent`, et aucune requête réseau n'a eu lieu.
- CA6 : Étant donné l'app ouverte sans appui sur un bouton de téléchargement, quoi que fasse la personne (saisie, liste, détail, Réglages, écran d'aide), alors aucune requête réseau n'a lieu.

### Téléchargement

- CA7 : Étant donné la proposition, quand la personne touche « Télécharger le modèle (1,1 Go) », alors le modèle passe à `downloading`, l'écran passe à la progression, et `ModelTransport` reçoit une seule demande, vers l'URL de `ModelSource`, avec exactement les en-têtes `User-Agent: Tidemark` et `Accept-Encoding: identity`, sans en-tête `Range`.
- CA8 : Étant donné une réponse de redirection, quand elle arrive, alors l'app résout un `Location` relatif sur l'URL courante, puis suit la redirection avec la même requête si l'adresse est admise (« Hôtes ») : `https://cdn-lfs.huggingface.co/…`, `https://cas-bridge.xethub.hf.co/…`, `/api/resolve-cache/…`. Pour une adresse refusée (`https://huggingface.co.evil.com/…`, `https://evilhf.co/…`, `http://huggingface.co/…`, port explicite autre que 443) ou au-delà de 5 redirections, aucune requête ne part vers cette adresse et le téléchargement échoue avec la cause « réseau ».
- CA9 : Étant donné un téléchargement en cours, quand des octets arrivent, alors l'écran montre le pourcentage entier, arrondi à l'inférieur (« 28 % »), la barre de progression et « 312 Mo sur 1,1 Go » (mégaoctets de 10⁶ octets, arrondis à l'inférieur), mis à jour à chaque point de pourcentage au moins.
- CA10 : Étant donné un téléchargement en cours, quand un nouveau téléchargement est demandé (double appui, `start()` appelé de nouveau), alors aucune seconde requête ne part et la progression en cours continue ; pendant le téléchargement, ni les Réglages (CA23) ni le détail d'une entrée (spec 004) ne montrent de bouton de téléchargement.
- CA11 : Étant donné un téléchargement en cours, quand la personne touche « Revenir à mon journal » ou fait un geste de retour, alors la liste s'affiche et le téléchargement continue ; la section des Réglages montre sa progression (CA23).
- CA12 : Étant donné un téléchargement en cours, quand la personne touche « Annuler le téléchargement », alors une confirmation demande « Annuler le téléchargement ? », avec « Ce qui a déjà été téléchargé sera effacé. », « Annuler le téléchargement » et « Continuer » ; « Continuer » ferme la confirmation, le téléchargement continue.
- CA13 : Étant donné la confirmation, quand la personne confirme l'annulation, alors le transfert s'arrête, le fichier temporaire est effacé, le modèle repasse à `absent` et la liste s'affiche.

### Vérification

- CA14 : Étant donné tous les octets reçus, quand le transfert se termine, alors l'écran passe à « Vérification du fichier… » (sans bouton d'annulation) ; si l'empreinte SHA-256 et la taille sont celles de `ModelSource`, le fichier est renommé à son nom définitif, le modèle passe à `ready` et l'écran à l'état « Prêt ».
- CA15 : Étant donné un fichier reçu dont l'empreinte diffère de `ModelSource`, quand la vérification se termine, alors le fichier est effacé, le modèle repasse à `absent` et l'écran montre l'échec « Le fichier reçu n'est pas le bon ».
- CA16 : Étant donné un serveur qui envoie plus d'octets que la taille de `ModelSource`, quand la taille est dépassée, alors le transfert s'arrête aussitôt et l'échec est celui de CA15 ; s'il en envoie moins avant de fermer la connexion, l'échec est « réseau » (CA17).

### Échecs (RM26)

- CA17 : Étant donné un téléchargement en cours, quand la connexion échoue, que le serveur répond autre chose que 200 (hors redirection, CA8) ou qu'aucun octet n'arrive pendant 30 s, alors le fichier temporaire est effacé, le modèle repasse à `absent` et l'écran montre l'échec « Le téléchargement s'est interrompu ».
- CA18 : Étant donné une erreur d'écriture du fichier (stockage plein, dossier inaccessible), quand elle survient, alors le transfert s'arrête, le fichier temporaire est effacé, le modèle repasse à `absent` et l'écran montre l'échec « Pas assez de place sur le téléphone ».
- CA19 : Étant donné un échec, quand l'écran s'affiche, alors il montre exactement le bandeau de la maquette pour sa cause (titre en `danger`, phrase en `ink`), la phrase « Rien n'a été gardé : le téléchargement repartira de zéro. », « Réessayer (1,1 Go) » et « Plus tard ».
- CA20 : Étant donné l'échec, quand la personne touche « Réessayer (1,1 Go) », alors un nouveau téléchargement part de zéro, comme en CA7 (aucun en-tête `Range`) ; « Plus tard » ramène à la liste.

### Démarrage

- CA21 : Étant donné un fichier temporaire laissé par un téléchargement interrompu (app fermée, téléphone éteint), quand l'app démarre, alors il est effacé et le modèle est `absent` ; aucun téléchargement ne reprend de lui-même et la proposition ne s'ouvre pas.
- CA22 : Étant donné le fichier définitif présent, quand l'app démarre, alors le modèle est `ready` s'il a la taille de `ModelSource` ; sinon il est effacé et le modèle est `absent`.
- CA32 : Étant donné le modèle `ready` qui ne peut pas être chargé par l'analyseur (spec 004), quand `ModelDownloader.verifyAfterLoadFailure()` est appelé, alors l'empreinte du fichier est recalculée une fois : fausse, le fichier est effacé et le modèle repasse à `absent` (la personne peut le retélécharger) ; juste, le modèle reste `ready`.
- CA34 : Étant donné le modèle `ready` au démarrage (CA22), quand `verifyBeforeFirstLoad()` est appelé pour la première fois du lancement, alors l'empreinte du fichier est recalculée : juste, il rend `true` et le modèle reste `ready` ; fausse (fichier de la bonne taille, contenu modifié) ou fichier illisible, il rend `false`, le fichier est effacé et le modèle repasse à `absent`, sans cause d'échec. Avec un modèle `absent` ou `downloading`, il rend `false` sans rien calculer.
- CA35 : Étant donné une première vérification juste, quand `verifyBeforeFirstLoad()` est appelé de nouveau pendant le même lancement, alors il rend `true` sans recalculer l'empreinte ; deux appels simultanés ne font qu'un seul calcul ; un modèle téléchargé et vérifié pendant le lancement (CA14) rend `true` sans nouveau calcul. Après `deleteModel()`, ou si le modèle est effacé pendant le calcul, il rend `false` et le modèle reste `absent`. Une erreur du calcul autre qu'un fichier illisible rend `false`, garde le fichier et le modèle `ready`, et l'appel suivant recalcule.
- CA36 : Étant donné le calcul de l'empreinte d'un fichier, quand il tourne, alors il s'exécute dans un isolat : pendant le calcul d'un fichier de plusieurs dizaines de mégaoctets, le fil principal continue de traiter ses événements (un minuteur périodique s'y déclenche) ; le même calcul sert à `verifyAfterLoadFailure()` (CA32).

### Réglages

- CA23 : Étant donné l'écran Réglages, quand il s'affiche, alors la section « Analyse sur le téléphone » montre la ligne « Modèle d'analyse » selon l'état du modèle, avec les textes de la maquette : `absent`, « Non téléchargé · 1,1 Go » et le bouton « Télécharger le modèle (1,1 Go) » ; `downloading`, « Téléchargement : 28 % », une barre et le lien « Voir le téléchargement » ; `ready`, « Prêt · 1,1 Go sur ton téléphone ». L'état se met à jour sans quitter l'écran.
- CA24 : Étant donné la ligne « Modèle d'analyse », quand la personne touche « Télécharger le modèle (1,1 Go) », alors l'écran du modèle s'ouvre sur la proposition (le téléchargement ne commence pas sans elle, RM11) ; quand elle touche « Voir le téléchargement », il s'ouvre sur la progression.

### Seul accès réseau (RM1)

- CA25 : Étant donné le code de l'app, quand les tests s'exécutent, alors aucun fichier de `lib/` hors de `lib/model/` n'utilise `HttpClient`, `HttpRequest`, `Socket`, `RawSocket`, `SecureSocket`, `WebSocket`, `InternetAddress`, `Image.network`, `NetworkImage`, `package:http` ni `package:dio` ; `url_launcher` n'est admis qu'avec un schéma `tel:` (écran d'aide, spec 002). Un garde-fou de `test/guards/` le vérifie, contrôlé par mutation.
- CA33 : Étant donné une PR qui ajoute une dépendance directe à `pubspec.yaml`, quand elle est relue, alors sa description dit si le paquet ouvre une connexion réseau ; un paquet qui en ouvre une, hors du téléchargement du modèle, exige un ADR (RM1). Limite assumée : depuis que la permission `INTERNET` est dans le manifeste principal, le garde-fou de CA25 ne voit pas le code des dépendances.
- CA26 : Étant donné l'app installée, quand le système sauvegarde le téléphone, alors le dossier du modèle n'est pas inclus dans la sauvegarde (ADR-002).
- CA31 : Étant donné `IoModelTransport` face à un `HttpServer` lancé par le test sur la boucle locale (`127.0.0.1`, rien ne sort du poste), quand il fait une demande, alors le serveur reçoit un `GET` sans corps dont les en-têtes sont exactement la liste fixée par le test (`host`, `user-agent: Tidemark`, `accept-encoding: identity`, et ce que `dart:io` ajoute sans identifiant), sans cookie ; et une réponse 302 est rendue au téléchargeur sans être suivie par le client HTTP.
- CA27 : Étant donné `ModelSource`, quand les tests s'exécutent, alors son URL est en `https`, sur l'hôte `huggingface.co`, avec un commit de 40 caractères hexadécimaux dans le chemin (jamais `main`), son empreinte compte 64 caractères hexadécimaux et sa taille est positive.

### Accessibilité et thème

- CA28 : Étant donné la progression, quand un lecteur d'écran la parcourt, alors la barre s'annonce « Téléchargement du modèle, 28 % », et chaque changement d'état (vérification, prêt, échec) est annoncé (`status`, ou `alert` pour un échec).
- CA29 : Étant donné la taille de texte du système à 200 %, quand l'écran du modèle et la section des Réglages s'affichent, alors aucun texte n'est tronqué ni ne déborde ; l'écran défile et ses boutons restent atteignables.
- CA30 : Étant donné le thème sombre du système, quand l'écran du modèle et la section des Réglages s'affichent, alors ils utilisent les couleurs du thème sombre de la charte.

## Données

Fixées par cette spec, puis reportées dans l'architecture technique avec l'implémentation.

- **Source** (`ModelSource`, `lib/model/model_source.dart`) : URL, empreinte SHA-256, taille en octets, hôtes admis (`huggingface.co`, suffixes `.huggingface.co` et `.hf.co`), nom du fichier.
- **État** (`LocalModelStatus`) : `absent`, `downloading`, `ready`. L'état complet exposé aux écrans est une classe scellée `ModelState` : `ModelAbsent` (avec la cause du dernier échec, `DownloadFailure` : `network`, `checksum`, `storage`, ou rien), `ModelDownloading` (octets reçus, taille attendue, vérification en cours ou non), `ModelReady` (chemin du fichier).
- **Téléchargement** (`ModelDownloader`, `lib/model/model_downloader.dart`) : interface.
  - `Stream<ModelState> watch()` ; `Future<void> start()` (sans effet si un téléchargement tourne) ; `Future<void> cancel()` ; `Future<void> checkAtStartup()` (CA21, CA22) ; `Future<void> deleteModel()` (pour la suppression totale du lot H).
  - Implémentation `HttpModelDownloader` : calcule l'empreinte au fil de l'eau (`package:crypto`, déjà présent comme dépendance transitive, à déclarer en dépendance directe et à justifier dans la PR), et passe par une interface de transport.
  - `FakeModelDownloader` dans `test/support/`, pour les écrans.
- **Transport** (`ModelTransport`) : `get(Uri url, Map<String, String> headers)` rend le statut HTTP, l'en-tête `Location` et un flux d'octets. Implémentation `IoModelTransport` sur `dart:io` `HttpClient`, avec `followRedirects = false` (l'app suit les redirections elle-même, CA8), `autoUncompress = false`, sans cookie ni proxy ajouté, et `userAgent` remplacé par `Tidemark`. `FakeModelTransport` dans `test/support/` pour tous les tests du téléchargeur : **aucune requête vers Internet dans les tests**. Seul le test de `IoModelTransport` (CA31) ouvre une connexion, vers un serveur local lancé par le test sur `127.0.0.1`. Les tests utilisent un dossier temporaire du système de fichiers.
- **Vérification après échec de chargement** : `ModelDownloader.verifyAfterLoadFailure()` (CA32), appelée par la file d'analyse (spec 004).
- **Vérification avant le premier chargement** : `Future<bool> ModelDownloader.verifyBeforeFirstLoad()` (CA34 à CA36), appelée par la file d'analyse (spec 004) et par la mise en mots du bilan (spec 006) avant toute lecture du modèle par le moteur. Le SHA-256 est calculé par `sha256OfFile(String path)` (`lib/model/model_downloader.dart`), dans un isolat ; `HttpModelDownloader` reçoit ce calcul en paramètre, pour que les tests le remplacent.
- **Réglages** (`SettingsRepository`, spec 002) : nouvelle valeur « proposition du modèle déjà affichée » (`watchModelOfferShown`, `setModelOfferShown`), colonne ajoutée à la table `settings` par une migration (version suivante du schéma). Effacée avec la base à la suppression totale (lot H).
- **Android** : la permission `android.permission.INTERNET` passe dans le manifeste principal (`android/app/src/main/AndroidManifest.xml`) ; elle n'était jusqu'ici que dans les manifestes de débogage et de profil. Elle ne sert qu'à `IoModelTransport` (CA25).
- **iOS** : aucune exception ATS : tout est en HTTPS.

## Maquette

Artefact Claude de type « Design » ([lien privé](https://claude.ai/artifact/UWcB9nLPntAx9rUt8XrKwL)), construit sur la charte. La copie versionnée, qui fait foi, est dans [`docs/maquettes/003-telechargement-du-modele/`](../maquettes/003-telechargement-du-modele/).

Écrans, chacun en clair et en sombre :

- **Écran du modèle** : proposition, progression, confirmation d'annulation, vérification, échec (réseau, fichier faux, place), prêt.
- **Réglages** : section « Analyse sur le téléphone » avec le modèle absent, en téléchargement et prêt ; la section « Écran d'aide » de la spec 002 suit, inchangée.

Il n'y a pas d'état vide (le contenu de la proposition est fixe) ; la progression et la vérification sont les états de chargement, l'échec l'état d'erreur. L'état « chargement » des Réglages est celui de la spec 002 (titre seul).

Captures PNG : absentes, comme pour les maquettes 001 et 002 ; à exporter depuis l'artefact (dette à suivre dans une issue, à créer avec l'accord de Yanis). En attendant, la copie HTML de `docs/maquettes/` fait foi.

Jetons manquants, à ajouter à la charte, à `tokens.json` et au test de fidélité dans la PR d'implémentation : `progress-height` (8, hauteur de la barre de progression), en plus de `icon-md` (24) et `icon-button` (18) déjà demandés par la spec 002. La barre utilise `tide` sur un fond `tide-soft`, déjà dans la charte.

## Cas limites et erreurs

- Téléphone sans réseau au moment de l'appui : échec « réseau » (CA17), sans attendre 30 s si la connexion est refusée tout de suite.
- Passage du Wi-Fi aux données mobiles en cours de route : si la connexion tient, le téléchargement continue ; sinon, échec « réseau » et reprise de zéro (RM26).
- App mise en arrière-plan : le système peut suspendre le transfert ; au retour, le délai de 30 s sans octet déclenche l'échec « réseau ». L'écran de progression prévient avant (« Garde Tidemark ouvert… »).
- App fermée ou téléphone éteint pendant le téléchargement : CA21 au démarrage suivant.
- Fichier définitif effacé par le système ou à la main : CA22, l'état redevient `absent`.
- Fichier définitif modifié sans changer de taille (appareil rooté ou jailbreaké, conteneur d'une version de développement remplacé, stockage corrompu) : refusé avant tout chargement (CA34), effacé, modèle `absent`. Un remplacement entre la vérification et le chargement, ou entre deux chargements du même lancement (après une libération du modèle, ou pour un bilan), passerait : il exige un accès en écriture au conteneur pendant que l'app tourne, c'est-à-dire un appareil déjà compromis, hors du modèle de menace (ADR-004). Limite assumée, signalée par la revue de sécurité du 2026-10-16.
- Révision Hugging Face supprimée ou fichier déplacé : échec « réseau » (404). Il faudra une nouvelle version de l'app avec une nouvelle `ModelSource`. Limite écrite dans le README (lot J).
- Serveur compromis qui sert un autre fichier : refusé par l'empreinte (CA15), quel que soit l'hôte.
- Stockage plein : détecté seulement à l'écriture (CA18), sans vérification préalable de la place libre, qui demanderait un paquet natif de plus.

## Hors périmètre

- Analyse des entrées et affichage des étiquettes : [spec 004](004-etiquetage-automatique.md).
- Suppression du modèle par la personne, seule ou avec la suppression totale : lot H (`deleteModel` est prévu ici, l'écran non).
- Mise à jour du modèle vers une autre version, choix entre plusieurs modèles.
- Téléchargement en arrière-plan du système (`URLSession` en arrière-plan, `WorkManager`), reprise d'un téléchargement interrompu (RM26), miroir hors de Hugging Face.
- Choix « Wi-Fi seulement » : la proposition le conseille, sans le vérifier (RM18).

## Questions ouvertes

Aucune. Décisions prises par l'agent, à la demande de Yanis (2026-10-14) :

1. **Un seul fournisseur plutôt qu'un seul hôte** : Hugging Face redirige vers son stockage ; les redirections sont suivies par l'app, seulement vers `huggingface.co`, `*.huggingface.co` et `*.hf.co`, en HTTPS (RM30).
2. **Proposition automatique une seule fois**, puis accès par les Réglages et le détail d'une entrée en attente : pas de relance répétée sur un sujet sensible (RM31).
3. **Confirmation avant l'annulation** : un appui malheureux ne doit pas coûter un gigaoctet de forfait (CA12).
4. **Retour au journal pendant le téléchargement**, sans téléchargement en arrière-plan du système : plus simple, sans paquet natif ; la limite est dite à l'écran (RM32).
5. **Empreinte vérifiée une fois**, avant le renommage, et pas à chaque démarrage : la taille suffit ensuite (CA22). Recalculer 1,1 Go à chaque lancement coûterait plusieurs secondes. **Révisée le 2026-10-16** (décision n° 11) : la taille suffit pour l'état affiché au démarrage, plus pour le chargement.
6. **Pas de vérification de la place libre** avant le téléchargement : l'erreur d'écriture est traitée (CA18).
7. **URL, commit et empreinte** fixés à l'implémentation et vérifiés par CA27 et par un téléchargement manuel consigné dans la PR : ils ne figurent pas dans l'ADR-001.
8. **Hôtes admis précisés** après la revue IA de la PR #18 : `Location` relatif résolu, suffixes `.huggingface.co` et `.hf.co` comparés point compris ; pas d'ADR, la source étant déjà fixée par RM1 et l'ADR-001.
9. **Fichier `ready` mais impossible à charger** : empreinte recalculée une fois, effacement si elle est fausse (CA32).
10. **Test de `IoModelTransport` sur la boucle locale** admis (CA31) : c'est le seul moyen de vérifier ce qui part réellement sur le fil.
11. **Empreinte recalculée une fois par lancement, avant le premier chargement** (agent, par délégation de Yanis, 2026-10-16, en application de l'[ADR-004](../adr/004-integrite-du-moteur-et-du-modele.md) accepté par Yanis le 2026-10-16, option E) : le lecteur GGUF de llama.cpp ne lit jamais un fichier non vérifié pendant le lancement (CA34 à CA36). Calcul dans un isolat, résultat gardé en mémoire pour le lancement, partagé entre étiquetage et bilan ; un fichier téléchargé pendant le lancement compte comme vérifié. Empreinte fausse : fichier effacé et modèle `absent`, comme CA32. Une erreur du calcul qui n'est pas une lecture impossible ne fait pas effacer 1,1 Go : le chargement est seulement refusé. Passage au calcul par la bibliothèque du système (option F) seulement si la mesure sur l'iPhone dépasse 10 s.
