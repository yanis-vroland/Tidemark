---
name: implement
description: Implémente une spec validée en test-first.
disable-model-invocation: true
argument-hint: <chemin de la spec>
---

Implémente la spec : $ARGUMENTS

Lance chaque subagent sans paramètre `model` ; si son modèle est indisponible, applique la règle n°7 de `CLAUDE.md` : demande-moi le substitut, ne le choisis jamais seul ([spec 007](https://github.com/yanis-vroland/agentic-dev-workflow/blob/main/docs/specs/007-modele-par-agent.md)).

1. Vérifie que la spec a le statut « validée ». Sinon, arrête-toi et dis-le.
2. Crée une branche `feat/<nom-court>` depuis `main` à jour, et son fichier de journal (section « Reprise de session » de `CLAUDE.md`). À chaque commit, ajoute ou complète l'entrée du jour, puis pousse la branche.
3. Lis les pièges `actif` de `docs/learnings/` dont le domaine ou la rubrique « Où » recoupe la spec. Chaque règle qui s'applique devient un test ou une consigne transmise au subagent `test-writer`.
4. Délègue au subagent `test-writer` l'écriture des tests couvrant chaque critère d'acceptation.
5. Lance les tests et montre-moi qu'ils échouent pour la bonne raison. Attends mon accord avant d'implémenter.
6. Implémente le minimum pour faire passer les tests. Ne modifie aucun test : si un test te semble faux, arrête-toi et explique pourquoi.
7. Lance le lint et les tests jusqu'au vert. Puis revue de sécurité ([spec 006](https://github.com/yanis-vroland/agentic-dev-workflow/blob/main/docs/specs/006-revue-securite-et-hooks-qualite.md)), avant le test humain pour que ses correctifs y passent aussi :
   - Délègue au subagent `security-reviewer` la relecture du diff : transmets-lui le résultat de `git diff main...HEAD`, la spec et la liste des fichiers modifiés. Il n'a pas `Bash` et ne peut pas calculer le diff lui-même.
   - Corrige chaque point « Bloquant » avant de continuer, avec un test qui échoue avant la correction quand c'est testable, puis relance le lint et les tests.
   - Corrige les points « À corriger », ou reporte-les dans « Points d'attention » de la PR avec la raison.
8. Test humain ([spec 005](https://github.com/yanis-vroland/agentic-dev-workflow/blob/main/docs/specs/005-capitalisation-des-pieges.md)) : tu n'as pas accès à l'application démarrée, tu ne peux donc ni simuler ni sauter cette étape.
   - Demande-moi de tester dans l'application démarrée, en proposant les scénarios : le parcours nominal et chaque cas limite de la spec. Attends mon retour.
   - Retour négatif : consigne le symptôme, cherche la cause, ajoute un test qui échoue sur ce cas, corrige jusqu'au vert, puis redemande-moi un test. Un correctif n'est jamais suffisant sans un nouveau retour, quel que soit le nombre de boucles. Si la cause révèle un cas que la spec n'avait pas prévu, complète la spec.
   - Consigne chaque boucle négative dans la rubrique « Corrections et limites » du journal : symptôme, cause, correctif et commit.
   - Si je déclare le test impossible, consigne-le dans le journal et dans la section « Ce que l'humain a vérifié » de la PR, puis continue.
9. Après un retour positif précédé d'au moins une boucle négative, ou si je te demande de retenir quelque chose, délègue au subagent `learning-curator` la capitalisation : spec, branche, symptôme, cause, correctif et date du jour. Le fichier de piège est committé dans la branche. Sans boucle négative, n'invoque pas le subagent.
10. Mets à jour les documents de référence (section « Documents de référence » de `CLAUDE.md`) : statut « livrée » de la fonctionnalité dans le cahier des charges, et architecture technique si le modèle de données, un contrat, la sécurité ou l'infrastructure a changé.
11. Termine par un récapitulatif : chaque critère et son ou ses tests, le résultat du test humain et le nombre de boucles, les pièges appliqués et les pièges créés ou enrichis, les documents de référence mis à jour, les fichiers modifiés, les dépendances ajoutées et pourquoi, les points d'attention pour la revue.
