# Journal de la branche docs/maquettes-etats

## 2026-11-06 00:45

### Fait

- Issue #50, demandée par la revue IA de la PR #49 et créée avec l'accord de Yanis : la maquette de la refonte dessine maintenant les états manquants, en clair et en sombre, dans l'artefact « Design » *Tidemark : tous les écrans* (page « Refonte · proposition », rangées « États ») et dans sa copie versionnée. Ce sont :
  - l'accueil vide sous le check-in, en lecture et en erreur ;
  - l'onglet « Semaine » en calcul et en erreur ;
  - le coquillage ramassé sans rang, et la version douce en sombre.
- `Journal`, `Semaine` et `Enregistre` prennent un état (`state`, `norank`) ; 13 nouveaux écrans les importent. Textes repris du code de `main`.

### Décisions

- Agent : en lecture, l'accueil ne montre que l'en-tête, sans check-in ni plage, comme le code (spec 009, CA11 et CA17).

### Corrections et limites

- Captures PNG toujours absentes (#20).

### Prochaine étape

- PR en brouillon ; validation des maquettes par Yanis au merge.
