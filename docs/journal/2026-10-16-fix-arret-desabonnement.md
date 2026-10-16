# Journal : fix/arret-desabonnement

## 2026-10-16 11:31

### Fait

- `main` (874150f) est rouge : le test « CA34 : un désabonnement qui lève n'empêche pas le reste de l'arrêt » (`test/analysis/analysis_queue_lifecycle_test.dart`) échoue avec `Bad state: désabonnement impossible`.
- Cause : la résolution du conflit du merge efd5edb (`main` dans `fix/suites-revue-004`) a gardé le `_stop()` de `main` et perdu la boucle de désabonnements protégés ajoutée par a643f07. Le reste de `lib/` et `test/` est intact (comparaison fb9c161 / 874150f, faite par l'agent de `docs/cloture-apres-merges`).
- Correction : boucle remise dans `AnalysisQueue._stop()`, en gardant `_halted.complete()`. Le test existant échoue sans la correction et passe avec (même test, pas de test nouveau : il existe déjà et n'a pas été modifié).
- `flutter test` : 1 775 tests au vert, aussi avec `TZ=UTC` ; `dart analyze --fatal-infos` et `dart format` au vert.

### Décisions

- Correction faite par l'agent principal, sans spec nouvelle : CA34 de la spec 004 couvre déjà le cas (agent, par délégation de Yanis du 2026-10-16).

### Corrections et limites

- La CI de la PR #37 aurait dû voir l'échec sur le commit de merge : à vérifier ; c'est la deuxième fois qu'une résolution de conflit perd du code. Piste : relancer `flutter test` sur le commit de merge avant de pousser.
- Test humain impossible : un désabonnement qui lève ne se provoque pas depuis l'app. Le test automatique est la seule preuve.

### Prochaine étape

- Yanis merge ; l'agent vérifie que le commit est sur `main` et que la CI de `main` repasse au vert.

## 2026-10-16 12:00

### Fait

- Suites de la revue IA de la PR #41.
- Le merge efd5edb a perdu plus que la boucle de `_stop()`. Comparaison ligne à ligne des fichiers de `fix/suites-revue-004` (fb9c161) avec `main` (874150f) : dans la spec 004, le statut, la fin de CA34 (second `stop()`, désabonnement qui échoue) et la décision n° 11 ; dans la spec 006, le statut et la décision n° 14 (« 1er ») ; dans l'architecture technique, le garde-fou « Source du modèle pour `llamadart` » (issue #31). Les trois sont remis.
- Le même merge a laissé deux critères en double : spec 004, deux CA36 (vérification avant le premier chargement, de l'ADR-004 ; écriture du résultat impossible, de la PR #37) ; spec 006, deux CA37 (empreinte avant la mise en mots ; « 1er » du mois). Ceux de la PR #37 sont renumérotés : écriture impossible → CA39, « 1er » → CA38, dans les specs, le cahier des charges (RM57, RM61), la spec 001 (CA3), les commentaires de `lib/` et les noms des tests concernés.
- Nouveau test CA34 : le désabonnement du cycle de vie (le premier de la liste) lève ; celui du journal est quand même fait, la génération annulée, le modèle libéré. Mutation « sortir de la boucle à la première erreur » : ce test échoue, l'ancien passait.
- `flutter test` : 1 776 tests au vert, aussi avec `TZ=UTC` ; analyse et format au vert ; aucun numéro de critère en double dans les specs.

### Décisions

- Renuméroter les critères de la PR #37 plutôt que ceux de l'ADR-004 : ils sont moins cités (agent, par délégation de Yanis du 2026-10-16).
- Noms des tests renommés (CA36 → CA39, CA37 → CA38) sans toucher à leur contenu : signalé dans la PR.

### Corrections et limites

- Correction de l'entrée précédente : « CA34 couvre déjà le cas » était faux sur `main`, la phrase avait été perdue au merge. Elle est remise.
- Les journaux déjà mergés citent encore CA36 et CA37 sous leur ancien numéro : ils ne se modifient pas (`verifier-journal.sh`).
- La PR #40 touche RM57 et RM61 : elle sera rebasée après le merge de celle-ci.

### Prochaine étape

- Yanis merge ; l'agent rebase la PR #40 et vérifie que la CI de `main` repasse au vert.
