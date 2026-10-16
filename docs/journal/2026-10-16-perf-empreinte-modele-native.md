# Journal : perf/empreinte-modele-native

## 2026-10-16 11:29

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
