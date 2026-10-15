# ADR-004 : Intégrité du moteur natif et du modèle

Statut : proposé (agent, 2026-10-15), à accepter par Yanis
Date : 2026-10-15

Contexte : l'analyse des entrées passe par `llamadart` 0.12.0 (ADR-001), qui exécute llama.cpp, du code natif en C++, dans le processus de l'app. Ce code a les mêmes droits que Tidemark : il peut lire la clé de la base dans le trousseau ou le Keystore, le journal déchiffré, et ouvrir une connexion : sur Android, la permission `INTERNET` existe pour le téléchargement du modèle ; sur iOS, aucune permission n'est nécessaire. Le garde-fou de `test/guards/` (aucun `HttpClient` hors de `lib/model/`) ne lit que le Dart : il ne voit rien du code natif. Le modèle GGUF de 1,1 Go est lu par le même code natif. Deux constats de la relecture du 2026-10-15 montrent que ni le binaire natif ni le modèle ne sont vérifiés au moment où ils comptent.

Le journal de la branche `feat/etiquetage` et la description de la PR #23 affirmaient que le hook de `llamadart` télécharge llama.cpp « avec une empreinte SHA-256 épinglée ». C'est faux pour llama.cpp (constat 1). L'affirmation vient sans doute du hook de `sqlite3` 3.7.1, qui, lui, vérifie bien l'empreinte de SQLite3MultipleCiphers au téléchargement et à chaque réutilisation du cache (`lib/src/hook/asset_hashes.dart`, `lib/src/hook/compile/description.dart`, l. 201 à 276) : le commentaire de `pubspec.yaml` qui le dit est exact, mais il laissait croire que tous les binaires natifs de l'app sont vérifiés. La rectification est consignée dans le journal de la branche `docs/chaine-approvisionnement-et-suivi-004`.

## Constats

### 1. Le binaire de llama.cpp est téléchargé sans contrôle d'empreinte

Lu dans `~/.pub-cache/hosted/pub.dev/llamadart-0.12.0/hook/build.dart` :

- `_acquireBundleDirectory` (l. 1610 à 1731) construit le nom `llamadart-native-<bundle>-v0.6.0-2.tar.gz` (tag `llamaCppTag` de `lib/src/hook/native_release_pins.dart`), puis appelle `_downloadReleaseAsset` (l. 1709, définie l. 2129) qui télécharge `https://github.com/leehack/llamadart-native/releases/download/v0.6.0-2/<archive>`. L'archive est ensuite extraite et seule la présence des bibliothèques attendues est contrôlée (`_isBundleLayoutCompatible`). Aucune empreinte.
- Les autres moteurs du même hook sont épinglés : LiteRT-LM (`_verifyLiteRtLmArchiveChecksum`, l. 1277 à 1300, empreintes dans `native_release_pins.dart`) et stable-diffusion (`_stableDiffusionArchiveMatchesPin`, l. 1053 à 1094). llama.cpp, le seul moteur que Tidemark utilise, est l'exception.
- L'archive est mise en cache dans `~/.pub-cache/hosted/pub.dev/llamadart-0.12.0/.dart_tool/llamadart/native_bundles/v0.6.0-2/<bundle>/`, partagé par tous les projets du poste, et réutilisée ensuite sans vérification.
- La release `v0.6.0-2` de `leehack/llamadart-native` n'est **pas immuable** (`gh api repos/leehack/llamadart-native/releases/tags/v0.6.0-2` : `"immutable": false`) : un asset peut y être remplacé sous le même nom, par le mainteneur ou par quiconque obtient ses droits.

Risque : une archive remplacée produirait une app qui embarque un binaire natif arbitraire, signé avec le certificat de Yanis, capable de lire la clé et le journal puis de les envoyer. RM1 serait violée sans qu'aucune ligne de Dart ne change, et aucun test ne le verrait.

État observé le 2026-10-15 : les archives en cache sur le poste de Yanis correspondent aux empreintes publiées par GitHub pour la release (champ `digest` des assets, publiés le 2026-10-10) :

| Archive | Taille | SHA-256 |
| --- | --- | --- |
| `llamadart-native-android-arm64-v0.6.0-2.tar.gz` | 35 569 866 o | `e227f5b3b72fe7c2d727a18a3b9172f6e186a609422f14b2abbcc5e48f855d6e` |
| `llamadart-native-ios-arm64-v0.6.0-2.tar.gz` | 5 033 334 o | `3d709de622e218b4c9ea6e64a28ea9e00b4b6343953392635b9b4bd8961b773d` |
| `llamadart-native-ios-arm64-sim-v0.6.0-2.tar.gz` | 5 252 892 o | `d47edd9a71a601a4b5f68cf637042ad6734c8c39ebfa9f7a1e107c50c85143bd` |
| `llamadart-native-ios-x86_64-sim-v0.6.0-2.tar.gz` | 5 467 363 o | `052139c8c0166dae650db9faed4d59005574f19de3e9f945c65389666b5b2615` |
| `llamadart-native-macos-arm64-v0.6.0-2.tar.gz` | 5 264 256 o | `fc4bf705c40a8958881f5f5ca99531a6afe2fa86ee9600e78a744e90b0bdd92c` |

Cette concordance dit seulement que les archives n'ont pas changé depuis leur téléchargement sur le poste. Elle ne dit rien des bibliothèques réellement embarquées : le hook réutilise d'abord le dossier `extracted/` (l. 1640 à 1649) sans relire l'archive, et ce dossier n'a pas été comparé au contenu des archives. Les dates des assets (`created_at` le 2026-10-10 entre 16:10:39 et 16:10:58, `updated_at` une seconde plus tard au plus, release publiée à 16:11:27) n'indiquent aucun remplacement après la publication, sans le prouver. Les empreintes qui seraient écrites dans le dépôt reposent donc sur la confiance accordée à ce premier téléchargement. La release ne publie pas d'attestation de construction (`gh api repos/leehack/llamadart-native/attestations/sha256:e227…` : 404), qui aurait permis de remonter à la compilation. Ces relevés ne protègent pas les constructions suivantes.

### 2. Le modèle n'est vérifié qu'après un échec de chargement

- Au téléchargement, l'empreinte SHA-256 est vérifiée avant le renommage du fichier (spec 003).
- Au démarrage, `HttpModelDownloader.checkAtStartup` (`lib/model/model_downloader.dart`, l. 313 à 328) ne contrôle que la taille (l. 318) avant de déclarer le modèle prêt.
- L'empreinte n'est recalculée que par `verifyAfterLoadFailure` (l. 343 à 359), appelée par `AnalysisQueue` quand `prepare()` a déjà échoué.

Le lecteur GGUF de llama.cpp, écrit en C++, lit donc un fichier non vérifié. Un fichier modifié de même taille, conçu pour exploiter une faille de ce lecteur, s'exécuterait avec les droits de l'app.

Vecteurs réalistes, à nuancer : le dossier `Application Support/tidemark/` est exclu des sauvegardes iCloud et Finder sur iOS (`AppDelegate.swift`) et toute donnée de l'app est exclue des sauvegardes et transferts sur Android (`data_extraction_rules.xml`) : une sauvegarde modifiée puis restaurée ne ramène donc pas le modèle. Restent un appareil rooté ou jailbreaké, l'accès au conteneur d'une app signée en développement (« Replace Container » de Xcode, `adb run-as` sur une version débogable) et la corruption du stockage. Le risque est faible pour la personne visée.

Ce comportement est un choix validé, pas un oubli : la spec 003 (l. 69 et décision 5, l. 188) vérifie l'empreinte une fois, avant le renommage, et pas à chaque démarrage, parce que « recalculer 1,1 Go à chaque lancement coûterait plusieurs secondes » ; la spec 004 (l. 113, CA15) ne recalcule l'empreinte qu'après un échec de chargement. Ce choix a été fait sans regarder le lecteur GGUF comme une surface d'attaque. L'option E ci-dessous le remet en cause, coût mesuré à l'appui.

### 3. Constats annexes

- **LiteRT-LM embarqué sans usage** : sans `llamadart_native_runtimes`, le hook retient `llama_cpp` et `litert_lm` (`defaultNativeRuntimes`, `lib/src/hook/native_bundle_config.dart`, l. 85 à 88). Tidemark n'utilise que `llama_cpp`. Sur le poste, l'archive LiteRT-LM n'a été téléchargée que pour `macos-arm64` ; sa présence dans l'APK et l'IPA n'est pas vérifiée. Tout code natif embarqué sans usage est de la surface d'attaque et de la taille en plus.
- **Code exécuté à la construction** : le hook `build.dart` de chaque dépendance s'exécute sur le poste et en CI avec les droits de l'utilisateur, avant tout contrôle d'empreinte. Seul `pubspec.lock` (version et `sha256` de chaque paquet) le verrouille ; d'où la relecture du hook à chaque montée de version (« Conséquences »).
- **Failles connues figées** : épingler un binaire fige aussi ses failles. Le commit de llama.cpp inclus dans `v0.6.0-2` est à relever, et ses avis de sécurité à suivre ; l'option E ci-dessous protège contre un modèle modifié, pas contre une faille du lecteur GGUF exploitée par le modèle d'origine.
- **Journaux natifs** : le niveau natif vaut déjà `none` par défaut (`lib/src/core/llama_logging.dart`, l. 55) et Tidemark ne le change pas. `setNativeLogLevel` est dépréciée au profit de `LlamaLogging.configure(level:, nativeLevel:)`. Un appel explicite protégerait contre un changement de valeur par défaut dans une version future, sans plus.

## Exigences

- **Aucun binaire natif non vérifié** dans une app construite, sur le poste de Yanis comme en CI.
- **Aucune lecture du modèle par llama.cpp avant vérification de son empreinte**, au moins une fois par lancement.
- **Aucun effet visible pour la personne** au-delà d'un délai de la première analyse ; l'analyse reste en arrière-plan.
- **Testable en CI sans vrai modèle** (`FakeMoodAnalyzer`, `FakeModelDownloader`).
- Lancement en 3 commandes conservé, ou une seule commande de plus, documentée.

## Options envisagées pour le moteur

- **A. Archive versionnée et vérifiée, passée par `hooks.user_defines.llamadart.llamadart_native_path`** : un script du dépôt (par exemple `scripts/fetch-llama-native.sh`) télécharge l'archive de chaque cible utile (`android-arm64`, `ios-arm64`, `ios-arm64-sim`, `ios-x86_64-sim` : la construction pour le simulateur iOS prend les deux architectures) pour le tag `v0.6.0-2`, compare son SHA-256 aux valeurs écrites dans le dépôt, refuse en cas d'écart, et la dépose dans un dossier ignoré par Git. `pubspec.yaml` pointe `llamadart_native_path` vers ce dossier : le hook prend alors la branche `_acquireLocalBundleDirectory` (l. 1778) et ne télécharge plus rien. La CI lance le même script. Les empreintes sont écrites dans le dépôt, pas lues dans la release : c'est plus strict que l'installation actuelle de gitleaks dans `garde-fous.yml`, qui télécharge `checksums.txt` depuis la même release que l'archive et ne protège donc que contre une corruption en transit (point séparé, hors de cet ADR). Conditions pour que A tienne :
  - **le dossier ne contient que les archives**, sous leur nom exact : `_acquireLocalBundleDirectory` cherche d'abord un dossier de bibliothèques (l. 1800 à 1816, parcours récursif l. 1992) et l'utiliserait sans contrôle ; le script refuse tout `.so`, `.dylib` ou `.framework` présent ;
  - **le script revérifie les archives présentes à chaque lancement** (51 Mo, moins d'une seconde), pas seulement au téléchargement, sinon le dossier reproduit le défaut du cache de pub ;
  - **les cibles de l'hôte sont couvertes** : `flutter test` déclenche peut-être le hook pour `linux-x64` (CI) et `macos-arm64` (poste). Si c'est le cas, le chemin local doit aussi les fournir, sinon la CI échoue (l. 1837) ou retombe sur un téléchargement non vérifié. À vérifier avant d'accepter l'ADR.

  - **limite** : la vérification ne tient que si le script est lancé ; un `flutter run` sans lui utilise le dossier tel quel. Une vérification à la construction (phase de build Xcode, tâche Gradle) fermerait ce trou, au prix de code de build sur deux plateformes ; à défaut, limite acceptée et écrite dans le README.

  Ces conditions remplies, A couvre iOS, Android et l'hôte, sur le poste de Yanis comme en CI. Coûts : une commande de plus avant `flutter run`, des empreintes à mettre à jour à chaque montée de version de `llamadart`, et un hook qui échoue si le dossier manque (message à rendre clair dans le README). Les binaires ne sont pas committés : 51 Mo pour les quatre cibles mobiles.
- **B. Vérification des empreintes en CI seulement** : un job calcule le SHA-256 des archives du cache après `flutter build` et le compare aux valeurs du dépôt. Simple, mais la CI de Tidemark ne construit pas l'app pour iOS ni Android, et l'app installée sur l'iPhone est construite sur le poste de Yanis, dont le cache n'est jamais vérifié. Protège surtout la CI, pas l'app réelle. Écartée seule ; utile en complément de A pour vérifier que le hook n'a rien téléchargé d'autre. Attention au cache de la CI (`cache: true` de `subosito/flutter-action`, `flutter.yml`, l. 26) : s'il contient le cache de pub, un binaire téléchargé une fois sans contrôle peut y durer d'une exécution à l'autre ; B doit vérifier le contenu restauré, ou l'exclure.
- **C. Paquet compagnon iOS `llamadart_llama_cpp_flutter`** : quand l'app en dépend, le hook ne fournit plus llama.cpp sur iOS et laisse SwiftPM le faire ; le hook vérifie que le manifeste du compagnon épingle le tag `v0.6.0-2` et que son gabarit a l'empreinte attendue (`_validateAppleCompanion`, l. 682 à 805), et SwiftPM contrôle le `checksum` du `binaryTarget`. Une version publiée sur pub.dev ne change plus : l'empreinte est figée par la version du compagnon. Mais iOS seulement : Android reste sans contrôle, alors qu'il porte la plus grosse archive. Une dépendance de plus, non lue à ce jour. Écartée seule ; envisageable plus tard pour iOS si A pèse trop.
- **D. Statu quo documenté** : rien à faire, risque accepté et écrit dans le README. Contraire à l'esprit de RM1 pour un projet dont la preuve n° 2 est « une IA sur l'appareil, sans fuite de données ». Écartée.

## Options envisagées pour le modèle

- **E. SHA-256 une fois par lancement, avant le premier `prepare()`**, résultat gardé en mémoire pour la session : `ModelDownloader` gagne une vérification (par exemple `verifyBeforeFirstLoad`) appelée par `AnalysisQueue` avant le premier chargement ; empreinte fausse → fichier effacé et modèle `ModelAbsent`, comme `verifyAfterLoadFailure`. Calcul dans un isolat (`Isolate.run`) pour ne pas figer l'interface.
  - Coût mesuré le 2026-10-15 sur un Mac M3, Dart 3.13.5 compilé (`dart compile exe`), paquet `crypto` 3.0.7 déjà utilisé par l'app, fichier de 1 117 320 736 octets : **6,7 s, 6,7 s et 7,0 s** (159 à 167 Mo/s), lecture du disque négligeable (fichier creux). En comparaison, `openssl dgst -sha256`, qui utilise les instructions SHA du processeur, met 0,7 s.
  - Estimation pour l'iPhone 15 Pro (A17 Pro, cœurs de la même génération que le M3) : 7 à 10 s au moins, borne basse puisque la mesure s'est faite sur un fichier creux, sans lecture réelle ; s'y ajoute la lecture de 1,1 Go depuis le stockage. Cette lecture remplit le cache du système, ce qui raccourcit le chargement qui suit (12 s au premier chargement, 0,3 s relancé, ADR-001). Sur l'émulateur Android, plus lent. **À mesurer au test humain**, sur l'iPhone et l'émulateur.
  - Effet pour la personne : la première étiquette d'un lancement arrive quelques secondes plus tard ; rien d'autre. Coût en batterie : une lecture complète du modèle par lancement où une analyse a lieu.
  - Limite : un fichier remplacé entre la vérification et le chargement passerait (temps de contrôle à temps d'usage). Il faudrait pour cela un accès en écriture au conteneur pendant que l'app tourne, hors du modèle de menace retenu.
- **F. Même vérification, mais par la bibliothèque du système** (CommonCrypto sur iOS, `MessageDigest` sur Android) : environ dix fois plus rapide d'après l'écart mesuré avec `openssl`, mais du code natif à écrire sur deux plateformes, ou un paquet de plus. À garder si la mesure de E dépasse 10 s sur l'iPhone.
- **G. Vérification au démarrage seulement si la date de modification a changé** : rapide, mais la date se modifie aussi facilement que le fichier. Écartée.

## Décision

Proposition de l'agent (2026-10-15), à trancher par Yanis :

1. **Moteur : option A**, avec le contrôle de B en CI. C'est la seule option qui couvre l'app réellement installée sur l'iPhone et Android, sans dépendance nouvelle. Le surcoût est une commande de plus, que le README rend explicite, et une liste de trois empreintes à mettre à jour à chaque montée de version de `llamadart` (montée déjà soumise à relecture par l'ADR-001).
2. **Modèle : option E**, mesurée au test humain ; passage à F seulement si la mesure le justifie.
3. **`llamadart_native_runtimes: llama_cpp`** dans `pubspec.yaml` : un seul moteur natif embarqué.
4. **`LlamaLogging.configure(level: LlamaLogLevel.none)`** appelé une fois au démarrage de l'analyseur : niveau natif explicite, sans dépendre de la valeur par défaut.

Mise en œuvre : 1, 3 et 4 ne changent aucun comportement observable (PR `chore`, avec contrôle par mutation du script : une empreinte fausse doit faire échouer la construction). 2 change le comportement au démarrage et revient sur une décision validée : révision de la spec 003 (l. 69, décision 5, nouveau critère d'acceptation) et de la spec 004 (l. 113, CA15), validée par Yanis, puis des tests d'abord.

## Conséquences

- **Lancement** : `flutter pub get`, le script de récupération du moteur, puis `flutter run`. Le README le dira (lot J).
- **Montée de version de `llamadart`** : relire le hook (tag, dépôt, nouvelles cibles), mettre à jour les empreintes, vérifier qu'elles concordent avec le champ `digest` de la release GitHub.
- **En amont** : signaler à `leehack/llamadart` que llama.cpp est le seul moteur du hook sans empreinte épinglée, alors que LiteRT-LM et stable-diffusion en ont une. Une correction en amont rendrait l'option A inutile à la version suivante. Aucune issue ouverte sans l'accord de Yanis.
- **Première analyse de chaque lancement** retardée de quelques secondes (option E).
- **Contre-argument** : le risque de remplacement d'un asset GitHub reste rare, et le mainteneur pourrait aussi publier un binaire malveillant sous un nouveau tag. L'option A ne protège pas contre ce second cas, mais elle garantit que le binaire embarqué est celui qui a été relu et mesuré pendant le spike, et rend toute montée de version explicite.

### Incertitudes

- Présence de LiteRT-LM dans l'APK et l'IPA actuels : non vérifiée.
- Comportement du hook avec `llamadart_native_path` pour plusieurs cibles dans un même dossier : lu dans le code (`_localPathDirectoryCandidates`, `_localPathArchiveCandidates`), non essayé.
- Temps de hachage sur l'iPhone 15 Pro et l'émulateur Android : estimé, pas mesuré.
- `flutter test` déclenche peut-être le hook pour la machine hôte (archive `macos-arm64` présente dans le cache) : si c'est le cas, la CI télécharge déjà aujourd'hui une bibliothèque `linux-x64` non vérifiée à chaque exécution sans cache. À vérifier avant d'accepter l'ADR (condition de l'option A).

## Sources

- Code de `llamadart` 0.12.0 (`~/.pub-cache/hosted/pub.dev/llamadart-0.12.0/`) : `hook/build.dart` (l. 19, 682 à 805, 1053 à 1094, 1277 à 1300, 1610 à 1731, 1778 à 1870, 1985 à 1995, 2129 à 2145), `lib/src/hook/native_release_pins.dart`, `lib/src/hook/native_bundle_config.dart`, `lib/src/core/llama_logging.dart`, `README.md` (« native runtimes »).
- Code de `sqlite3` 3.7.1 (`~/.pub-cache/hosted/pub.dev/sqlite3-3.7.1/`) : `lib/src/hook/asset_hashes.dart`, `lib/src/hook/assets.dart` (l. 108 à 120), `lib/src/hook/compile/description.dart` (l. 201 à 276).
- Release GitHub : `gh api repos/leehack/llamadart-native/releases/tags/v0.6.0-2` (champs `immutable`, `digest`, `created_at`, `updated_at`, `published_at`) et `gh api repos/leehack/llamadart-native/attestations/sha256:<empreinte>`, relevés le 2026-10-15.
- Workflows de Tidemark : `.github/workflows/garde-fous.yml` (installation de gitleaks), `.github/workflows/flutter.yml` (cache).
- Code de Tidemark : `lib/model/model_downloader.dart`, `lib/analysis/analysis_queue.dart`, `ios/Runner/AppDelegate.swift`, `android/app/src/main/res/xml/data_extraction_rules.xml`.
- Mesure du hachage : programme Dart jetable hors du dépôt (`sha256.bind(file.openRead())`, comme `verifyAfterLoadFailure`), non versionné.
