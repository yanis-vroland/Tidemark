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

## 2026-11-05 22:10

### Fait

- Tests de la spec 010 écrits par le subagent `test-writer`, rouges pour la bonne raison : le dépôt ne compile pas sans `Topic`. Le subagent les a vérifiés sur une copie avec des signatures vides : 48 échecs sur 61 (sujets, export, base) et 87 sur 99 (interface), tous pour fonctionnalité absente. Sur un prototype jetable, 95 tests sur 99 passent, ce qui valide les sélecteurs et les captures.
- Nouveaux fichiers : `test/entries/topic_test.dart`, `test/storage/schema_v5_test.dart`, `test/export/export_v2_test.dart`, `test/distress/topics_guard_test.dart`, `test/ui/{topics_form,topics_detail,celebration}_test.dart`, `test/support/celebration_harness.dart` ; `fake_entry_repository` gère les sujets.
- Tests existants adaptés aux critères remplacés (signalés) :
  - la liste réapparaît après « Continuer » de la célébration (spec 001, CA9 et CA10 ; `entry_form_screen_test`, `distress_flow_test`, `check_in_test`, `home_shell_test`, `robustness_test`, `analysis_wiring_test`, `share_sheet_only_on_tap_test`) ;
  - la proposition du modèle vient après la célébration (`model_offer_flow_test`, assistant `save`) ;
  - export en version 2 (`journal_exporter_test`, `journal_export_test`, `my_data_section_test`) ;
  - schéma en version 5 (`analysis_storage_test`) ;
  - `ensureVisible` avant « Annuler », qui passe sous la section « Ce qui a compté » (`entry_form_screen_test`, CA30).
- Artefact « Design System » Tidemark mis à jour en v2 : `tokens.json` et brand book repris de `charte.md`.

### Décisions

- Agent : les sujets choisis restent après une erreur d'enregistrement et partent avec « Réessayer » ; l'exporteur range les sujets dans l'ordre de la liste, quel que soit l'ordre reçu.

### Corrections et limites

- Les aperçus des composants de l'artefact « Design System » (MoodSelector, EntryCard…) sont encore en v1 ; le dépôt fait foi.
- Le subagent a lancé `dart format` sur `lib/` une fois ; aucun fichier de `lib/` n'a changé.

### Prochaine étape

- Fusionner l'implémentation de la spec 009 (agent en copie isolée), puis implémenter la spec 010.

## 2026-11-05 23:30

### Fait

- Spec 009 implémentée par un agent dans une copie isolée (`impl-009`), puis spec 010 par un second agent en parallèle (`impl-010`), qui a fusionné `impl-009` : la migration en version 5 porte `welcome_shown` et `entry_topics`.
- Corrections après fusion (`fix-008-009`) :
  - puces d'étiquette remises en `tide-soft` (spec 004, CA26) ;
  - écran d'aide : titre en `title` et numéro en `stat`, car « Appeler le 112 » passait sous la zone fixe ;
  - mer de l'illustration du modèle en `hero-wave-2`, car `sea` sombre vaut `tide` clair.
- Intégration poussée sur `feat/refonte-ludique` : 2 497 tests au vert, format et analyse propres, `generate_brand.py --check` et noms exclus au vert.
- Revue `security-reviewer` : rien de bloquant ni à corriger. Deux points « À noter », traités :
  - un sujet inconnu en base rendait le journal illisible ;
  - lecture des sujets en `isIn` non borné.
- Revue `reviewer`, constats traités par deux agents en parallèle (`fix-accueil`, `fix-sujets`) et par l'agent :
  - échelle de texte plafonnée à 130 % sur l'accueil : retirée, et tests CA27 renforcés sur la taille rendue ;
  - contraste du bandeau de la plage (3,96:1) : passé sur `hero-wave-1` ;
  - accueil rendu paresseux, thème clair des cartes en constante ;
  - `Topic` en anglais avec libellés français ;
  - flottement décalé par bulle, bulles d'air dans la saisie, voilier animé le soir seulement ;
  - étiquette du groupe « Ce qui a compté » ;
  - tests de migration depuis les versions 1 à 3 ;
  - dessin du coquillage mis en commun.
- Specs complétées :
  - 008 : CA12 et CA19, le contenu des cartes d'entrée garde les jetons clairs et remplace la spec 004, CA30, pour la carte ; nouvelles paires de contraste ; mouvement ;
  - 009 : CA27, le texte grandit sans plafond ; coquille ;
  - 010 : noms du code et sujet inconnu ignoré.
- Architecture : navigation (`Stack`, `Offstage`, `TickerMode`) et stockage des sujets. Maquette `Journal` alignée sur le jeton `sea` sombre.
- Contrôle par mutation des nouvelles protections lancé (agent en copie isolée).

### Décisions

- Agent, par délégation de Yanis :
  - la carte d'entrée garde les jetons clairs sur son fond `mood-n-soft`, pour la lisibilité ;
  - le bilan garde la mise en page de la spec 006 hors de l'onglet (`showBack: true`) et montre les autocollants dans l'onglet ;
  - l'onglet « Semaine » n'est construit qu'à sa première ouverture, pour ne pas lancer la mise en mots au démarrage ;
  - toucher la plage ramène l'onglet sur la semaine en cours.
- Agent : le plafond de 130 % de l'échelle de texte, décidé par l'agent de la spec 009, est retiré après la revue ; le CA27 l'exclut désormais explicitement.

### Corrections et limites

- Tests d'avant modifiés dans `fix-008-009`, avec le critère qui les remplace :
  - `analysis_display_test` : ordre des puces avec une tolérance de rangée de 8 points (rotation des autocollants, spec 008, CA12) ; thème sombre avec `on-mood` et les jetons clairs admis dans la carte d'entrée (spec 008, CA12 et CA19 complétés) ;
  - `model_download_screen_test`, CA30 : `ink` clair admis (`on-mood` des autocollants, spec 008, CA15) ;
  - `weekly_review_screen_test`, CA33 : absence des couleurs d'humeur de l'autre thème retirée (`mood-n` identique dans les deux thèmes, spec 008) ;
  - `accessibility_and_theme_test`, `entry_detail_screen_test` : défilement avant de toucher un élément que l'accueil plus haut pousse sous la ligne de flottaison (spec 009) ;
  - `entry_form_screen_test`, CA9 : deux « Bien » (carte et check-in, spec 009, CA11) ;
  - `home_shell_test` : entrée ajoutée la semaine précédente pour que « Semaine précédente » soit active (spec 006, CA5), et onglets cherchés dans `HomeShell`, pour ne pas confondre avec le bouton retour « Journal ».
- La copie principale du dépôt était restée sur un état intermédiaire (fusion de la spec 009 seule), testé par le hook de fin de tour : réalignée sur `origin/feat/refonte-ludique`, sans perte.
- Test humain : pas fait, à faire par Yanis ; la PR reste en brouillon d'ici là.

### Prochaine étape

- Fusionner `fix-accueil`, `fix-sujets` et `fix-docs`, relancer la suite complète, intégrer les résultats des mutations, ouvrir la PR en brouillon et publier la réponse à la revue IA.
