# Journal : README final et vérifications de publication (lot J)

Branche `docs/readme-final`, partie de `main` après le merge de la PR #28. Sans changement de comportement : documentation, captures, nettoyage de fichiers générés.

## 2026-10-16 09:12

### Fait

- README final : pitch, emplacement du GIF iPhone (« à venir, filmé par Yanis »), 4 captures de l'app réelle, schéma Mermaid, notions d'IA, lancement en 3 commandes, mesures du spike et essai sur l'émulateur, limites, méthode, licences.
- Captures : `docs/maquettes/` n'a aucun PNG (issue #20 ouverte), donc captures de l'app réelle dans `docs/captures/` (détail d'une entrée étiquetée en clair et en sombre, bilan de la semaine, Réglages), réduites à 540 × 1200.
  - Émulateur `tidemark_api35` trouvé éteint : démarré sans fenêtre par l'agent.
  - L'app installée était une version debug du 2026-10-16 08:26 (bandeau « DEBUG ») : remplacée, données conservées (`adb install -r`), par un build release de `main` (15b4486) pour des captures sans bandeau.
  - Données déjà présentes, fictives (saisies aux essais précédents). La liste n'est pas capturée : elle montre deux entrées de test du garde-fou (« J ai envie de mourir »), à ne pas mettre en vitrine.
- Chiffres comptés, pas recopiés :
  - `flutter test --reporter json` sur `main` : 1 658 tests réussis, 0 échec, 0 ignoré, 70 fichiers ;
  - `gh pr list --state all` : 27 PR, toutes mergées (#1 à #28 ; #20 est une issue) ;
  - 6 specs, 204 critères d'acceptation (`^- CA[0-9]+ :`) ; 5 ADR, dont 3 acceptés et 2 proposés (004, 005).
- **gitleaks 8.30.1** (même version que la CI, installée par brew) sur tout l'historique, toutes les références (`gitleaks detect --redact --log-opts=--all`) : 85 commits analysés, **aucune fuite**. `gitleaks git` est refusé par l'isolation du worktree ; `detect` est l'ancienne forme de la même commande.
- **Données réelles** : `git grep -i` et `git log --all -p` sur les noms des employeurs et clients exclus (liste tenue hors du dépôt) : 0 occurrence avant cette branche. Adresses mail du dépôt : seulement `test@example.com`, `test@example.invalid` et l'URL piégée `huggingface.co@evil.com` d'un test. Auteur des commits : l'adresse personnelle de Yanis (gmail), aucune adresse professionnelle.
- **Licences** : tableau dans `docs/licences.md`.
  - Qwen2.5-1.5B-Instruct GGUF : Apache-2.0, vérifié à la révision épinglée `91cad511…` sur Hugging Face (fichier `LICENSE`, en-tête du README, API).
  - Polices Bricolage Grotesque et Figtree : OFL 1.1 (fichiers dans `assets/fonts/`).
  - Material Icons : Apache-2.0. llama.cpp, `llamadart-native`, SQLite3MultipleCiphers : MIT.
  - 116 paquets Dart (`flutter pub deps --json`, fichier `LICENSE` dans `~/.pub-cache`) : BSD-3-Clause, MIT, Apache-2.0, BSD-2-Clause ; aucun copyleft, aucun sans licence.
- **Références à l'espace de travail privé** :
  - 12 fichiers générés de l'app du spike (`spike/app/…`) étaient versionnés par erreur depuis le commit `e7ad27f` (charte), dont `flutter_native_integration.env`, qui contient des chemins `/Users/yvroland/…`. Supprimés du dépôt, et `/spike/` ajouté au `.gitignore`. Ils restent dans l'historique : chemins locaux, aucun secret.
  - `docs/projets/` : cité dans le plan (lot J) et dans un journal mergé (`2026-10-14-chore-nettoyage-workflows.md`, non modifiable) ; expliqué dans le README (« notes privées de l'espace de travail de l'auteur »).
- Plan : case « Vérification » du lot J cochée ; case README complétée sans être cochée (GIF et maquette côte à côte manquent). Aucune autre section touchée.

### Décisions

- Captures de l'app réelle plutôt que des maquettes, faute de PNG de maquettes (consigne de l'agent principal).
- Remplacement de la version debug installée sur l'émulateur par un build release de `main`, données conservées ; liste et écran d'aide non capturés, pour ne pas montrer ni ajouter d'entrées de détresse (agent, par délégation de Yanis du 2026-10-16).
- Suppression des fichiers générés du spike et ajout de `/spike/` au `.gitignore` : l'ADR-001 dit que le code du spike n'est pas mergé (agent, par délégation de Yanis du 2026-10-16).
- Dans le README, la PR #23 mergée avant ses revues est dite, pas cachée (agent).
- PR en brouillon : le GIF et le passage en public dépendent de Yanis (consigne de l'agent principal).

### Corrections et limites

- Pas de test-first ni de mutation : aucun changement de comportement.
- Test humain sans objet pour le code ; le GIF iPhone reste à filmer par Yanis.
- La mesure sur 20 entrées avec l'app réelle (spec 004) n'est toujours pas faite : le README le dit.
- Le bilan capturé n'a pas de texte du modèle (« Pas de texte pour cette semaine ») : la capture ne prouve pas la mise en mots.
- L'installation release sur l'émulateur remplace la version debug d'un autre agent ou de Yanis : à réinstaller par `flutter run` si besoin.

### Prochaine étape

Voir l'entrée suivante.

## 2026-10-16 09:25

### Fait

- PR #34 ouverte en brouillon ; revue `reviewer` (1 bloquant, 7 à corriger, 8 suggestions), suites dans le commentaire « Réponse à la revue IA » de la PR.
- **Bloquant** : la première entrée de ce journal citait en clair les noms des employeurs et clients exclus, dans le commit 462ceb1 et dans la description de la PR. Retirés du fichier (ce commit) et de la description (`gh pr edit`). Ils restent dans l'historique de la branche (462ceb1, donc `refs/pull/34/head`) et dans l'historique des révisions de la description : voir « Corrections et limites ».
- README corrigé : schéma (chiffres du bilan affichés sans passer par le modèle, semaine non sensible seule envoyée), cause réelle du bilan sans texte (semaine sensible, spec 006 CA20 : entrées de test du garde-fou cette semaine), export cité comme exception dans le pitch, garde-fou réseau limité au Dart, dictée du clavier du système, classifieur comme piste d'amélioration (engagement du plan, décision 2), dates (« planifié sur 3 semaines »), Q4_K_M (4 à 5 bits par poids), arbitrage `flutter_edge_ai`, mutations survivantes, « depuis la #2 ».
- Nouvel essai du vrai modèle sur l'émulateur, avec une entrée fictive correctement orthographiée (« Footing au parc ce matin, puis un bon repas en famille. », humeur 4) : analyse de 4 minutes environ, résultat sans étiquette (« Aucune étiquette n'a été proposée pour cette entrée »). Entrée supprimée ensuite, pour rendre l'émulateur dans l'état trouvé. Le README le dit (une entrée étiquetée sur deux essayées).
- `docs/licences.md` : `sky_engine` regroupe aussi les licences permissives du moteur Flutter.

### Décisions

- Pas de réécriture d'historique ni de force-push : interdits sans accord explicite de Yanis (règles communes du 2026-10-16). Décision demandée à Yanis (agent).
- Captures du détail gardées malgré les accents manquants de l'entrée (« journee », « ballade ») : la seule entrée ressaisie correctement n'a reçu aucune étiquette ; une recapture demande une entrée étiquetée, à faire avec le GIF (agent, par délégation de Yanis du 2026-10-16).

### Corrections et limites

- **Noms exclus dans l'historique de la PR #34** : le commit 462ceb1 les contient. Ce commit-ci les retire du fichier, mais 462ceb1 reste atteignable par `docs/readme-final` et `refs/pull/34/head`, que GitHub garde même après la suppression de la branche. Pour les effacer avant le passage en public, il faut réécrire la branche (un seul commit propre) et la pousser en force, ce qui met à jour `refs/pull/34/head` ; et supprimer la révision d'origine de la description dans son historique d'édition (menu « edited » de la PR). Les deux demandent l'accord de Yanis.
- L'émulateur `tidemark_api35` a 2 Go de mémoire (`hw.ramSize=2G`), pas les 6 Go de l'AVD du spike : l'app y swappe pendant l'analyse. L'absence d'étiquette peut venir du modèle comme de la mémoire ; non investigué.
- L'entrée étiquetée de 08:27 a été saisie et analysée avant cette branche, par une version debug installée à 08:26 dont la branche n'est pas connue ; `lib/main.dart` branche toujours le vrai `LlamaMoodAnalyzer`.
- Réglage de l'émulateur modifié : écriture au stylet désactivée (`stylus_handwriting_enabled 0`), qui interceptait la saisie par `adb`.
- Au merge de `feat/integrite-moteur-modele` (ADR-004), la limite « le modèle n'est vérifié que par sa taille » du README devra être mise à jour.

### Prochaine étape

Yanis : accord ou refus pour la réécriture de la branche (bloquant de la revue), puis GIF iPhone, recapture d'une entrée étiquetée bien orthographiée, et passage en public.
