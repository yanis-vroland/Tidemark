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
