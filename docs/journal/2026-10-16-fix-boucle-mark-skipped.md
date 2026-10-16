# Journal : fix/boucle-mark-skipped

Issue #38 : quand le marquage « non analysée » d'une entrée en détresse échoue (`markSkipped` lève), la file d'analyse reprend la même entrée à chaque événement et n'atteint plus les plus anciennes.

## 2026-10-16 14:00

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

## 2026-10-16 14:45

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
