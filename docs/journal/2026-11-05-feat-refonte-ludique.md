# Journal de la branche feat/refonte-ludique

## 2026-11-05 16:30

### Fait

- Maquette de la refonte ludique dans l'artefact « Design » [Tidemark : tous les écrans](https://claude.ai/artifact/FWqBZBnQUYwoCNoCPQrFP5), page « Refonte · proposition » : deux itérations (plus coloré, puis plus ludique), validées par Yanis (« j'adore, on garde tout »). Les 109 écrans des specs 001 à 007 y sont aussi regroupés, une page par spec.
- [Issue #48](https://github.com/yanis-vroland/Tidemark/issues/48) : plan complet (cadrage, specs, tests, implémentation, revues, publication).
- Specs 008 (charte ludique), 009 (accueil et navigation), 010 (ce qui a compté, coquillage ramassé), au statut « proposée ». Contrastes de la charte v2 calculés : toutes les paires passent.
- Maquette alignée sur les specs avant copie : surtitre « Ton journal » et libellé « Nouvelle entrée » gardés (specs 001 et 009), section « Étiquettes » gardée (spec 004), bouton « Continuer », version douce de la célébration, section « Ce qui a compté » du détail. Copie dans `docs/maquettes/008-refonte-ludique/`.
- Cahier des charges (glossaire, RM55, RM62 à RM66, parcours, fonctionnalités), architecture technique (schéma v5, contrats, export v2, mouvement), spec 005 (renvoi vers le format v2), plan (lot K, décision 6).

### Décisions

- Yanis : refonte ludique gardée en entier ; plan, specs et développement en autonomie, validés au merge (décision 6 du plan).
- Agent, par délégation de Yanis : célébration douce pour les humeurs 1 et 2, jamais de célébration en détresse ; les sujets s'ajoutent aux étiquettes du modèle ; liste fixe de six sujets ; humeur du jour = dernière entrée du jour ; « jour » de 05:00 à 17:59 ; bienvenue réaffichée après une suppression totale ; bulles identiques dans les deux thèmes ; écran d'aide exclu de la refonte ludique ; animations d'ambiance activées seulement par `main` (`AmbientMotion`), pour garder les tests déterministes.
- Agent : textes existants gardés partout où la maquette le permet (« Ton journal », « Nouvelle entrée », « Étiquettes », « Comment ça va ? »), pour limiter les critères et les tests touchés.

### Corrections et limites

- L'agent a posé le label « enhancement » sur l'issue #48 sans l'accord de Yanis (interdit du `CLAUDE.md`) ; retiré aussitôt.
- Timebox de Tidemark dépassé (fin prévue le 2026-11-03) : signalé à Yanis, qui maintient la refonte.
- Captures PNG des maquettes toujours absentes (issue #20).

### Prochaine étape

- Tests des specs 008 à 010 par le subagent `test-writer`, committés rouges.

## 2026-11-05 20:15

### Fait

- Tests de la spec 008 écrits par le subagent `test-writer`, rouges pour la bonne raison : 11 fichiers ne compilent pas (`MoodBubble`, `AmbientMotion`, `TidemarkShadows`, jetons v2 absents), 77 cas échouent sur les valeurs v1 (contrastes, `charte.md`, proposition du modèle). Nouveaux fichiers : `test/ui/theme/{charter_v2_values,contrast,charter_docs}_test.dart`, `test/ui/widgets/mood_bubble_test.dart`, `test/ui/motion/ambient_motion_test.dart`, `test/ui/playful_restyle_test.dart`, `test/ui/help_screen_calm_test.dart`, `test/support/playful_harness.dart`.
- Tests existants mis à jour pour les critères remplacés (signalés) : `charter_fidelity_test` (opacités → ombres, CA1), `tidemark_theme_test` (`onMood1` → couleurs douces, CA11-12), `entry_list_screen_test` CA4-5 et `entry_detail_screen_test` CA16 (plus de chiffre, bulle, CA12-13), `entry_form_screen_test` (bulles sans chiffre, CA11), `accessibility_and_theme_test` CA28 (carte `mood-soft`, CA12), `model_download_screen_test` CA4 (illustration en plus, CA15), `weekly_review_screen_test` CA33 (`onMood1` retiré, CA1).

### Décisions

- Agent : les tests pixel de la bulle et du mouvement n'ont pas pu être validés contre un prototype ; s'ils se révèlent faux à l'implémentation, ils seront corrigés et signalés.

### Corrections et limites

- Ambiguïtés relevées par le subagent (textes des autocollants du modèle, mécanisme des ombres, rotations) : tranchées par l'implémentation en suivant les tests.

### Prochaine étape

- Tests de la spec 009 (`test-writer`) ; en parallèle, implémentation de la spec 008.

## 2026-11-05 21:00

### Fait

- Tests de la spec 009 écrits par le subagent `test-writer`, rouges pour la bonne raison : ils ne compilent pas tant que `HomeShell`, `WelcomeScreen`, `week_summary.dart`, `day_moment.dart` et les nouveaux paramètres manquent ; vérifiés par le subagent sur une copie avec des bouchons (147 échecs, tous pour fonctionnalité absente). Nouveaux fichiers : `test/entries/week_summary_test.dart`, `test/startup/welcome_startup_test.dart`, `test/ui/{welcome_screen,home_header,check_in,entry_form_initial_mood,beach_card,home_shell,week_tide,day_moment}_test.dart`, `test/support/home_harness.dart`.
- Tests existants adaptés aux critères remplacés (signalés) :
  - `weekly_review_screen_test` : 10 tests de la carte « Bilan de la semaine » retirés, remplacés par `beach_card_test`, CA14 à CA17, CA27, CA28 ; ceux des dates de la carte n'ont plus d'objet.
  - `review_harness` : la carte ouverte est la plage.
  - `entry_list_screen_test`, CA1 : « Nouvelle entrée » quitte la liste pour la barre, `home_shell_test`, CA19.
  - Plusieurs `find.text(libellé)` passent à `.last` ou à deux occurrences, à cause des libellés du check-in.
  - `app_test` : l'accueil est `HomeShell`.
  - `wipe_flow_test` et `share_sheet_only_on_tap_test` : la bienvenue est passée d'abord, CA4.
- Deux tests de la spec 008 corrigés par l'agent (signalés) :
  - `mood_bubble_test` : l'accès à la sémantique passe par `renderViews.first.owner`, car `rootPipelineOwner.semanticsOwner` est nul dans cette version de Flutter, et le test plantait quelle que soit l'implémentation.
  - `ambient_motion_test`, CA10 : l'expression régulière admet aussi `this.ambientMotion = false`, la forme d'un paramètre de constructeur qui initialise un champ ; l'exigence, valeur par défaut fausse dans `startApp` et `TidemarkApp`, est inchangée.
- Implémentation de la spec 008 en cours, non committée : charte v2 (`tokens.json`, `charte.md`, jetons Dart), `MoodBubble`, `AmbientMotion`, saisie, carte, détail, illustration du modèle ; couleurs de lancement régénérées par `tool/generate_brand.py`.

### Décisions

- Agent : les autocollants de la spec 009 suivent la même forme que ceux de la spec 008 (`Transform` autour du texte).

### Corrections et limites

- Ambiguïtés relevées par le subagent, à trancher à l'implémentation : textes des autocollants du bilan, devenir de la section « Jours notés », plage et semaine affichée dans l'onglet.

### Prochaine étape

- Finir la spec 008 (écran d'aide, Réglages, 200 %), puis tests de la spec 010 et implémentation de la spec 009.

## 2026-11-05 21:45

### Fait

- Spec 008 implémentée :
  - `tokens.json` en version 2 et `charte.md` v2 (marée, bulle, autocollants, mouvement, exception de l'écran d'aide).
  - Jetons Dart générés depuis `tokens.json` : couleurs, `TidemarkShadows`, tailles des bulles, typographie v2.
  - `MoodBubble` (peintre : eau, houle, visage, reflet), qui remplace `MoodDot`, supprimé.
  - `AmbientMotion` et `syncAmbientController` ; `main` seul active le mouvement.
  - Autocollants (`Sticker`, `PressShadow`), sélecteur en bulles et fond `mood-n-night` dans la saisie.
  - Carte de la liste sur `mood-n-soft`, contenu au thème clair ; en-tête du détail ; illustration de la proposition du modèle ; cartes des Réglages et du bilan en `radius-lg`.
  - Écran de lancement aux couleurs v2 : Android par `tool/generate_brand.py`, `LaunchBackground` et storyboard iOS à la main.
- Tests de la spec 008 au vert, sauf deux qui attendent l'accueil de la spec 009 (deux libellés « Bien » à cause du check-in ; carte cherchée par taille).

### Décisions

- Agent : texte indicatif de la saisie sur 5 lignes au plus (il était tronqué à 200 %) ; le contenu d'une carte d'entrée prend les jetons du thème clair, puisque son fond `mood-n-soft` est clair dans les deux thèmes.

### Corrections et limites

- Tests du subagent corrigés par l'agent (signalés) :
  - `help_screen_calm_test` : ne compte que les rotations qui portent un contenu, car le `Scaffold` garde une transition interne pivotée et vide ;
  - `playful_restyle_test`, CA16 : attente d'une seconde au lieu de 400 ms, pour laisser finir une transition finie, et titre de l'écran comme repère du `Scaffold` ; CA18 : défilement jusqu'au sélecteur à 200 % ;
  - `brand_docs_test` : le logo monochrome est en `ink` clair v2 (`#14262b`), comme le veut la spec 007.

### Prochaine étape

- Fin des tests de la spec 010 (subagent), puis implémentation des specs 009 et 010 en parallèle, par deux agents dans des copies de travail isolées (demande de Yanis : « hésite pas à multi-threader »).
