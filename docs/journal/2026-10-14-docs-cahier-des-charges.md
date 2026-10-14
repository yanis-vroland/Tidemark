# Journal : cahier des charges fonctionnel

Branche `docs/cahier-des-charges`.

## 2026-10-14 10:25

### Fait

- Cahier des charges rempli : objectif et périmètre, acteur unique, glossaire de 14 termes avec leur nom dans le code, statuts du modèle local et de l'analyse d'une entrée, règles RM1 à RM12, parcours, fonctionnalités par lot, 10 questions ouvertes.
- Plan : tâche cochée, section « Décisions » qui renvoie vers le cahier des charges.
- En dehors du dépôt : charte « Tidemark » (artefact Design System) et maquette d'exploration de la saisie (artefact Design), créées à la demande de Yanis.

### Décisions

- Chaque règle cite sa source tant qu'aucune spec n'existe : `CLAUDE.md`, le plan ou la charte (agent).
- Libellés d'humeur (RM3) repris de la charte, que Yanis a validée (« parfait ») le 2026-10-14.
- Noms du code proposés par l'agent (`Entry`, `mood`, `note`, `Tag`, `WeeklyReview`…), à valider dans la PR.

### Corrections et limites

- Aucune règle inventée : texte obligatoire, nombre d'entrées par jour, modification, sort d'une entrée en détresse, moment du téléchargement, vocabulaire des étiquettes, format d'export, semaine du bilan et langue restent en questions ouvertes.
- La maquette de la saisie est une exploration : elle n'est pas copiée dans `docs/maquettes/` avant sa spec (lot E).

### Prochaine étape

Yanis répond aux questions ouvertes (au moins la 10, la langue, avant le spike) et merge cette PR. Ensuite : spike du moteur d'IA (lot B).
