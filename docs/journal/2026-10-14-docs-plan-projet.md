# Journal : plan du projet

Branche `docs/plan-projet`.

## 2026-10-14 09:05

### Fait

- Plan du projet rédigé dans `docs/plan.md` : objectif, périmètre en trois niveaux, calendrier sur 3 semaines, lots A à I, tâches de Yanis, questions ouvertes, frictions de la chaîne.
- README : renvoi vers le plan.

### Décisions

- Plan versionné dans `docs/plan.md`, contrairement au `plan.md` local du template, pour respecter la spec 004 (agent, à valider par Yanis).
- Proposé par l'agent, à valider par Yanis : Foundation Models écarté du spike (pas d'Android) ; garde-fou de détresse (lot E) livré avant l'étiquetage (lot F) ; bilan de la semaine conditionnel ; point d'arrêt le 2026-10-24.
- Dictée et classifieur de détresse sortis du MVP en attendant la réponse de Yanis (questions 1 et 2 du plan).

### Corrections et limites

- Cahier des charges non rempli dans cette PR : il demande des règles métier que seul Yanis tranche (glossaire, termes de détresse). Il fait l'objet de la PR suivante du lot A.
- La dictée Android via la reconnaissance du système n'a pas été vérifiée en détail : le risque d'envoi aux serveurs de Google est à confirmer si Yanis veut garder la dictée. (Complété le même jour : le risque existe aussi sur iOS, voir l'entrée de 09:20.)

### Prochaine étape

Yanis relit le plan et répond aux trois questions. Ensuite : cahier des charges (fin du lot A), puis spike du moteur d'IA (lot B).

## 2026-10-14 09:20

### Fait

- Corrections après la revue IA de la PR #4 : téléchargement du modèle ajouté au périmètre et au lot F (deux specs) ; question sur la dictée étendue à iOS ; point d'arrêt sans coupe du lot F ; numérotation des ADR précisée ; « chaîne P1 » et P2 définis ; vérification des références privées ajoutée au lot I ; migration des questions vers le cahier des charges prévue au lot A ; Foundation Models à réexaminer si la cible devient iOS seul.
- Contrôles de la CI relancés en local : journal conforme sur les deux branches, gitleaks (image Docker 8.30.1) sans fuite.

### Décisions

- Les sept points de la revue sont suivis (agent). Réponse publiée en commentaire de la PR.

### Corrections et limites

- Le job « Revue IA » est rouge : `permission_denials_count: 1`, alors que le rapport est bien publié. Les logs ne disent pas quelle action a été refusée.
- La PR #4 a aussi reçu une revue de `claude-code-review.yml`, encore présent sur `main` tant que la PR #3 n'est pas mergée.

### Prochaine étape

Yanis relit le plan et répond aux trois questions. Ensuite : cahier des charges (fin du lot A), puis spike du moteur d'IA (lot B).
