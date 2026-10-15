# Journal : bilan de la semaine (spec 006)

Branche `feat/bilan-semaine`, partie de `main` à jour (lot I du plan). Spec : [`docs/specs/006-bilan-de-la-semaine.md`](../specs/006-bilan-de-la-semaine.md), statut « validée ».

## 2026-10-15 15:20

### Fait

- Lu : spec 006, maquettes `docs/maquettes/006-bilan-de-la-semaine/` et charte, architecture technique, spec 004 (file d'analyse, `MoodAnalyzer`). Aucun piège dans `docs/learnings/` (dossier vide).
- Squelette de la spec 006, sans comportement (`UnimplementedError`) :
  - `lib/review/` : `LocalWeek` et libellés de semaine, `WeeklyReview` (`InsufficientWeek`, `ComputedWeek`), `ReviewFacts`, `WeekRegularity`, `ReviewTrend`, `WeeklyReviewCalculator`, `ReviewWriter` (`RawReview`, `ModelMissing`, `WriterFailed`), `ReviewTextValidator` et ses listes (vides), `ReviewNarrator` (sensibilité, mémoire, délai, validation), `LlamaReviewWriter`, `GatedReviewWriter` ;
  - `lib/model/` : `ModelGate` (accès exclusif au modèle) et `GatedMoodAnalyzer` ;
  - `WeeklyReviewScreen` vide ; paramètre `narrator` de la liste, `reviewNarrator` de `TidemarkApp`, `reviewWriter` de `Journal`.
- `FakeReviewWriter` dans `test/support/` : sortie choisie par le test, faits reçus enregistrés, délai, mise en mots sans fin, compteur de mises en mots simultanées.
- Suite existante : 968 tests au vert.

### Décisions

- Yanis a donné son accord le 2026-10-15 pour enchaîner sans pause après les tests rouges (« fonce, continue le dev ») : tests rouges montrés ici et dans la PR, puis implémentation (Yanis).
- Partage du moteur avec la file d'étiquetage, non tranché par la spec : un verrou `ModelGate` détenu par l'analyseur de son chargement à sa libération, et par le rédacteur le temps d'une mise en mots. Jamais deux générations ni deux modèles en mémoire, sans toucher à `analysis_queue.dart` ni à `llama_mood_analyzer.dart` (corrigés en parallèle sur `fix/etiquetage-interruption`). Choix structurant : ADR-005 au statut « proposé » (agent, à valider par Yanis).
- `ReviewWriter.cancel()` ajouté au contrat de la spec : nécessaire pour abandonner la génération au délai de 30 s et quand la personne quitte l'écran (« Cas limites »). Signalé dans la PR (agent).

### Corrections et limites

- Rien à signaler.

### Prochaine étape

Tests de la spec 006 par le subagent `test-writer`, committés seuls et rouges ; puis implémentation.

## 2026-10-15 15:41

### Fait

- Tests de la spec 006 écrits par le subagent `test-writer`, à partir de la spec et de la maquette seules, avant toute implémentation : 344 tests, dont **342 en échec** pour la bonne raison (`UnimplementedError`, texte absent de l'écran vide, listes de rejet vides, jetons `bar-thickness` et `day-cell` absents de `tokens.json`). Les 968 tests existants restent verts.
- Fichiers : `test/review/` (`local_week_test` 31, `weekly_review_calculator_test` 65, `review_text_validator_test` 80, `review_narrator_test` 42, `review_wiring_test` 4), `test/model/model_gate_test.dart` (22), `test/ui/weekly_review_screen_test.dart` (97), `test/ui/theme/review_tokens_test.dart` (3), harnais `test/support/review_harness.dart`.
- Les 2 tests verts sans implémentation : `icon-md` et `icon-button`, déjà dans `tokens.json` ; aucun libellé de la liste fermée dans les blocs de la spec 006 (vérifie la spec, pas le code ; le même test sur le code échoue).

### Décisions

- Accord de Yanis du 2026-10-15 appliqué : pas de pause après les tests rouges, implémentation enchaînée (Yanis).
- Horloge des tests d'écran : dimanche 18 octobre 2026, comme la maquette (test-writer).

### Corrections et limites

- Points non fixés par la spec, signalés par le test-writer et non testés : « 1er » du mois dans les dates ; tri alphabétique avec accents ; semaine sensible sans modèle (`Withheld` ou `ModelMissing`) ; changement de semaine pendant une mise en mots ; partage réel du verrou entre analyseur et rédacteur (non observable sans moteur).

### Prochaine étape

Implémentation jusqu'au vert, ADR-005 (proposé), documents de référence.

## 2026-10-15 15:53

### Fait

- Implémentation de la spec 006 :
  - `LocalWeek` en dates civiles (changement d'heure sans effet) et libellés de semaine ;
  - `WeeklyReviewCalculator` : toutes les moyennes en entiers, libellé transmis depuis la moyenne exacte (CA35), sensibilité aux trois critères, étiquettes des seules entrées « étiquetées » ;
  - `ReviewTextValidator` (règles 1 à 5) et listes reprises des blocs de la spec ;
  - `ReviewNarrator` : sensibilité évaluée avant la mémoire (CA34), modèle absent, délai de 30 s avec abandon, texte gardé en mémoire seulement, rien gardé après un abandon ;
  - `ModelGate`, `GatedMoodAnalyzer`, `GatedReviewWriter`, `LlamaReviewWriter` (consigne fixe, schéma `{"text": string}`, 160 jetons, température 0,2), branchés dans `openJournal` et `startApp` ;
  - `WeeklyReviewScreen` (états chargement, erreur avec « Réessayer », moins de 3 entrées, mise en mots, texte, sans texte, modèle absent ; flèches de semaine) et carte « Bilan de la semaine » en tête de la liste.
- Jetons `bar-thickness` (8) et `day-cell` (40) ajoutés à `tokens.json`, à `TidemarkSize` et à la charte ; usage de `line` étendu aux flèches désactivées.
- ADR-005 « Partage du modèle local entre l'étiquetage et le bilan », statut **proposé**. Architecture technique : contrats `ReviewWriter` et `ModelGate`, index des ADR.
- Vérifications : `dart format` sans changement, `dart analyze --fatal-infos` sans remarque, `flutter test` 1 312 tests au vert, et aussi avec `TZ=UTC`.
- Contrôle par mutation : 25 mutations, toutes détectées par au moins un test. Sensibilité : chacun des 3 critères désactivé seul. Narrateur : semaine sensible ignorée, mémoire lue avant la sensibilité, texte gardé non effacé, validation contournée, délai supprimé, résultat abandonné gardé, modèle absent ignoré. Validateur : JSON, champ en plus, texte vide, longueur, longueur en unités UTF-16, caractères numériques, chiffres ASCII seulement, mots de nombre, expressions interdites, sous-chaînes au lieu de mots entiers, détresse. Verrou : rédacteur ou analyseur sans verrou, verrou rendu avant la fin de la génération, verrou non exclusif.

### Décisions

- Dates d'une autre année sur l'écran : jour, mois et année aux deux bornes (« 5 octobre 2025 – 11 octobre 2025 »), lecture de « l'année à chaque borne » (agent).
- Tri des étiquettes à égalité : ordre alphabétique sans tenir compte des accents (« études » avant « famille ») (agent).
- Semaine sensible et modèle absent : la sensibilité prime (`Withheld`), dans l'ordre de vérification de la spec (agent).
- Changement de semaine pendant une mise en mots : la mise en mots en cours est abandonnée, comme à la sortie de l'écran ; elle reprend au retour sur la semaine (agent).
- « Analysé sur ton téléphone » gardé sous « Aucune étiquette cette semaine. », comme le décrit le README de la maquette (même carte, phrase à la place des puces) (agent).

### Corrections et limites

- Deux tests du test-writer modifiés, sans changer ce qu'ils vérifient :
  - `review_wiring_test` : `find.text('3')` trouvait aussi le chiffre de la pastille « Neutre » de la répartition. Remplacé par « au moins un » et la présence de « Humeur moyenne ».
  - `weekly_review_screen_test`, CA27 : le test interdisait tout `TextButton`, donc aussi le retour « Journal » exigé par CA4. Il exige maintenant que ce retour soit le seul.
  - `weekly_review_screen_test`, CA22 : le fragment cherché « 3 jours » figurait aussi dans les chiffres de l'app (« sur 3 jours »). Il cherche maintenant « 3 jours notés », la phrase de la sortie brute.
- `LlamaReviewWriter` n'est exécuté ni par les tests ni par la CI : à vérifier au test humain, comme `LlamaMoodAnalyzer`.
- Test humain : impossible pour l'agent, à faire par Yanis (scénarios dans la PR).

### Prochaine étape

Revues `reviewer` et `security-reviewer`, corrections, puis PR.
