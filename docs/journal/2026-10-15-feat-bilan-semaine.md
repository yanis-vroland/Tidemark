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
