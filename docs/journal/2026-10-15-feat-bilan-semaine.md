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
