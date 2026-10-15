# Journal : correction de l'interruption de l'étiquetage (spec 004)

Branche `fix/etiquetage-interruption`, partie de `main` après le merge de la PR #23. Corrige les points des revues IA de la PR #23. La PR #24 (`test/mutations-etiquetage`, encore ouverte) touche `test/analysis/analysis_queue_test.dart`, `test/storage/analysis_storage_test.dart` et `test/support/analysis_harness.dart` : cette branche n'y touche pas, et sera rebasée après son merge.

## 2026-10-15 15:16

### Fait

- Spec 004 complétée avant toute correction, parce que le bug révèle des cas non prévus :
  - règle « Arrière-plan » : la file observe le cycle de vie de l'app, interrompt l'analyse sans écrire de résultat, libère le modèle, et reprend au retour au premier plan ;
  - règle « Entrée en cours » : l'entrée est « en cours d'analyse » dès le chargement du modèle et jusqu'à l'écriture du résultat ;
  - CA32 (arrière-plan pendant une analyse), CA33 (arrière-plan pendant le chargement), CA34 (libération qui échoue, arrêt pendant le chargement), CA35 (`LlamaMoodAnalyzer.cancel()` attend la génération, 5 s au plus, puis libère le moteur) ;
  - cas limite « App mise en arrière-plan » et « Données » mis à jour ; décision n° 10.
- Architecture technique : contrats `LocalEngine` et cycle de vie de l'app ajoutés au tableau des contrats.

### Décisions

- Yanis a donné son accord le 2026-10-15 pour enchaîner sans pause après les tests rouges (« fonce, continue le dev ») ; la spec complétée reste à valider par Yanis avec la PR.
- Le cycle de vie est injecté dans `AnalysisQueue` comme un `Stream<AppLifecycleState>` fourni par `startApp`, plutôt que `WidgetsBinding` en dur : testable avec un flux factice (agent, sur la demande de la revue).
- `inactive` n'interrompt rien : sur iOS, il couvre le centre de contrôle ou un appel entrant, où le GPU reste permis ; `hidden`, `paused` et `detached` interrompent (agent).
- Tout résultat d'une analyse pendant laquelle l'app est passée en arrière-plan est ignoré, même `Tagged` : on ne peut pas distinguer un `Untagged` dû au GPU refusé d'un vrai `Untagged` ; l'entrée sera analysée de nouveau au retour (agent).
- Délai borné de `cancel()` dans `LlamaMoodAnalyzer` : 5 s, puis libération du moteur (agent).

### Corrections et limites

- Les CA32 à CA35 sont numérotés à la suite du CA31, comme lui hors ordre dans la liste.

### Prochaine étape

Couture `LocalEngine` et paramètre du cycle de vie (squelette, sans comportement), puis tests de non-régression rouges.

## 2026-10-15 15:30

### Fait

- Squelette, sans changement de comportement :
  - couture `LocalEngine` (`generate`, `cancelGeneration`, `dispose`) et `loadLlamadartEngine` dans `lib/analysis/llama_mood_analyzer.dart` ; `LlamaMoodAnalyzer` reçoit `loader` et `cancelGrace` (pas encore utilisé) ;
  - `AnalysisQueue` reçoit `lifecycle` (pas encore observé) ; `startApp` le lui passe ; `appLifecycleStates()` rend pour l'instant un flux vide.
- 968 tests verts, analyse sans remarque.

### Décisions

- Couture au niveau du moteur chargé, plutôt qu'un faux `llama.LlamaEngine` : `ChatSession` appelle des méthodes internes du moteur, qu'un faux devrait toutes imiter (agent).

### Corrections et limites

- L'adaptateur `_LlamadartEngine` n'est toujours exécuté que sur le téléphone, au test humain.

### Prochaine étape

Tests de non-régression des points 1 à 6, rouges, dans des fichiers neufs (pas ceux de la PR #24).

## 2026-10-15 15:45

### Fait

- Tests de non-régression écrits par le subagent `test-writer` à partir de la spec complétée, dans des fichiers neufs (aucun des trois fichiers de la PR #24 touché) :
  - `test/analysis/analysis_queue_lifecycle_test.dart` : CA32 (hidden, paused, detached ; analyseur qui ignore `cancel()` ; délai qui tombe en arrière-plan ; entrée enregistrée en arrière-plan ; reprise au retour ; `inactive` sans effet ; aller-retour rapide ; branchement `startApp` ; `appLifecycleStates()`), CA33, CA34, règle « Entrée en cours » ;
  - `test/analysis/llama_mood_analyzer_cancel_test.dart` : CA35, sur un moteur factice (jamais de modèle) ;
  - `test/entries/fake_entry_repository_test.dart` (par l'agent principal) : le faux dépôt n'écrit un résultat que sur une entrée « en attente », comme le vrai.
- Résultat : 28 tests, 22 rouges pour la bonne raison, 6 verts. Rouges : `cancel()` jamais appelé à la mise en arrière-plan, `saveAnalysis` appelé avec `Untagged` après la mise en arrière-plan, entrée analysée en arrière-plan, `verifyAfterLoadFailure()` appelé après un chargement interrompu, erreur de `release()` qui bloque la file et `stop()`, analyse lancée après `stop()` pendant le chargement, `currentEntryId` nul pendant le chargement et l'écriture, `LlamaMoodAnalyzer.cancel()` qui rend la main avant la fin de la génération et n'attend jamais `cancelGrace`, `appLifecycleStates()` muet, faux dépôt qui écrase un statut déjà posé. Verts dès maintenant : `inactive` sans effet, `cancel()` sans génération ou avant chargement, `analyze()` par la couture (Tagged, Untagged), écriture du faux sur une entrée en attente.

### Décisions

- Pour CA34, le test accepte que `stop()` se termine normalement ou par l'erreur de `release()`, pourvu qu'il ne bloque pas (test-writer) ; l'implémentation avalera l'erreur (agent).

### Corrections et limites

- Suite des nouveaux fichiers : environ 28 s en rouge (attentes bornées), beaucoup moins une fois au vert.

### Prochaine étape

Correction de `AnalysisQueue`, `LlamaMoodAnalyzer`, `appLifecycleStates()` et du faux dépôt, jusqu'au vert.

## 2026-10-15 16:10

### Fait

- `AnalysisQueue` :
  - observe le cycle de vie injecté : `hidden`, `paused`, `detached` mettent la file en arrière-plan (annulation de l'analyse en cours, aucun résultat écrit, modèle libéré après la fin de l'analyse, aucune analyse lancée) ; `resumed` la relance ; `inactive` ne change rien ;
  - « interrompue » distinguée de « sans étiquette » : un compteur de mises en arrière-plan, relevé avant le chargement et l'analyse, fait ignorer tout résultat obtenu pendant une mise en arrière-plan, y compris un délai de 30 s qui tombe au retour ;
  - un chargement interrompu (arrière-plan ou `stop()`) n'est ni un échec de chargement (`verifyAfterLoadFailure()`, « indisponible ») ni suivi d'une analyse ; un chargement réussi est libéré ;
  - `release()` qui lève est avalé, et l'état de la file est remis dans un `finally` interne (CA34) ;
  - l'entrée est « en cours » du chargement du modèle à l'écriture de son résultat ;
  - `whenIdle` annoté `@visibleForTesting`.
- `LlamaMoodAnalyzer.cancel()` garde la génération en cours, demande l'arrêt au moteur, l'attend `cancelGrace` (5 s) au plus, puis rend `Untagged` à l'analyse et libère le moteur (CA35).
- `appLifecycleStates()` (dans `lib/main.dart`) : flux d'un `AppLifecycleListener`, créé au premier abonné ; `main` le passe à `startApp`.
- `FakeEntryRepository.saveAnalysis` n'écrit plus que sur une entrée « en attente », comme le vrai dépôt (modification d'un faux de test, signalée dans la PR).
- `dart format`, `dart analyze --fatal-infos` sans remarque ; `flutter test` : 996 tests verts, aussi avec `TZ=UTC`.
- Contrôle par mutation, chaque protection désactivée une fois, sur `test/analysis/` et le test du faux dépôt : 15 mutations, 15 détectées (cycle de vie non écouté, pas d'annulation en arrière-plan, résultat interrompu enregistré, chargement interrompu traité en échec, analyse en arrière-plan, pas de relance au retour, erreur de `release()` non avalée, `stop()` non vu après le chargement, `inactive` qui interrompt, « en cours » seulement après le chargement, retour au repos avant l'écriture, `cancel()` sans attente, abandon non rendu, moteur non libéré au délai, faux dépôt qui écrase le statut).

### Décisions

- `stop()` avale l'erreur de `release()` : l'arrêt doit toujours se terminer (agent).
- Une analyse dont la mise en arrière-plan est suivie d'un retour rapide n'est pas gardée : la file la relance (agent).

### Corrections et limites

- Le comportement réel d'iOS (GPU refusé, suspension) n'est pas reproductible en test : à vérifier au test humain.

### Prochaine étape

Revues `reviewer` puis `security-reviewer`, puis PR.

## 2026-10-15 16:40

### Fait

- Revues lancées : `reviewer` (1 bloquant, 5 à corriger, 4 suggestions) et `security-reviewer` (rien de bloquant, 2 à corriger, 2 suggestions). Point commun bloquant : après une annulation qui dépasse 5 s, `LlamaMoodAnalyzer` a libéré son moteur, mais la file le croit encore chargé ; chaque entrée suivante devenait « sans étiquette » sans analyse.
- Spec 004 précisée (CA35) : seul le moteur annulé est libéré, attente de la libération bornée, et la file libère le modèle après un délai de 30 s dépassé, pour que l'entrée suivante le recharge. Cahier des charges : RM34 dit maintenant que l'analyse n'a lieu qu'au premier plan et reprend au retour.
- 5 tests de non-régression ajoutés à `test/analysis/llama_mood_analyzer_cancel_test.dart`, tous rouges pour la bonne raison : libération qui ne se termine jamais (`cancel()` bloqué), analyse abandonnée rendue avant la fin de la libération, moteur chargé entre-temps libéré à tort, `cancel()` qui n'attend plus la génération une fois le moteur libéré, entrée suivante « sans étiquette » sans rechargement du modèle (file branchée sur `LlamaMoodAnalyzer` et un moteur factice).

### Décisions

- Correction du bloquant côté file (libération après un délai dépassé), sans changer le contrat de `MoodAnalyzer` (agent, option proposée par les deux revues).

### Corrections et limites

- Le premier essai du test « analyse abandonnée après la libération » passait sans correction (la libération factice était instantanée) : renforcé avec une libération de 100 ms.

### Prochaine étape

Corrections jusqu'au vert, puis réponse aux revues dans la PR.

## 2026-10-15 17:00

### Fait

- Corrections des revues :
  - file : après un délai de 30 s dépassé, le modèle est libéré, et l'entrée suivante le recharge (bloquant) ;
  - `LlamaMoodAnalyzer.cancel()` : seul le moteur annulé est libéré, la libération est attendue avant que l'analyse abandonnée rende la main, et cette attente est bornée à `cancelGrace` ; la génération est attendue même si le moteur vient d'être libéré.
- `dart format`, `dart analyze --fatal-infos` sans remarque ; `flutter test` : 1001 tests verts, aussi avec `TZ=UTC`.
- Contrôle par mutation des nouvelles protections : 5 mutations, 5 détectées (pas de libération après le délai, libération du moteur courant au lieu du moteur annulé, libération non bornée, abandon rendu avant la libération, pas d'attente sans moteur).

### Décisions

- Non suivis, avec leur raison dans la réponse à la revue de la PR (agent) : libération différée à la fin réelle de la génération (la documentation de `llamadart` 0.12.0 dit que `dispose` décharge le modèle en annulant les générations en cours ; à vérifier au test humain) ; borne côté file de l'attente après `cancel` (le contrat de `MoodAnalyzer` l'impose déjà à l'analyseur) ; traces des erreurs avalées ; état initial du cycle de vie (l'app n'a aucun mode d'arrière-plan et démarre toujours au premier plan) ; état `idle` entre deux entrées (garde la règle « en cours jusqu'à l'écriture », sans laisser un identifiant périmé sur une entrée déjà analysée) ; erreur GPU reçue avant l'événement `hidden` (à observer au test humain).

### Corrections et limites

- Test humain à faire par Yanis, non simulé : voir la PR.

### Prochaine étape

PR, puis commentaire « Réponse à la revue IA ».
