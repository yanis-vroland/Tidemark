# Journal : fix/arret-desabonnement

## 2026-10-16 11:31

**Fait**
- `main` (874150f) est rouge : le test « CA34 : un désabonnement qui lève n'empêche pas le reste de l'arrêt » (`test/analysis/analysis_queue_lifecycle_test.dart`) échoue avec `Bad state: désabonnement impossible`.
- Cause : la résolution du conflit du merge efd5edb (`main` dans `fix/suites-revue-004`) a gardé le `_stop()` de `main` et perdu la boucle de désabonnements protégés ajoutée par a643f07. Le reste de `lib/` et `test/` est intact (comparaison fb9c161 / 874150f, faite par l'agent de `docs/cloture-apres-merges`).
- Correction : boucle remise dans `AnalysisQueue._stop()`, en gardant `_halted.complete()`. Le test existant échoue sans la correction et passe avec (même test, pas de test nouveau : il existe déjà et n'a pas été modifié).
- `flutter test` : 1 775 tests au vert, aussi avec `TZ=UTC` ; `dart analyze --fatal-infos` et `dart format` au vert.

**Décisions**
- Correction faite par l'agent principal, sans spec nouvelle : CA34 de la spec 004 couvre déjà le cas (agent, par délégation de Yanis du 2026-10-16).

**Corrections et limites**
- La CI de la PR #37 aurait dû voir l'échec sur le commit de merge : à vérifier ; c'est la deuxième fois qu'une résolution de conflit perd du code. Piste : relancer `flutter test` sur le commit de merge avant de pousser.
- Test humain impossible : un désabonnement qui lève ne se provoque pas depuis l'app. Le test automatique est la seule preuve.

**Prochaine étape**
- Yanis merge ; l'agent vérifie que le commit est sur `main` et que la CI de `main` repasse au vert.
