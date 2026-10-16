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
