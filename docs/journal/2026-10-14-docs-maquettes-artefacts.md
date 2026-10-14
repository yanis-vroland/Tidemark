# Journal : maquettes en artefacts Claude

Branche `docs/maquettes-artefacts`.

## 2026-10-14 10:10

### Fait

- Plan mis à jour : exigence de finition des écrans, méthode des maquettes en artefacts Claude, nouveau lot C (charte graphique, en parallèle du spike). Les lots suivants sont renumérotés (socle D, fonctionnalités E à I, publication J).
- Règle « Maquettes dans la spec » du `CLAUDE.md` alignée sur la méthode.
- Tâches de Yanis cochées : PR #3 mergée, label `agent-corrigé` créé avec son accord.

### Décisions

- Écrans soignés, maquettés en artefacts Claude puis transcrits en Flutter (Yanis).
- Proposé par l'agent, à valider dans la PR : un artefact « Design System » pour la charte et un artefact « Design » par spec ; source et captures versionnées dans `docs/maquettes/`, qui font foi (les artefacts sont privés et hors du dépôt) ; jetons Dart de même nom que ceux de la charte ; contrôle en CI des couleurs codées en dur ; tests golden des composants communs ; polices embarquées, sans `google_fonts` en téléchargement ; finition payée sur le lot I (bilan).

### Corrections et limites

- Le spike (lot B) garde une interface brute : son code n'est pas mergé.
- La skill `/spec` ne prévoit pas l'étape de maquette : friction ajoutée au plan.

### Prochaine étape

Yanis relit et merge cette PR. Ensuite : cahier des charges (fin du lot A), puis spike (lot B) et charte (lot C) en parallèle.
