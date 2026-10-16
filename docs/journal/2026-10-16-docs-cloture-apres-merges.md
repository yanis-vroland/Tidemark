# Journal : docs/cloture-apres-merges

## 2026-10-16 11:22

### Fait

- Branche créée depuis `origin/main` (874150f, PR #34 à #37 mergées).
- Cahier des charges : mentions « À mettre en œuvre » retirées de RM57, RM60 et RM61, ainsi que la phrase d'introduction et la question ouverte qui y renvoyaient, après vérification dans le code de `main` :
  - RM57 : `AnalysisQueue` garde les entrées en échec d'écriture (`_saveFailed`), les place après les autres, et ne relance pas la file sur les événements reçus pendant un passage en échec (`_writeFailed`) ; une écriture réussie retire l'entrée ;
  - RM60 : `EntryTagsSection` annonce la fin de l'analyse (`analysisFinishedMessage`), par `SemanticsService.sendAnnouncement` sur iOS et par une région vive ailleurs, seulement pour une transition « en attente » vers un statut final vue dans le journal ; « Analyse en cours… » était déjà une région vive. Issue #29 fermée ;
  - RM61 : `dayOfMonth` écrit « 1er » ; utilisé par `weekdayAndDate` (liste, détail, `fullDateLabel`) et par le libellé de semaine du bilan (`local_week.dart`). Aucune autre écriture de date en français dans `lib/` (l'export écrit des dates ISO).
- README : la limite « Binaire natif non vérifié… ADR-004 proposé » remplacée par l'état réel (llama.cpp épinglé par SHA-256, modèle revérifié une fois par lancement avant le premier chargement, 9,4 à 14,8 s sur Mac M3, iPhone non mesuré) ; le renvoi « code natif non couvert, voir Limites » y retrouve sa cible. ADR comptés « tous acceptés », 31 PR mergées. Les deux sections de lancement fusionnées en une seule, à 3 commandes.
- `scripts/setup.sh` ajouté : `flutter pub get`, puis `scripts/fetch-llama-native.sh "$@"`, depuis la racine du dépôt quel que soit le dossier courant. `shellcheck` sans remarque ; lancé dans le worktree : 6 archives téléchargées et vérifiées ; avec un bundle inconnu, il échoue (code 1) avec le message du script du moteur.
- Architecture technique : réseau (empreinte recalculée à chaque lancement), chaîne d'approvisionnement (llama.cpp épinglé, contrôle B en CI, LiteRT-LM exclu et absent de l'APK et de l'IPA d'après le journal de `feat/integrite-moteur-modele`), modèle revérifié, lancement local, construction, index des ADR (ADR-004 « accepté », sans « mise en œuvre en cours »).
- `CLAUDE.md`, « Stack et commandes » : Installer = `scripts/setup.sh`.

### Décisions

- Agent, par délégation de Yanis du 2026-10-16 : `scripts/setup.sh` n'est pas ajouté à la liste `shellcheck` de `garde-fous.yml`, qui ne couvre aucun script de `scripts/` et vient du template générique ; vérifié localement.
- Agent, par délégation : l'ADR-004 (accepté, mergé) n'est pas réécrit ; ses « Conséquences » décrivent déjà le lancement en trois temps.

### Corrections et limites

- Aucun changement de `lib/` ni des tests : PR sans changement de comportement, test humain sans objet.
- `dart analyze --fatal-infos` et `dart format` au vert. `flutter test` : 1 775 tests (77 fichiers, nombre repris dans le README), **1 en échec sur `main`**, indépendant de cette PR : `analysis_queue_lifecycle_test.dart`, « CA34 : un désabonnement qui lève n'empêche pas le reste de l'arrêt » (`Bad state: désabonnement impossible`). Cause : la résolution de conflit du merge efd5edb (`main` dans `fix/suites-revue-004`) a repris le `_stop()` de `main` et perdu la boucle `try`/`catch` par désabonnement ajoutée par a643f07 ; seul ce bloc est perdu (comparaison de `lib/` et `test/` entre fb9c161 et 874150f). Non corrigé ici (consigne : ne pas toucher à `lib/`) : à corriger dans une PR `fix` dédiée, en gardant `_halted.complete()` et la boucle. La CI Flutter de cette PR échouera sur ce test tant que ce n'est pas fait.

### Prochaine étape

PR prête (docs), relecture et merge par Yanis.

## 2026-10-16 12:45

### Fait

- `main` fusionné dans la branche après le merge de la PR #41 (agent principal). Un conflit dans le cahier des charges, sur RM57 à RM61 : texte de cette branche gardé (mentions « À mettre en œuvre » retirées), avec les numéros de critères de la PR #41 (RM57 : CA39 au lieu de CA36 ; RM61 : CA38 au lieu de CA37).
- Commit de merge testé avant le push : `dart analyze --fatal-infos` sans remarque, `flutter test` 1 776 tests au vert, aucun numéro de critère en double dans les specs. Le test CA34 qui échouait sur `main` passe.

### Décisions

- Fusion de `main` plutôt que rebase : le force-push est interdit (agent, par délégation de Yanis du 2026-10-16).

### Corrections et limites

- Les chiffres du README (PR mergées, nombre de tests) seront remis à jour dans la PR de clôture finale, après les derniers merges.

### Prochaine étape

- Yanis merge ; l'agent vérifie que le dernier commit est sur `main`.
