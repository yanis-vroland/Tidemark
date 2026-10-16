# Journal : test/mutations-etiquetage

## 2026-10-15 14:55

### Fait

- Suite de la PR #23 (spec 004, déjà mergée) : ajout des tests qui manquaient au contrôle par mutation.
  - Attente de la fin de l'analyse après `cancel` : nouveau test CA14, avec `DetachedCancelAnalyzer` (un `cancel()` qui rend la main tout de suite pendant que la génération continue). La mutation est maintenant détectée.
  - `saveAnalysis` limité aux entrées « en attente » : 3 tests de stockage (entrée non analysée, étiquetée, sans étiquette). Mutation détectée.
  - Garde `!_modelReady` dans `_kick` : mutant équivalent. La boucle de `_run` vérifie la même condition avant toute lecture ou analyse, donc aucun comportement observable ne change. Le cas « modèle retiré pendant la file » est couvert par la garde de la boucle, et sa mutation est détectée.
- 972 tests verts, en heure de Paris comme en UTC ; lint et format au vert.

### Décisions

- Pas de test artificiel pour le mutant équivalent : la garde de `_kick` est gardée comme protection en amont (agent).

### Corrections et limites

- Aucun test existant modifié ; aucun code de `lib/` modifié.
- Ces tests ont d'abord été committés par erreur sur `feat/etiquetage`, déjà mergée (commit a80739f, qui touchait aussi le journal mergé). Ils sont repris ici.
- La PR #23 a été mergée avant les revues `reviewer` et `security-reviewer`, l'essai du vrai modèle et le test humain prévus par son journal : ces étapes restent à faire sur `main`.

### Prochaine étape

1. Revues `reviewer` et `security-reviewer` de la spec 004, sur `main`.
2. Essai du vrai modèle sur l'émulateur Android, puis test humain de Yanis sur l'iPhone (20 entrées fictives du spike).
3. PR `docs` sur le plan : cases de validation et reports du lot C (icônes, captures).
