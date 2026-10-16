# CLAUDE.md

Contexte projet pour l'agent de code. Les sections marquées « À ADAPTER » sont propres à chaque projet.

## Projet

Tidemark : journal d'humeur mobile (Flutter) dont l'IA tourne entièrement sur l'appareil. Pour une personne qui veut suivre son humeur et en comprendre les tendances sans qu'aucune donnée ne quitte son téléphone. Projet de démonstration, fictif et public à terme.

Règles propres au projet :

- **Rien ne quitte l'appareil.** Aucun appel réseau avec une donnée de l'utilisateur : pas de compte, pas de synchronisation, pas d'analytics, pas d'API d'IA distante. Le seul téléchargement admis est celui du modèle, et il est documenté. Toute exception passe par un ADR.
- **Sujet sensible.** L'app ne donne aucun conseil médical. En cas de détresse détectée, elle affiche un écran d'aide fixe (3114, numéro national de prévention du suicide), jamais une réponse générée par le modèle. Chaque garde-fou est couvert par des tests.
- **L'IA derrière une interface.** Le modèle local reste isolé derrière une abstraction, avec une implémentation factice pour les tests et la CI, qui n'exécutent jamais de vrai modèle.
- **Données de test fictives**, rédigées pour le projet.
- **Maquettes dans la spec.** Toute spec qui touche un écran contient sa maquette : un artefact Claude de type « Design », construit sur la charte Tidemark (artefact « Design System »), et validé par l'humain avant les tests. Elle couvre aussi les états vide, chargement et erreur, en thème clair et sombre. La source HTML et les captures sont versionnées dans `docs/maquettes/` et font foi ; la spec affiche les captures et donne le lien de l'artefact. Le code n'utilise que les jetons de la charte. Méthode détaillée : `docs/plan.md`, « Maquettes en artefacts Claude ».

## Stack et commandes

Flutter 3.47.7 (Dart 3.13.5), iOS 16.4+ et Android.

- Installer : `scripts/setup.sh` (`flutter pub get`, puis `scripts/fetch-llama-native.sh`, moteur llama.cpp vérifié par SHA-256 ; à relancer après chaque clonage et avant toute construction à installer)
- Lancer : `flutter run`
- Tests : `flutter test` (jamais de vrai modèle d'IA : seulement `FakeMoodAnalyzer`)
- Lint : `dart analyze --fatal-infos` ; format : `dart format lib test`
- Garde-fous : `test/guards/` (aucune couleur en dur hors de `lib/ui/theme/`) et `test/ui/theme/charter_fidelity_test.dart` (le thème reprend exactement les jetons de `docs/maquettes/000-charte/tokens.json`)

Les hooks de Claude Code lisent les commandes de lint (sur un fichier) et de tests dans `.claude/quality.json`, à tenir à jour avec cette section ([spec 006](https://github.com/yanis-vroland/agentic-dev-workflow/blob/main/docs/specs/006-revue-securite-et-hooks-qualite.md)) : clés `lint` (`scripts/lint-dart.sh`, qui n'analyse que les fichiers Dart) et `test`.

## Langue

- Code en anglais : variables, fonctions, classes, entités, tables, routes d'API.
- Tout le reste en français : README, ADR, specs, commentaires, messages de commit, PR.
- Réponses à l'humain en français, y compris les points d'étape et les messages courts pendant une tâche longue.
- Commits au format Conventional Commits, préfixe en anglais, message en français :
  `feat: ajout du CRUD des machines`

## Méthode de travail

1. Toute modification du comportement observable exige une spec validée dans `docs/specs/` :
   - nouvelle fonctionnalité (feat) : nouvelle spec ;
   - correction (fix) : référence à la spec concernée et test de non-régression qui échoue avant la correction ; si le bug révèle un cas non prévu, compléter d'abord la spec ;
   - sans changement de comportement (refactor, perf, test, chore, ci, docs) : la description de la PR suffit. Si le changement modifie un comportement malgré son préfixe, il relève des cas précédents.

   Pour les deux premiers cas, sans spec, proposer d'en rédiger une et attendre la validation.
2. Test-first ([ADR-003](https://github.com/yanis-vroland/agentic-dev-workflow/blob/main/docs/adr/003-strategie-test-first.md)) :
   - écrire les tests à partir des critères d'acceptation (subagent `test-writer`), vérifier qu'ils échouent pour la bonne raison, et les committer avant l'implémentation, dans un commit séparé ;
   - relire les tests avant d'implémenter, et renforcer toute vérification qui passerait sans implémentation ;
   - implémenter jusqu'au vert ;
   - sur les garde-fous (hooks, scripts de sécurité, vérifications de CI), contrôle par mutation : désactiver chaque protection une fois et vérifier qu'au moins un test échoue.
3. Ne jamais modifier ou supprimer un test pour le faire passer sans le signaler explicitement.
4. Face à un choix d'architecture structurant, s'arrêter et proposer un ADR dans `docs/adr/` au lieu de trancher seul. L'agent peut rédiger l'ADR en entier, au statut « proposé » ; il ne passe à « accepté » et n'est mergé qu'après validation humaine ([ADR-002](https://github.com/yanis-vroland/agentic-dev-workflow/blob/main/docs/adr/002-place-revue-humaine.md)).
5. Après la revue IA d'une PR, et une fois les corrections poussées, publier un commentaire `## Réponse à la revue IA` dans la PR. Chaque point du rapport y reçoit une suite : corrigé (avec le SHA du commit), non suivi et pourquoi, ou reporté (avec l'issue). La description de la PR renvoie vers ce commentaire sans le répéter. Ne pas se contenter de modifier la description : cela ne laisse aucune trace dans la chronologie et ne notifie personne.
6. PR : toujours basée sur `main` (`gh pr create --base main`), jamais sur la branche d'une autre PR ; si un travail dépend d'une PR non mergée, attendre son merge ou regrouper les deux. Une PR qui touche les mêmes fichiers qu'une PR encore ouverte est rebasée par l'agent après le merge de la première, au lieu de laisser la résolution du conflit à l'humain. Pousser tous les commits avant d'annoncer qu'une PR est prête, et vérifier après le merge que son dernier commit est bien sur `main`.
7. Modèle des subagents ([ADR-005](https://github.com/yanis-vroland/agentic-dev-workflow/blob/main/docs/adr/005-choix-du-modele-par-agent.md), [spec 007](https://github.com/yanis-vroland/agentic-dev-workflow/blob/main/docs/specs/007-modele-par-agent.md)) :
   - tout subagent de `.claude/agents/` déclare `model: sonnet`, `opus` ou `haiku`, choisi selon le critère de l'ADR-005 ; la PR qui l'ajoute ou change son modèle cite ce critère en une ligne. `verifier-modeles.sh` refuse en CI un modèle absent, `inherit` ou hors liste ;
   - lancer un subagent sans paramètre `model` : son en-tête est la seule source du choix ;
   - modèle déclaré indisponible : ne jamais choisir seul un substitut. S'arrêter et demander à l'humain quel modèle utiliser, en rappelant le subagent, le modèle déclaré, l'erreur reçue et le critère de l'ADR-005. Le substitut vaut pour la session (seul cas où le paramètre `model` est passé), sans modifier l'en-tête, et il est consigné dans « Corrections et limites » du journal et dans « Points d'attention » de la PR. Si l'humain répond de ne pas lancer le subagent, l'étape est consignée comme sautée, jamais présentée comme faite.

## Reprise de session

Le dépôt est la seule mémoire : une session doit pouvoir être fermée à tout moment et reprise plus tard, sur n'importe quel poste, sans perte ([spec 004](https://github.com/yanis-vroland/agentic-dev-workflow/blob/main/docs/specs/004-reprise-de-session.md)).

- Ne jamais enregistrer une règle, une décision ou un état dans la mémoire locale de Claude Code (désactivée par `autoMemoryEnabled` dans `.claude/settings.json`). Une règle de travail va dans `CLAUDE.md`, un skill ou un subagent, par une PR ; un état va dans le journal de la branche ; un piège du code découvert au test humain va dans `docs/learnings/` (un fichier par piège), relu au cadrage des fonctionnalités suivantes.
- Journal : un fichier par branche, `docs/journal/AAAA-MM-JJ-<branche>.md` (`/` remplacés par `-`, date de création), créé au premier commit de la branche. Chaque entrée commence par `## AAAA-MM-JJ HH:MM` (heure locale) et contient quatre rubriques : **Fait**, **Décisions** (et qui a décidé), **Corrections et limites**, **Prochaine étape**.
- À chaque commit de travail : ajouter une entrée ou compléter celle du jour dans le même commit, puis pousser la branche.
- Ne jamais modifier le fichier de journal d'une autre branche, ni un fichier déjà mergé : la CI le refuse (`verifier-journal.sh`).
- Au début d'une session, le hook `session-start.sh` met la branche à jour si c'est sans risque, et affiche son état et la dernière entrée de journal. Repartir de la « Prochaine étape » de cette entrée. Si la branche est en retard sur `main`, proposer un rebase sans le faire.

## Définition du « done »

- Chaque critère d'acceptation de la spec est couvert par au moins un test.
- Lint, format et tests au vert.
- Test humain positif dans l'application démarrée pour tout changement de comportement observable (fonctionnalité ou correction), ou son impossibilité consignée dans le journal et la PR ; sans changement de comportement, la PR l'indique « sans objet » ([spec 005](https://github.com/yanis-vroland/agentic-dev-workflow/blob/main/docs/specs/005-capitalisation-des-pieges.md)).
- Après une boucle négative au test humain : piège capitalisé dans `docs/learnings/` par le subagent `learning-curator`, ou « rien écrit » motivé dans le journal.
- Aucun TODO sans ticket associé.
- Entrée de journal de la branche à jour et poussée.
- Documentation mise à jour si un comportement public change, dont le cahier des charges et l'architecture technique (section « Documents de référence »).

## Interdits

- Lire, créer ou modifier un fichier `.env*`, sauf `.env.example`.
- Committer un secret, une clé ou un token.
- Ajouter une dépendance sans la justifier dans la PR.
- Pousser directement sur `main`.
- Merger une PR : seul l'humain merge ([ADR-002](https://github.com/yanis-vroland/agentic-dev-workflow/blob/main/docs/adr/002-place-revue-humaine.md)).
- Créer une issue ou poser un label sans l'accord de l'humain. Seule exception : le label `bug` sur une issue de bug.

## Documents de référence

Une information vit à un seul endroit ; les autres documents y renvoient.

- `docs/cahier-des-charges-fonctionnel.md` : le quoi. Acteurs et droits, glossaire, règles métier, parcours, fonctionnalités par phase avec un lien vers leur spec, questions métier ouvertes.
- `docs/architecture-technique.md` : le comment. Modèle de données, contrats entre composants, conventions d'API, sécurité, infrastructure, index des ADR.
- `docs/specs/` détaille une fonctionnalité ; `docs/adr/` explique un choix.

Lire le cahier des charges avant d'écrire une spec, et l'architecture technique avant de toucher aux données, à un contrat, à la sécurité ou à l'infrastructure. Les noms du code sont ceux du glossaire.

Mettre à jour dans la même PR :
- le cahier des charges : nouvelle fonctionnalité, changement d'acteur, de droit, de terme ou de règle métier, changement de statut d'une spec ;
- l'architecture technique : changement du modèle de données, d'un contrat, de la sécurité ou de l'infrastructure, ADR accepté.

Une règle métier non tranchée va dans les questions ouvertes du cahier des charges : ne jamais l'inventer.

## Architecture

iOS + Android (décision de Yanis, 2026-10-13). Moteur d'IA local : `llamadart` avec Qwen2.5-1.5B-Instruct, sortie contrainte par schéma JSON ([ADR-001](docs/adr/001-moteur-ia-local.md)). Stockage : `drift` chiffré, clé dans le trousseau ou le Keystore ([ADR-002](docs/adr/002-stockage-local-chiffre.md)). Vue d'ensemble : `docs/architecture-technique.md`.

- `lib/ui/theme/` : jetons de la charte (`TidemarkColors`, `TidemarkSpacing`, `TidemarkRadius`, `TidemarkSize`, `TidemarkTypography`) et `buildTidemarkTheme`. Seul endroit où une couleur s'écrit en dur ; ailleurs, `context.colors` ou le `ThemeData`.
- `lib/analysis/` : `MoodAnalyzer`, `Tag`, `TagKind`, `AnalysisResult` (`Tagged`, `Untagged`) et `FakeMoodAnalyzer`.
- Polices embarquées dans `assets/fonts/` (licence OFL) : aucune police chargée depuis le réseau.
