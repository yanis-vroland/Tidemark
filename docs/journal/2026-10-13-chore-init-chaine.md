# Journal : initialisation de la chaîne agentique

Branche `chore/init-chaine`.

## 2026-10-13 17:31

### Fait

- Dépôt créé sur GitHub par Yanis (privé, licence MIT), sans passer par « Use this template ».
- Chaîne appliquée avec `agentic-dev-workflow/scripts/init.sh` : garde-fous, skills, subagents, workflows, modèle de PR, `CLAUDE.md`, documents de référence vides.
- Sections « À ADAPTER » du `CLAUDE.md` complétées : description du projet, règles propres (rien ne quitte l'appareil, sujet sensible, IA derrière une interface, maquettes dans la spec), commandes Flutter prévues.
- `.gitignore` NestJS généré par GitHub remplacé par un `.gitignore` Flutter, qui exclut aussi les fichiers de modèles d'IA.
- README minimal : accroche et statut « en cours de cadrage ».
- Description et topics du dépôt renseignés sur GitHub.

### Décisions

- Nom Tidemark, sujet « journal d'humeur avec IA locale » (Yanis).
- Dépôt privé pendant le spike, public quand le README sera lisible (Yanis).
- Projet borné à 3 semaines pour ne pas retarder P2 de FieldOps (proposé par l'agent).

### Corrections et limites

- `.claude/quality.json` laissé vide : le projet Flutter n'existe pas encore, les hooks de lint et de tests sont donc inactifs.
- Configuration GitHub non faite : application Claude, secret `CLAUDE_CODE_OAUTH_TOKEN`, ruleset sur `main`, label `agent-corrigé`. Tant qu'elle manque, la revue IA de cette PR échouera.
- Le choix des plateformes (Android seul ou iOS + Android) reste ouvert.

### Prochaine étape

Yanis termine la configuration GitHub et merge cette PR. Ensuite : plan du projet, puis ADR-001 (moteur d'IA local) après un spike de 2 jours.
