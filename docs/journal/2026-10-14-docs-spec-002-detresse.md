# Journal : spec 002, garde-fou de détresse

Branche `docs/spec-002-detresse`.

## 2026-10-14 20:15

### Fait

- PR #13 mergée par Yanis ; son dernier commit (3378a64) est sur `main`, dont la CI est revenue au vert. Branches locales déjà mergées supprimées.
- Spec 002 rédigée au statut « brouillon » : règles de détection (texte normalisé, expressions en mots entiers, sans négation ; série d'humeurs à 1), liste de 72 expressions, 26 critères d'acceptation, données, cas limites.
- Maquette en artefact « Design » (11 écrans) : écran d'aide (nominal, appel impossible, clair et sombre), Réglages (nominal, chargement, erreur, clair et sombre), liste avec l'icône « Réglages ». Copie dans `docs/maquettes/002-garde-fou-detresse/`.
- Cahier des charges : RM25 précisée, RM29, glossaire (`LowMoodSensitivity`, `SettingsRepository`), statut « spec brouillon ».

### Décisions

- Seuil de la série réglable par la personne, spec et maquettes à mettre à jour (Yanis, 2026-10-14). Trois degrés, « Normale » par défaut, aucun qui désactive le garde-fou (agent, à valider par Yanis).
- Écran d'aide : 3114 et 112, sans accès permanent hors détection (Yanis, 2026-10-14).
- Entrées « en attente » antérieures au lot : vérifiées au démarrage, sans écran d'aide (Yanis, 2026-10-14).
- Rappel maximal : pas de gestion de la négation (Yanis, 2026-10-14).
- Fidélité de la liste des termes vérifiée par un test qui relit la spec (agent).

### Corrections et limites

- Pas de captures PNG, comme pour la maquette 001.
- La liste des termes exclut « me tue » et « mort » seuls (trop fréquents) : à confirmer par Yanis.

### Prochaine étape

Yanis valide la spec, la liste des termes, les degrés et la maquette. Ensuite : tests par le subagent `test-writer`, committés seuls, puis implémentation (branche `feat/garde-fou-detresse`).
