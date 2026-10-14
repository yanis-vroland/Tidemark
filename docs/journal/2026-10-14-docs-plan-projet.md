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
- La dictée Android via la reconnaissance du système n'a pas été vérifiée en détail : le risque d'envoi aux serveurs de Google est à confirmer si Yanis veut garder la dictée.

### Prochaine étape

Yanis relit le plan et répond aux trois questions. Ensuite : cahier des charges (fin du lot A), puis spike du moteur d'IA (lot B).
