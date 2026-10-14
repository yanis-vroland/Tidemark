# Journal : nettoyage des workflows en doublon

Branche `chore/nettoyage-workflows`.

## 2026-10-14 08:45

### Fait

- Suppression de `claude-code-review.yml` et `claude.yml`, ajoutés par `/install-github-app` (PR #2).
- Section « CI » de l'architecture technique renseignée : les deux workflows restants et l'absence de job requis sur `main`.

### Décisions

- Suppression des deux workflows, décidée par Yanis (`docs/projets/tidemark.md` de l'espace de travail, 2026-10-13).
- `claude-code-review.yml` doublait `ai-review.yml` : deux revues par PR, la seconde sans les consignes de `reviewer.md` ni le modèle de l'ADR-005, et avec une action non épinglée par SHA (`@v1`).
- `claude.yml` (assistant appelé par `@claude`) n'a pas d'équivalent dans la chaîne, mais personne ne l'utilise et il reprend la même action non épinglée. Le remettre plus tard passera par la chaîne P1, pas par ce dépôt seul (agent).

### Corrections et limites

- Label `agent-corrigé` toujours absent : sa création attend l'accord de Yanis (interdit du `CLAUDE.md`).
- Cette PR ne touche pas `ai-review.yml` : la revue IA doit donc tourner normalement dessus.

### Prochaine étape

Yanis relit et merge cette PR. En parallèle : PR du plan du projet (`docs/plan.md`).
