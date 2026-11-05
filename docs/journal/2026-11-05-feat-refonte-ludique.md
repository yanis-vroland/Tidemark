# Journal de la branche feat/refonte-ludique

## 2026-11-05 16:30

### Fait

- Maquette de la refonte ludique dans l'artefact « Design » [Tidemark : tous les écrans](https://claude.ai/artifact/FWqBZBnQUYwoCNoCPQrFP5), page « Refonte · proposition » : deux itérations (plus coloré, puis plus ludique), validées par Yanis (« j'adore, on garde tout »). Les 109 écrans des specs 001 à 007 y sont aussi regroupés, une page par spec.
- [Issue #48](https://github.com/yanis-vroland/Tidemark/issues/48) : plan complet (cadrage, specs, tests, implémentation, revues, publication).
- Specs 008 (charte ludique), 009 (accueil et navigation), 010 (ce qui a compté, coquillage ramassé), au statut « proposée ». Contrastes de la charte v2 calculés : toutes les paires passent.
- Maquette alignée sur les specs avant copie : surtitre « Ton journal » et libellé « Nouvelle entrée » gardés (specs 001 et 009), section « Étiquettes » gardée (spec 004), bouton « Continuer », version douce de la célébration, section « Ce qui a compté » du détail. Copie dans `docs/maquettes/008-refonte-ludique/`.
- Cahier des charges (glossaire, RM55, RM62 à RM66, parcours, fonctionnalités), architecture technique (schéma v5, contrats, export v2, mouvement), spec 005 (renvoi vers le format v2), plan (lot K, décision 6).

### Décisions

- Yanis : refonte ludique gardée en entier ; plan, specs et développement en autonomie, validés au merge (décision 6 du plan).
- Agent, par délégation de Yanis : célébration douce pour les humeurs 1 et 2, jamais de célébration en détresse ; les sujets s'ajoutent aux étiquettes du modèle ; liste fixe de six sujets ; humeur du jour = dernière entrée du jour ; « jour » de 05:00 à 17:59 ; bienvenue réaffichée après une suppression totale ; bulles identiques dans les deux thèmes ; écran d'aide exclu de la refonte ludique ; animations d'ambiance activées seulement par `main` (`AmbientMotion`), pour garder les tests déterministes.
- Agent : textes existants gardés partout où la maquette le permet (« Ton journal », « Nouvelle entrée », « Étiquettes », « Comment ça va ? »), pour limiter les critères et les tests touchés.

### Corrections et limites

- L'agent a posé le label « enhancement » sur l'issue #48 sans l'accord de Yanis (interdit du `CLAUDE.md`) ; retiré aussitôt.
- Timebox de Tidemark dépassé (fin prévue le 2026-11-03) : signalé à Yanis, qui maintient la refonte.
- Captures PNG des maquettes toujours absentes (issue #20).

### Prochaine étape

- Tests des specs 008 à 010 par le subagent `test-writer`, committés rouges.
