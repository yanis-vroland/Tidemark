# Journal : chaîne d'approvisionnement du moteur et suivi de la spec 004

Branche `docs/chaine-approvisionnement-et-suivi-004`.

## 2026-10-15 15:21

### Fait

- ADR-004 « Intégrité du moteur natif et du modèle », au statut **proposé** : constats relus dans le code de `llamadart` 0.12.0 et de Tidemark, options comparées, recommandation (archive vérifiée passée par `llamadart_native_path`, contrôle en CI, empreinte du modèle avant le premier chargement de chaque lancement, `llamadart_native_runtimes: llama_cpp`, niveau de journal natif explicite).
- Constats vérifiés :
  - `hook/build.dart` de `llamadart` : `_acquireBundleDirectory` (l. 1610 à 1731) puis `_downloadReleaseAsset` (appel l. 1709, définition l. 2129) téléchargent l'archive de llama.cpp par son tag seul, sans empreinte ; LiteRT-LM (l. 1277 à 1300) et stable-diffusion (l. 1053 à 1094) sont épinglés ;
  - release `v0.6.0-2` de `leehack/llamadart-native` non immuable (`"immutable": false`) ; les archives en cache sur le poste concordent avec le champ `digest` de GitHub ;
  - `checkAtStartup` ne contrôle que la taille du modèle (`lib/model/model_downloader.dart`, l. 318) ;
  - niveau de journal natif déjà à `none` par défaut (`llama_logging.dart`, l. 55).
- Mesure du hachage SHA-256 d'un fichier de la taille du modèle (1 117 320 736 octets), Mac M3, Dart compilé, paquet `crypto` 3.0.7 : 6,7 s, 6,7 s, 7,0 s (159 à 167 Mo/s) ; `openssl` : 0,7 s. Programme jetable hors du dépôt, fichier effacé.
- `pubspec.yaml` : commentaire seulement, complété (voir « Corrections et limites »).
- Architecture technique : chaîne d'approvisionnement du code natif dans « Sécurité », construction dans « Infrastructure », `AnalysisQueue` et `saveAnalysis` dans les contrats, ADR-004 dans l'index.
- Cahier des charges : spec 004 « implémentée (PR #23) », spec 001 « implémentée (PR #13) », CA31 à CA36 toujours en attente ; cinq points de la spec 004 tranchés par le code sans décision, reportés dans les questions ouvertes, avec le comportement actuel.
- Plan : validations cochées d'après les statuts réels (ADR-001 à 003, specs 001 à 006) ; tâche « Valider l'ADR-004 » ajoutée ; état réel des icônes et des captures de la charte ; deux frictions de la chaîne ajoutées.

### Décisions

- Aucune décision d'architecture prise : l'ADR-004 reste « proposé », à trancher par Yanis (agent).
- « Valider la charte » laissé non coché : aucune validation trouvée (consigne de l'agent principal).
- Statut de la spec 001 corrigé dans le même tableau que la 004 : elle est mergée depuis la PR #13, le tableau disait encore « spec validée » (agent).
- Doublons de la section « Sécurité » de l'architecture (« Réseau » et « Export » écrits deux fois, dont un « aucun accès réseau dans l'app à ce jour » devenu faux) non corrigés ici : les branches `feat/export-suppression` et `feat/bilan-semaine` touchent ces lignes. Signalé dans la PR (agent).

### Corrections et limites

- **Rectification du journal `2026-10-15-feat-etiquetage.md` et de la PR #23** (fichier mergé, non modifié) : l'entrée de 09:25 et la section « Dépendance » de la PR disent que le hook de `llamadart` télécharge llama.cpp « avec une empreinte SHA-256 épinglée ». C'est faux : seule la présence des bibliothèques est contrôlée (ADR-004, constat 1).
- **Commentaire de `pubspec.yaml`** : la consigne était de corriger « vérifié par empreinte », supposé faux. Vérification faite, il est exact : il parle de SQLite3MultipleCiphers, et le hook de `sqlite3` 3.7.1 vérifie bien son empreinte SHA-256, au téléchargement et à chaque réutilisation du cache (`lib/src/hook/compile/description.dart`, l. 201 à 276). Le commentaire est donc conservé et complété : le hook de `llamadart`, lui, ne vérifie rien (ADR-004).
- **Vecteur « sauvegarde iOS modifiée »** du modèle : peu réaliste, le dossier `Application Support/tidemark/` étant exclu des sauvegardes (iOS) et toute donnée de l'app exclue des sauvegardes et transferts (Android). Restent un appareil rooté ou jailbreaké, le conteneur d'une version de développement et la corruption du stockage. Nuancé dans l'ADR.
- Temps de hachage sur l'iPhone 15 Pro et l'émulateur Android : estimé, pas mesuré ; présence de LiteRT-LM dans l'APK et l'IPA : non vérifiée.
- Écart de chemin non corrigé (hors des sections de cette PR) : l'architecture cite `Application Support/tidemark/model/` dans le tableau des fichiers et `models/` ailleurs ; le code utilise `models/`.
- Revues `reviewer` et `security-reviewer` : à lancer par l'agent principal (ce subagent ne lance pas d'autre subagent).
- Test humain : sans objet (documentation seulement, aucun changement de comportement).

### Prochaine étape

1. Revue de la PR par Yanis ; décision sur l'ADR-004 (accepter, refuser ou amender).
2. Si accepté : PR `chore` pour le script de récupération vérifiée du moteur, `llamadart_native_runtimes` et le niveau de journal ; complément de la spec 003 pour l'empreinte du modèle au lancement, puis tests d'abord.
3. Réponses de Yanis aux questions ouvertes de la spec 004, puis report dans la spec.

## 2026-10-15 15:26

### Fait

- Revues lancées sur le premier commit : `reviewer` (aucun point bloquant, 8 à corriger) et `security-reviewer` (aucun point bloquant, 4 à corriger). L'entrée précédente, qui les disait « à lancer par l'agent principal », est dépassée.
- Corrections de l'ADR-004 :
  - comparaison avec l'installation de gitleaks retirée : `garde-fous.yml` lit `checksums.txt` dans la même release que l'archive, l'option A est plus stricte ;
  - conditions de l'option A : dossier limité aux archives (le hook préfère un dossier de bibliothèques, sans contrôle), revérification à chaque lancement du script, cibles de l'hôte (`linux-x64`, `macos-arm64`) à vérifier avant acceptation, cible `ios-x86_64-sim` ajoutée, limite du script non lancé ;
  - concordance des archives ramenée à ce qu'elle prouve (premier téléchargement, dossier `extracted/` non comparé) ; dates des assets et absence d'attestation relevées ;
  - constat 2 rattaché à la décision 5 de la spec 003 et au CA15 de la spec 004, que l'option E remet en cause ; mesure du hachage présentée comme borne basse ;
  - modèle de menace complété : code exécuté à la construction, failles figées par l'épinglage, iOS sans permission réseau, garde-fou réseau limité au Dart, cache de la CI.
- Architecture : phrase « Empreinte et taille vérifiées avant usage » corrigée ; détails de la chaîne d'approvisionnement ramenés à un renvoi vers l'ADR-004.
- Cahier des charges : délégation de la spec 004 expliquée, effet de l'échec d'écriture sur les entrées plus anciennes, CA28 recentré sur le détail, question déjà tranchée retirée.
- `flutter test` : 968 tests verts ; `dart analyze --fatal-infos` et `dart format` au vert (aucun code modifié).

### Décisions

- Aucune décision d'architecture : l'ADR-004 reste « proposé » (agent).
- Durcissement de l'installation de gitleaks (empreinte écrite dans le dépôt) : signalé dans la PR, hors de son périmètre (agent).

### Corrections et limites

- Suggestion non suivie : comparer le dossier `extracted/` au contenu des archives ; l'ADR l'écrit comme limite du constat.
- Restent non mesurés : temps de hachage sur l'iPhone et l'émulateur, présence de LiteRT-LM dans l'APK et l'IPA, déclenchement du hook par `flutter test`.

### Prochaine étape

Revue de la PR par Yanis ; décision sur l'ADR-004 ; réponses aux questions ouvertes de la spec 004.
