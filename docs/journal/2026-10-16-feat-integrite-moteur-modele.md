# Journal : intégrité du moteur natif et du modèle (ADR-004)

Branche `feat/integrite-moteur-modele`, partie de `main` (`15b4486`, après le merge de la PR #28). Met en œuvre l'[ADR-004](../adr/004-integrite-du-moteur-et-du-modele.md), accepté par Yanis le 2026-10-16 avec l'option recommandée (A + contrôle de B pour le moteur, E pour le modèle, `llamadart_native_runtimes: llama_cpp`, journaux natifs à `none`). Le statut de l'ADR est changé par une autre PR (docs), pas ici. La branche `fix/suites-revue-004` touche en parallèle `lib/analysis/analysis_queue.dart` (`stop()` idempotent, échec d'écriture) : les changements de ce fichier ici sont réduits au minimum.

## 2026-10-16 09:20

### Fait

- Specs complétées avant tout test, parce que le changement revient sur une décision validée :
  - spec 003 : règle « Vérification avant le premier chargement », CA34 (empreinte recalculée au premier appel, fausse → fichier effacé, `absent`), CA35 (mémoire du lancement, appels simultanés, modèle téléchargé pendant le lancement, effacement pendant le calcul, erreur du calcul), CA36 (calcul dans un isolat) ; décision 5 révisée, décision 11 ; cas limite du fichier modifié de même taille ;
  - spec 004 : règle « Vérification avant le chargement », CA36 (vérification avant `prepare()`, empreinte fausse → entrée « en attente », file `idle`, reprise après retéléchargement, une seule vérification par lancement), CA37 (arrière-plan et arrêt pendant le calcul), CA38 (journaux de `llamadart` à `none` avant le chargement) ; décision 11 ;
  - spec 006 : CA37 (vérification avant la mise en mots du bilan, hors des 30 s), cas limite, décision 14.
- Constat vérifié avant d'écrire : `flutter test` exécute le hook de `llamadart` pour la machine hôte. Avec `llamadart_native_path` vers un dossier vide, `flutter test test/model/model_source_test.dart` échoue : « No compatible native bundle found at … for macos-arm64 ». La CI télécharge donc aujourd'hui `linux-x64` (177 Mo) sans contrôle à chaque exécution sans cache. Le dossier local devra fournir l'hôte : `macos-arm64` sur le poste, `linux-x64` en CI. Le hook échoue sans repli sur un téléchargement : c'est le comportement voulu.

### Décisions

- Yanis a donné son accord le 2026-10-16 pour enchaîner sans pause après les tests rouges (« fonce, continue le dev ») et délégué les décisions à l'agent (« fonce, sois autonome sur les décisions et finis l'app »).
- Le bilan (spec 006) lit aussi le modèle par llama.cpp : la vérification de l'ADR-004 (« aucune lecture du modèle avant vérification ») le couvre aussi, d'où la spec 006 complétée, alors que la demande ne citait que les specs 003 et 004 (agent, par délégation de Yanis du 2026-10-16).
- `verifyBeforeFirstLoad()` rend un booléen et est appelé avant chaque `prepare()` ; c'est lui qui garde le résultat du lancement. Un seul endroit sait si le fichier a été vérifié, partagé par l'étiquetage et le bilan (agent, par délégation de Yanis du 2026-10-16).
- Erreur du calcul autre qu'un fichier illisible : chargement refusé, fichier gardé, nouvel essai au chargement suivant. Effacer 1,1 Go sur une erreur passagère coûterait un retéléchargement à la personne (agent, par délégation de Yanis du 2026-10-16).
- L'arrêt de la file n'attend pas la fin du calcul (CA37) : sinon la suppression totale attendrait plusieurs secondes. Cela demande une ligne dans `stop()`, que la branche `fix/suites-revue-004` modifie aussi : conflit possible, à rebaser après le premier merge (agent, par délégation de Yanis du 2026-10-16).
- Le calcul du bilan est hors des 30 s de CA26 : il ne fait pas partie de la réponse du rédacteur (agent, par délégation de Yanis du 2026-10-16).

### Corrections et limites

- Les nouveaux critères suivent la numérotation existante de chaque spec (CA34 à CA36 pour la 003, CA36 à CA38 pour la 004, CA37 pour la 006).

### Prochaine étape

Tests rouges : `HttpModelDownloader.verifyBeforeFirstLoad` et `sha256OfFile`, file d'analyse, bilan, journaux de `llamadart`, script de récupération du moteur.

## 2026-10-16 09:45

### Fait

- Squelette sans comportement : `ModelDownloader.verifyBeforeFirstLoad()` (rend `_state is ModelReady`, sans calcul), paramètre `hashFile` de `HttpModelDownloader`, fonction `sha256OfFile` (calcul juste mais synchrone, sur le fil principal) ; `FakeModelDownloader` gagne `verifyBeforeLoadCalls`, `fingerprintMatches` et `verifyBeforeLoadGate`.
- Tests rouges, écrits par le subagent `test-writer` (sans paramètre `model`) à partir des specs, relus avant l'implémentation :
  - `test/model/verify_before_first_load_test.dart` (spec 003, CA34 à CA36) ;
  - `test/analysis/analysis_queue_verification_test.dart` (spec 004, CA36, CA37) ;
  - `test/analysis/llama_logging_test.dart` (spec 004, CA38 ; spec 006, décision 14) ;
  - `test/review/review_narrator_verification_test.dart` (spec 006, CA37).
- Tests du moteur natif, écrits par l'agent principal (comportement sans spec, ADR-004 décisions 1 et 3) : `tests/fetch-llama-native.sh` (archives factices en `file://`, aucun accès à Internet : téléchargement vérifié, revérification du cache, empreinte fausse, archive altérée, entrées inattendues, bundle non épinglé, fichier d'empreintes réel), `tests/check-llama-hook-cache.sh` (contrôle B du cache de pub), `test/platform/native_engine_config_test.dart` (`pubspec.yaml`, `.gitignore`, aucune archive versionnée, étapes de la CI).
- Résultat, rouge pour la bonne raison :
  - `flutter test` sur les cinq nouveaux fichiers Dart : 10 réussis, 41 en échec. Échecs : `hashFile` jamais appelé, `true` au lieu de `false` (empreinte fausse, fichier illisible), minuteur à 0 tick pendant `sha256OfFile` (calcul synchrone), file et narrateur qui n'appellent jamais `verifyBeforeFirstLoad`, niveaux de journal restés à `info`, `pubspec.yaml` sans bloc `llamadart`, CI sans les étapes.
  - Réussis dès le squelette (gardes de non-régression, signalés par `test-writer`) : modèle absent ou en téléchargement → `false` sans calcul, modèle téléchargé pendant le lancement → `true`, après `deleteModel()` → `false`, empreinte juste de `sha256OfFile`, délai du narrateur après le calcul, aucun texte gardé après `cancel()`.
  - `bash tests/fetch-llama-native.sh` et `bash tests/check-llama-hook-cache.sh` : script absent, toutes les vérifications échouent (code 127).

### Décisions

- `test-writer` a supposé, et l'agent retient : après un `false` sans changement d'état (erreur du calcul), la file s'arrête sans boucler et un nouvel enregistrement la relance ; pendant le calcul, l'entrée est « en cours » (`running`) mais reste `pending` en base ; le rédacteur du bilan fixe les niveaux de journal avant le test d'existence du fichier (agent, par délégation de Yanis du 2026-10-16).
- Le contrôle B de l'ADR prend la forme d'un script (`scripts/check-llama-hook-cache.sh`), lancé avant `flutter pub get` avec `--purge` (cache restauré par la CI) et après les tests sans option : avec `llamadart_native_path`, le hook ne range rien hors de `native_bundles/local/` (agent, par délégation de Yanis du 2026-10-16).

### Corrections et limites

- Le seuil du test du minuteur (3 ticks de 4 ms pendant le calcul de 32 Mo) pourrait être fragile sur une machine très rapide ; à surveiller en CI.

### Prochaine étape

Implémentation : `HttpModelDownloader`, `AnalysisQueue` (minimum), `ReviewNarrator`, journaux de `llamadart`, scripts, `pubspec.yaml`, CI, puis documents de référence.
