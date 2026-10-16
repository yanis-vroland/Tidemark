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
