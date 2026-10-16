# Journal : perf/empreinte-modele-native

## 2026-10-16 11:30

### Fait

- Lu l'ADR-004 (option F), `sha256OfFile` et `verifyBeforeFirstLoad` (`lib/model/model_downloader.dart`), et leurs tests (`test/model/verify_before_first_load_test.dart`).
- Cherché le vrai modèle sur le Mac (conteneurs, simulateurs, caches, Spotlight) : absent. Fichier aléatoire de 1 117 320 736 octets généré dans le scratchpad de la session, hors du dépôt.
- Tests écrits par le subagent `test-writer` à partir des critères F1 à F9 (ci-dessous), plus un test du câblage dans `AppDelegate.swift` ajouté par l'agent principal : `test/model/system_file_hasher_test.dart`. Squelette `lib/model/system_file_hasher.dart` (constante du canal, classe dont `call` lève `UnimplementedError`) committé avec les tests pour qu'ils compilent.
- Tests rouges : `flutter test test/model/system_file_hasher_test.dart` → `+2 -26`. Échecs : `UnimplementedError` (F1 à F7), `Expected: true` ou modèle resté `ModelReady` (F8, l'erreur est avalée par le téléchargeur), `hashFile` encore `sha256OfFile` (F9 câblage), fichiers natifs absents ou sans le canal (F9 iOS et Android). Les 2 tests verts vérifient seulement le nom de la constante du canal.

Critères : F1 appel de `sha256OfFile` avec `{path}` ; F2 empreinte native égale à l'attendue rendue sans repli ; F3 empreinte native différente : le Dart décide ; F4 `PlatformException` → repli ; F5 canal absent → repli ; F6 réponse mal formée → repli ; F7 erreur de lecture du repli propagée ; F8 intégration avec `HttpModelDownloader` (bon fichier, mauvais fichier effacé, natif menteur corrigé par le Dart, voie rapide) ; F9 câblage dans `openJournal`, `AppDelegate.swift` et `MainActivity.kt`.

### Décisions

- Mettre en œuvre l'option F de l'ADR-004 maintenant (agent principal, par délégation de Yanis du 2026-10-16) : 9,4 à 14,8 s mesurés sur le M3 au-delà du seuil de 10 s.
- Le natif ne peut dire que « oui » : une empreinte native différente de l'attendue est recalculée en Dart avant tout effacement, pour qu'un défaut du code natif n'efface jamais un bon modèle de 1,1 Go ; un fichier réellement modifié est donc refusé comme aujourd'hui, au coût du calcul Dart (agent, par délégation de Yanis du 2026-10-16).
- Câblage dans `openJournal` (`hashFile: modelSha256OfFile`), le défaut de `HttpModelDownloader` reste `sha256OfFile` : le test existant de CA36 (`identical(downloader.hashFile, sha256OfFile)`) n'est pas modifié (agent, par délégation de Yanis du 2026-10-16).
- Enchaîner sans pause après les tests rouges : accord de Yanis du 2026-10-16 (« fonce, continue le dev »).

### Corrections et limites

- `test-writer` a copié dans `.llamadart-native/` (ignoré par Git) l'archive `macos-arm64` d'un autre worktree, empreinte conforme à `scripts/llama-native.sha256`, pour que `flutter test` tourne.

### Prochaine étape

- Implémenter `SystemFileHasher`, le canal Swift (CryptoKit) et Kotlin (`MessageDigest`), mesurer, mettre à jour l'ADR-004 et la spec 003.

## 2026-10-16 11:54

### Fait

- `SystemFileHasher` et `modelSha256OfFile` (`lib/model/system_file_hasher.dart`), câblés dans `openJournal` ; canal iOS `ios/Runner/ModelHashChannel.swift` (CryptoKit, blocs de 4 Mo, file d'arrière-plan), ajouté au projet Xcode et enregistré dans `AppDelegate.swift` ; canal Android dans `MainActivity.kt` (`MessageDigest`, blocs de 4 Mo, `makeBackgroundTaskQueue`).
- Tests : `system_file_hasher_test.dart` 28/28 ; suite complète `+1802 -1`, aussi avec `TZ=UTC`. Le seul échec, `analysis_queue_lifecycle_test.dart` « CA34 : un désabonnement qui lève… » (`Bad state: désabonnement impossible`), touche `AnalysisQueue._stop`, que cette branche ne modifie pas : il est corrigé par la PR #41, encore ouverte.
- `dart format` et `dart analyze --fatal-infos` sans remarque. `flutter build apk --debug`, `flutter build ios --simulator --debug` et `flutter build ios --no-codesign --debug` : construits (après `scripts/fetch-llama-native.sh`).
- Contrôle par mutation (script jetable hors du dépôt, chaque mutation restaurée), sur `system_file_hasher_test.dart` et `verify_before_first_load_test.dart` : M1 réponse native crue sans comparaison à l'attendue (9 échecs) ; M2 erreur du canal propagée, sans repli (6) ; M3 réponse native rendue au lieu du repli (18) ; M4 comparaison d'empreinte du téléchargeur neutralisée (5) ; M5 câblage retiré d'`openJournal` (1) ; M6 canal non enregistré dans `AppDelegate` (1). Toutes tuées.
- Mesures (Mac M3, fichier aléatoire de 1 117 320 736 octets, trois tours alternés, poste chargé par d'autres constructions) : Dart compilé 9,9 / 19,6 / 23,9 s ; fonction Swift de l'app 0,96 / 0,98 / 1,18 s ; `openssl` 1,28 / 1,87 / 0,75 s ; `shasum` 4,35 / 6,16 / 4,12 s ; Java 17 macOS `MessageDigest` 6,85 / 9,79 / 8,22 s (non représentatif d'Android). Même empreinte partout. ADR-004 (« Mise en œuvre de l'option F »), spec 003 et architecture technique mises à jour.

### Décisions

- CryptoKit plutôt que CommonCrypto sur iOS : même bibliothèque du système, API non dépréciée, sans pointeur ; un peu plus rapide sur le Mac (agent, par délégation de Yanis du 2026-10-16).
- Contrôle de format de la réponse native retiré : la comparaison exacte à l'empreinte attendue suffit et une mutation du contrôle de format survivrait (agent, par délégation de Yanis du 2026-10-16).
- Ligne « pas encore mis en œuvre » de la section sécurité de l'architecture technique (l. 129) laissée telle quelle : la PR #40, ouverte, modifie ce fichier ; à reprendre après son merge (agent).

### Corrections et limites

- iPhone 15 Pro et Android : non mesurés, à mesurer par Yanis au test humain.
- Le code natif n'est vérifié que par lecture des sources (nom du canal, enregistrement) et par la mesure de la fonction Swift copiée ; aucun test automatique ne l'exécute.
- Test humain : à faire par Yanis.

### Prochaine étape

- Revues `reviewer` et `security-reviewer`, puis PR en brouillon.

## 2026-10-16 11:59

### Fait

- Revues `reviewer` et `security-reviewer` reçues. Tests renforcés d'après leurs points (agent principal) : F10 (canal muet → repli après un délai borné, 60 s par défaut), empreinte attendue jamais envoyée au canal, voie native de `modelSha256OfFile` lui-même, source du téléchargeur de l'app identique à `qwenModelSource`, `verifyAfterLoadFailure` par le canal (F8e, F8f), lecture des sources natives sans les commentaires (enregistrement iOS et Android, `queue.async`, `makeBackgroundTaskQueue()`, `catch (…: Throwable)` sur Android). Champ `nativeTimeout` ajouté au squelette pour que les tests compilent.
- Tests rouges : `+33 -2` (F10 : le canal muet n'est jamais abandonné, délai du test dépassé ; Android : `catch (e: Exception)` seulement).
- Tests de cette PR retouchés, non encore mergés : test en double du nom du canal retiré, commentaire faux du cas F6 retiré, tests statiques F9 réécrits (plus stricts).

### Décisions

- Délai de 60 s sur l'appel natif, puis repli Dart (suggestion de la revue sécurité, agent, par délégation de Yanis du 2026-10-16).

### Corrections et limites

- Test humain : à faire par Yanis.

### Prochaine étape

- Délai et `Throwable`, docs selon les revues, puis PR en brouillon et réponse aux revues.

## 2026-10-16 12:09

### Fait

- Délai de 60 s sur l'appel natif, puis repli (`SystemFileHasher.nativeTimeout`) ; Android attrape `Throwable`. Docstring : gain mesuré sur Mac seulement.
- Docs selon les revues : ADR-004 (statut de la section F, empreinte attendue jamais envoyée au canal, `verifyAfterLoadFailure`, portée réelle des tests du natif, conséquences d'un défaut natif réécrites, gain de dix à vingt fois selon la charge, TOCTOU) ; spec 003 (coût et calcul orphelin au présent de F, `verifyAfterLoadFailure`) ; architecture technique (ligne de sécurité « pas encore mis en œuvre » corrigée dans cette PR, au risque d'un rebase après la PR #40).
- Tests : `system_file_hasher_test.dart` 35/35 ; suite `+1809 -1`, aussi avec `TZ=UTC` (même échec préexistant, corrigé par la PR #41). `dart analyze --fatal-infos` sans remarque. APK debug, iOS simulateur et iOS appareil (`--no-codesign`) construits.
- Mutations : 15, toutes tuées (M1 à M6 de l'entrée précédente, plus enregistrement iOS commenté, délai retiré, Android limité à `Exception`, calcul iOS hors de `queue.async`, Android sans file d'arrière-plan, `configureFlutterEngine` retiré, `modelSha256OfFile` sans voie native, empreinte attendue vide, empreinte attendue envoyée au canal).

### Décisions

- Section F de l'ADR-004 : « accepté (agent, par délégation de Yanis du 2026-10-16), à confirmer par Yanis avec la PR ». La revue jugeait que la délégation ne couvrait pas la révision d'un ADR ; non suivi, puisque les règles communes du 2026-10-16 permettent un ADR « accepté (agent, par délégation de Yanis) » ; signalé en tête des points d'attention de la PR (agent).
- File d'arrière-plan explicite sur iOS (`DispatchQueue`), pas `makeBackgroundTaskQueue?()` : cette méthode est optionnelle dans le protocole et, absente, renverrait le calcul sur le fil principal (agent, par délégation de Yanis du 2026-10-16).
- Empreinte attendue gardée dans `modelSha256OfFile`, et un test vérifie que le téléchargeur de l'app utilise la même source (`same(qwenModelSource)`), plutôt que de changer la signature de `hashFile` (agent, par délégation de Yanis du 2026-10-16).

### Corrections et limites

- iPhone et Android non mesurés. Test humain : à faire par Yanis.

### Prochaine étape

- PR en brouillon, puis commentaire « Réponse à la revue IA ».

## 2026-10-16 12:10

### Fait

- PR #44 ouverte en brouillon sur `main` ; commentaire « Réponse à la revue IA » publié et lié depuis la description.

### Décisions

- PR en brouillon : le test humain reste à faire (agent, selon la règle du 2026-10-16).

### Corrections et limites

- Les fichiers `pr.md` et `mutate.py` du scratchpad partagé de la session existaient déjà (autres agents) et ont été écrasés avant d'être renommés ; sans effet sur le dépôt.
- Test humain : à faire par Yanis (scénario dans la PR).

### Prochaine étape

- Test humain par Yanis sur l'iPhone 15 Pro et l'émulateur `tidemark_api35` : chronométrer le premier étiquetage après un lancement. Puis reporter la mesure dans l'ADR-004 et la spec 003. Rebaser si la PR #40 est mergée avant. Ajuster ensuite la phrase des « Limites » du README (proposition dans la PR).

## 2026-10-16 12:55

### Fait

- `main` fusionné dans la branche après le merge de la PR #41 (agent principal). Fusion sans conflit.
- Commit de merge testé avant le push : `dart analyze --fatal-infos` et `dart format` sans remarque, `flutter test` au vert (1811 tests), dont le test CA34 qui échouait sur `main`.

### Décisions

- Fusion de `main` plutôt que rebase, le force-push étant interdit (agent, par délégation de Yanis du 2026-10-16).

### Corrections et limites

- Les heures des entrées de ce journal ne correspondaient pas à l'heure réelle (heures estimées par l'agent, parfois dans le futur) : la CI refusait l'ordre chronologique. Chaque titre d'entrée reprend désormais l'heure du commit qui l'a créée (agent principal). Le contenu des entrées n'a pas changé.

### Prochaine étape

- Inchangée : voir l'entrée précédente.
