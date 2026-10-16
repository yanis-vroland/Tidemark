# Journal : fix/boucle-mark-skipped

Issue #38 : quand le marquage « non analysée » d'une entrée en détresse échoue (`markSkipped` lève), la file d'analyse reprend la même entrée à chaque événement et n'atteint plus les plus anciennes.

## 2026-10-16 11:20

### Fait

- Lecture de l'issue #38, de `lib/analysis/analysis_queue.dart` et de la mise en œuvre de RM57/CA36 par la PR #37 (rang `_saveFailed` en mémoire, drapeau `_writeFailed` qui ignore les événements reçus pendant le passage en échec).
- Constat : en cas d'échec de `markSkipped`, la file fait `break` sans poser `_writeFailed` ni ranger l'entrée après les autres. Un événement reçu pendant le passage la relance aussitôt, et au prochain événement l'entrée en détresse, la plus récente, repasse devant les plus anciennes.
- Spec 004 complétée : règle « Défense en profondeur » (marquage impossible : même règle que l'écriture du résultat impossible, RM57) et nouveau CA39.

### Décisions

- Yanis a donné son accord le 2026-10-16 pour enchaîner sans pause après les tests rouges (« fonce, continue le dev ») et a délégué les décisions à l'agent (« fonce, sois autonome sur les décisions et finis l'app »).
- Le marquage « non analysée » est traité comme l'écriture d'un résultat : même règle RM57, même rang en mémoire, partagé avec les échecs de `saveAnalysis` (agent, par délégation de Yanis du 2026-10-16). Le cahier des charges n'est pas modifié : RM57 vise déjà « l'écriture du résultat », et le statut « non analysée » est le résultat de la vérification faite juste avant l'analyse (RM35) ; aucune règle métier ne change. Les lignes RM57, RM60 et RM61 sont éditées en parallèle par un autre agent.
- Nouveau critère numéroté CA39 (le plus grand numéro de la spec étant CA38).

### Corrections et limites

- La spec 004 porte deux CA36 (vérification de l'empreinte, PR #36, et échec d'écriture, PR #37). Non renuméroté ici, pour ne pas casser les renvois des tests et des PR ; signalé dans la PR.

### Prochaine étape

- Tests rouges (subagent `test-writer`), commit séparé, puis implémentation.

## 2026-10-16 11:52

### Fait

- Tests écrits par le subagent `test-writer`, avant toute implémentation, dans `test/analysis/analysis_queue_test.dart`, groupe « CA39 » (faux `FailMarkForRepository` : `markSkipped` lève pour des entrées données, compte ses appels, peut injecter des événements du journal pendant le marquage). Sur 52 tests du fichier, 2 rouges pour la bonne raison :
  - « CA39 : … la file s'arrête » : `markSkipped` appelé 44 fois au lieu d'une pour l'entrée en détresse (la file reboucle sur elle à chaque événement reçu pendant le passage) ;
  - « CA39 : au prochain événement… » : 2 marquages au lieu d'un dès la première série (l'événement du démarrage relance la même entrée).
  - Verts dès maintenant, gardés pour le contrôle par mutation : « CA39 : quand le marquage réussit ensuite… » et « RM8 : quel que soit le nombre d'événements… » (le texte de détresse n'atteint jamais le modèle).
- Relus avant l'implémentation : les deux rouges vérifient le nombre de marquages, l'ordre des analyses et l'absence du texte de détresse dans `FakeMoodAnalyzer.received`.

### Décisions

- Garde-fous propres aux tests, acceptés (agent, par délégation de Yanis du 2026-10-16) : au-delà de 30 marquages, le faux cède la main 20 ms, et les tests CA39 attendent un délai fixe plutôt que `whenIdle`, pour qu'une file qui reboucle fasse échouer le test au lieu de le figer.

### Corrections et limites

- `.llamadart-native/` absent du worktree : récupéré par `scripts/fetch-llama-native.sh macos-arm64` (empreinte vérifiée), ignoré par git.

### Prochaine étape

- Implémentation dans `lib/analysis/analysis_queue.dart`, puis contrôle par mutation.

## 2026-10-16 11:57

### Fait

- Critère renuméroté CA39 → CA40 dans la spec 004 et dans les noms des tests (seuls les noms changent, aucune vérification). Les tests ajoutés au commit `85eb2fa` sous « CA39 » sont donc les tests « CA40 ».

### Décisions

- Sur l'information de l'agent coordinateur : la PR #41 (`fix/arret-desabonnement`) renomme le second CA36 de la spec 004 (« écriture du résultat impossible ») en CA39. Le nouveau critère prend donc CA40, et la règle d'échec d'écriture est citée CA39 dans le code (agent, par délégation de Yanis du 2026-10-16). Remplace la décision « CA39 » de l'entrée de 14:00.

### Corrections et limites

- Tant que #41 n'est pas mergée, la spec de `main` nomme encore CA36 la règle d'échec d'écriture : rebase à prévoir après son merge.
- `main` est rouge sur le test CA34 « un désabonnement qui lève… » (boucle perdue au merge `efd5edb`), corrigé par #41. Ce test échoue aussi ici ; la branche ne touche pas `_stop()`.

### Prochaine étape

- Commit de l'implémentation, contrôle par mutation, revues.

## 2026-10-16 11:58

### Fait

- `lib/analysis/analysis_queue.dart` : l'échec de `markSkipped` suit le mécanisme de l'échec d'écriture du résultat (PR #37), mis en commun dans `_recordWriteFailure` : l'entrée passe en fin d'ordre (`_saveFailed`, en mémoire) et `_writeFailed` empêche les événements reçus pendant le passage de relancer la file. L'entrée reste « en attente » et la boucle s'arrête avant toute analyse : le modèle ne reçoit jamais son texte.
- Tests CA40 verts (52 sur 52 dans `analysis_queue_test.dart`). Suite complète : 1 778 verts, 1 rouge, en heure locale comme avec `TZ=UTC` ; le rouge est CA34 « un désabonnement qui lève… », déjà rouge sur `main` et corrigé par #41.
- `dart format` : rien à changer ; `dart analyze --fatal-infos` : aucun problème.
- Contrôle par mutation (tests filtrés sur CA40, RM8 et CA7), 5 mutations, toutes détectées :
  - M1, échec du marquage sans la règle RM57 (retour au défaut) : 2 rouges (CA40 « la file s'arrête », CA40 « au prochain événement ») ;
  - M2, arrêt de la série sans rang en mémoire : 1 rouge (CA40 « au prochain événement ») ;
  - M3, rang en mémoire sans arrêt de la série : 2 rouges (les deux mêmes) ;
  - M4, garde-fou RM8 : après un marquage en échec, l'entrée est analysée : 4 rouges (les quatre tests CA40 et RM8) ;
  - M5, garde-fou RM8 : détecteur ignoré : 7 rouges (les trois CA7 et les quatre CA40 et RM8).

### Décisions

- Rang commun aux deux échecs (écriture du résultat et marquage) : une entrée en détresse et une entrée ordinaire en échec passent l'une après l'autre, la plus anciennement en échec d'abord (agent, par délégation de Yanis du 2026-10-16).

### Corrections et limites

- Test humain difficile à provoquer : `markSkipped` n'échoue que sur une erreur de la base (disque plein, base verrouillée). Scénario proposé dans la PR.

### Prochaine étape

- Revues `reviewer` et `security-reviewer`, puis PR en brouillon.

## 2026-10-16 12:07

### Fait

- Revues `reviewer` et `security-reviewer` : aucun point bloquant. Suites données :
  - commentaire de `_writeFailed` mis à jour (il couvre aussi le marquage) ;
  - ensemble `_saveFailed` renommé `_failureOrder`, puisqu'il range les deux échecs ;
  - après un marquage réussi, l'entrée est retirée du rang explicitement, comme le dit la spec ;
  - rang commun aux deux échecs : CA40 complété dans la spec, et nouveau test « CA40 : une entrée en détresse au marquage en échec et une entrée ordinaire à l'écriture en échec partagent le même rang… », ajouté après le code et vert dès son ajout (la mutation M6 le couvre) ;
  - test « CA40 : quand le marquage réussit ensuite… » renforcé : un seul marquage réussi (2 appels en tout, rien ensuite). **Test modifié après son commit rouge** : ajout de vérifications, aucune retirée ;
  - cahier des charges : RM35 complétée (marquage impossible → l'entrée reste « en attente », jamais transmise au modèle, la file suit RM57), sans toucher RM57, RM60 ni RM61.
- Suite complète : 1 779 verts, 1 rouge (CA34, défaut de `main` corrigé par #41), en heure locale comme avec `TZ=UTC`. `dart format` et `dart analyze --fatal-infos` propres.
- Contrôle par mutation refait sur tout `analysis_queue_test.dart`, 7 mutations :
  - M1 (retour au défaut) : 4 rouges ; M2 (arrêt sans rang) : 2 ; M3 (rang sans arrêt) : 3 ; M4 (RM8 : analyse après un marquage en échec) : 5 ; M5 (RM8 : détecteur ignoré) : 8 ; M6 (marquage en échec non replacé en fin de rang) : 1 ;
  - M7 (rang non effacé après un marquage réussi) : survivante, mutation équivalente : `retainAll(pending)` retire l'entrée au tour suivant, puisqu'elle n'est plus « en attente ». Le retrait explicite documente la règle.

### Décisions

- Le journal de 14:00 disait qu'aucune règle métier ne changeait : corrigé, RM35 couvre désormais l'échec du marquage (agent, par délégation de Yanis du 2026-10-16, sur la remarque du `reviewer`).
- Renvois CA39 du code gardés (consigne du coordinateur) alors que la spec de `main` nomme encore CA36 la règle d'échec d'écriture : la PR reste en brouillon et sera rebasée après le merge de #41 (agent, par délégation de Yanis du 2026-10-16).
- Non suivis : délais fixes des tests CA40 (une file qui reboucle figerait `whenIdle` au lieu d'échouer ; délais larges, 300 ms pour des faux immédiats) ; garde contre un `markSkipped` « réussi sans effet » (suggestion de sécurité : impossible avec l'`UPDATE` actuel de drift, le texte n'atteindrait de toute façon pas le modèle), signalé dans la PR.

### Corrections et limites

- Test humain : impossible dans l'app telle quelle, `markSkipped` n'échoue que sur une erreur de la base, qu'aucune action de l'utilisatrice ne provoque. Scénario possible avec un correctif local non commité, décrit dans la PR, à faire par Yanis.

### Prochaine étape

- Ouvrir la PR en brouillon, publier la réponse à la revue IA, puis passer à `refactor/watch-entry` (#39).

## 2026-10-16 12:51

### Fait

- `main` fusionné dans la branche après le merge de la PR #41 (agent principal). Conflits résolus : dans `lib/analysis/analysis_queue.dart`, le code de cette branche (rang d'échec commun, CA39 et CA40) ; dans la spec 004, le statut et CA39 de `main`, complétés par la mention et le CA40 de cette branche.
- Commit de merge testé avant le push : `dart analyze --fatal-infos` et `dart format` sans remarque, `flutter test` au vert (1781 tests), dont le test CA34 qui échouait sur `main`.

### Décisions

- Fusion de `main` plutôt que rebase, le force-push étant interdit (agent, par délégation de Yanis du 2026-10-16).

### Corrections et limites

- Les heures des entrées de ce journal ne correspondaient pas à l'heure réelle (heures estimées par l'agent, parfois dans le futur) : la CI refusait l'ordre chronologique. Chaque titre d'entrée reprend désormais l'heure du commit qui l'a créée (agent principal). Le contenu des entrées n'a pas changé.

### Prochaine étape

- Inchangée : voir l'entrée précédente.

## 2026-10-16 13:10

### Fait

- `main` fusionné dans la branche après le merge des PR #40 et #45 (agent principal). Fusion sans conflit.
- Commit de merge testé avant le push : analyse et format sans remarque, `flutter test` au vert (1805 tests).

### Décisions

- Fusion de `main` plutôt que rebase, le force-push étant interdit (agent, par délégation de Yanis du 2026-10-16).

### Corrections et limites

- Aucune nouvelle.

### Prochaine étape

- Inchangée : voir l'entrée précédente.
