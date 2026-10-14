# Plan : Tidemark

Plan du projet, du 2026-10-13 au **2026-11-03** (3 semaines, date ferme). Il est rédigé pour l'agent de code qui l'exécute, sous la supervision de Yanis. Contrairement au `plan.md` du template, il est versionné : le dépôt est la seule mémoire ([spec 004](https://github.com/yanis-vroland/agentic-dev-workflow/blob/main/docs/specs/004-reprise-de-session.md)).

## Objectif

Deux preuves, par ordre de priorité :

1. **La méthode sur mobile** : plan, spec avec maquettes, tests d'abord, implémentation, chacun par une PR relue, avec la chaîne [agentic-dev-workflow](https://github.com/yanis-vroland/agentic-dev-workflow) (la « chaîne P1 », premier projet du portfolio). Les maquettes sont des artefacts Claude soignés, transcrits fidèlement en Flutter.
2. **Une IA sur l'appareil, sans fuite de données** : étiquetage et bilan produits par un modèle local, garde-fou de détresse testé.

Le 2026-11-03, le projet s'arrête où il en est : README à jour, limites écrites, retour à P2 (application Flutter du produit fictif FieldOps, deuxième projet du portfolio). Une fonctionnalité inachevée est retirée ou marquée comme telle, jamais présentée comme livrée.

## Règles d'exécution

- `CLAUDE.md` s'applique en toutes circonstances. Ce plan n'y déroge pas.
- Une PR par lot, basée sur `main` à jour, sur sa propre branche. L'agent ne merge jamais.
- Les cases sont cochées dans la PR qui réalise la tâche.
- Les tâches **[Yanis]** sont à lui : l'agent vérifie seulement qu'elles sont faites.
- Toute friction de la chaîne P1 est notée dans « Frictions de la chaîne », puis remontée en issue dans `agentic-dev-workflow` avec l'accord de Yanis.
- Écart au plan, choix structurant ou ambiguïté : s'arrêter et demander.

## Périmètre

Le MVP proposé au lancement du projet est trié en trois niveaux. « Si le temps le permet » n'est commencé que si tout l'indispensable est mergé avant le 2026-10-30 ; « Hors MVP » est écarté par Yanis (2026-10-14).

| Niveau | Fonctionnalité | IA | Lot |
| --- | --- | --- | --- |
| Indispensable | Saisie d'une entrée : humeur de 1 à 5 et texte libre, stockage local chiffré | — | E |
| Indispensable | Détection de détresse → écran d'aide fixe (3114) | Règles déterministes | F |
| Indispensable | Téléchargement du modèle, seul accès réseau admis | — | G |
| Indispensable | Étiquetage automatique (émotions, thèmes) | LLM local, JSON validé | G |
| Indispensable | Export et suppression totale | — | H |
| Si le temps le permet | Bilan de la semaine | LLM local + calculs en Dart | I |
| Hors MVP | Dictée | — | voir « Décisions » |
| Hors MVP | Classifieur de détresse | Modèle | voir « Décisions » |

Hors périmètre : comptes, synchronisation, cloud, notifications, thèmes personnalisés par l'utilisateur.

### Exigence de finition

Les écrans sont **soignés** (décision de Yanis, 2026-10-14). Concrètement, chaque écran livré :

- suit la charte du lot C, sans couleur, taille ni espacement codés en dur hors des jetons ;
- existe en thème clair et sombre ;
- a ses états vide, chargement et erreur dessinés, pas seulement l'état nominal ;
- respecte l'accessibilité : contraste AA, texte qui suit la taille système, cibles tactiles d'au moins 44 points, libellés pour le lecteur d'écran ;
- se limite à des animations utiles (sélecteur d'humeur, transitions entre écrans).

Le prix de cette finition est payé sur le lot I (bilan de la semaine), le plus probable à couper.

## Calendrier

| Semaine | Dates | Lots | Jalon |
| --- | --- | --- | --- |
| 1 | 13 → 19 oct. | A, B, C, D | ADR-001 accepté, charte validée, projet Flutter avec son thème qui tourne sur iOS et Android, CI verte |
| 2 | 20 → 26 oct. | E, F, G | Saisie, garde-fou et étiquetage livrés |
| 3 | 27 oct. → 3 nov. | H, I, J | Export et suppression livrés, README final, dépôt public |

Le lot C (charte) avance en parallèle du spike (lot B) : il ne dépend pas du moteur d'IA.

Point d'arrêt le **2026-10-24** : si le lot D n'est pas mergé, Yanis décide entre réduire à iOS seul ou couper le lot H (export et suppression). Le lot G n'est pas une option de coupe : sans lui, la preuve n° 2 tombe.

## Tâches de Yanis

- [x] **[Yanis]** Merger la PR #3 (nettoyage des workflows).
- [x] **[Yanis]** Accord pour créer le label `agent-corrigé` (2026-10-14).
- [x] **[Yanis]** Répondre aux questions de cadrage avant le lot B (2026-10-14).
- [ ] **[Yanis]** Valider la charte (lot C) en commentant l'artefact.
- [ ] **[Yanis]** Valider l'ADR-001, puis chaque spec et sa maquette.
- [ ] **[Yanis]** Test humain de chaque fonctionnalité sur l'iPhone 15 Pro et sur l'émulateur Android, maquette à côté.
- [ ] **[Yanis]** Passer le dépôt en public (lot J).

## Maquettes en artefacts Claude

Méthode commune aux lots C et E à I (décision de Yanis, 2026-10-14) :

1. **Charte** : un artefact de type « Design System », « Tidemark », créé au lot C. Il porte les jetons (couleurs des thèmes clair et sombre, échelle typographique, espacements, rayons, ombres) et les composants communs, avec leur aperçu.
2. **Écrans** : un artefact de type « Design » par spec, construit sur la charte, au format iPhone 15 Pro (393 × 852 points). Il montre chaque écran de la spec dans ses états nominal, vide, chargement et erreur, en clair et en sombre.
3. **Validation** : Yanis commente l'artefact ; l'agent corrige jusqu'à l'accord, avant les tests.
4. **Copie dans le dépôt** : un artefact est privé et vit hors du dépôt. La source HTML et une capture PNG de chaque écran sont versionnées dans `docs/maquettes/NNN-titre-court/`, et la spec affiche les captures et donne le lien de l'artefact. La version du dépôt fait foi.
5. **Transcription** : les jetons de la charte deviennent des constantes Dart de même nom (`lib/ui/theme/`), puis le `ThemeData` clair et sombre. Les widgets n'utilisent que ces jetons et les composants communs.
6. **Contrôle** : au test humain, Yanis compare l'app et la maquette ; la PR montre les deux captures côte à côte. Les composants communs ont des tests golden, générés une fois le rendu validé, pour éviter toute dérive.

Les maquettes ne contiennent que des données fictives. Les polices et les icônes sont embarquées dans l'app : aucune police ni image chargée depuis le réseau à l'exécution (le paquet `google_fonts` est donc exclu, ou utilisé avec le téléchargement désactivé).

## Lot A : cadrage

Branches : `docs/plan-projet` (PR #4), `docs/maquettes-artefacts`, puis `docs/cahier-des-charges`.

- [x] Plan du projet (`docs/plan.md`).
- [x] README : renvoi vers le plan.
- [x] Méthode des maquettes en artefacts Claude, dans le plan et dans la règle « Maquettes dans la spec » du `CLAUDE.md`.
- [x] Cahier des charges : objectif et périmètre, acteur unique (la personne qui tient son journal), glossaire (entrée, humeur, étiquette, bilan, détresse), règles métier tranchées, fonctionnalités du tableau ci-dessus au statut « à spécifier ». Les règles non tranchées vont dans les questions ouvertes. Les décisions sur la dictée et le classifieur y sont reportées (hors périmètre), avec un simple renvoi ici.

## Lot B : spike du moteur d'IA local (2 jours)

Branche : `spike/moteur-ia`. Le code du spike n'est pas mergé : seuls l'ADR et ses mesures le sont. L'app du spike n'a pas d'interface soignée : elle sert à mesurer, pas à montrer.

Candidats prévus : `flutter_gemma` et `llama_cpp_dart`. Candidats réellement mesurés, et pourquoi : [ADR-001](adr/001-moteur-ia-local.md). Foundation Models d'Apple est écarté d'office, puisqu'il n'existe pas sur Android (décision iOS + Android du 2026-10-13) ; l'ADR le mentionne comme option rejetée. À réexaminer seulement si la cible est ramenée à iOS seul.

- [x] Pour chaque candidat, étiquetage d'une entrée fictive en JSON sur l'iPhone 15 Pro (mesures) et sur l'émulateur Android (fonctionnement seulement : un émulateur utilise le processeur du Mac, ses temps ne valent pas ceux d'un téléphone, et l'accélération GPU peut y manquer).
- [x] Un candidat qui ne tourne pas sur l'émulateur Android est éliminé, ou l'ADR explique pourquoi l'émulateur n'est pas représentatif.
- [x] Mesures sur l'iPhone 15 Pro consignées dans l'ADR, avec le modèle utilisé : taille du modèle téléchargé, mémoire, temps de chargement, temps d'étiquetage, taux de JSON valide sur 20 entrées fictives.
- [x] Vérification qu'aucun appel réseau n'a lieu après le téléchargement du modèle (mode avion).
- [x] Licence du modèle compatible avec un dépôt public.
- [x] ADR-001 « Moteur d'IA local » rédigé, puis accepté par Yanis le 2026-10-14.

## Lot C : charte graphique

Branche : `docs/charte`. En parallèle du lot B.

Une première version existe : l'artefact « Design System » Tidemark, créé le 2026-10-14 (jetons, typographie, README, couverture, sans composants), avec une maquette d'exploration de la saisie. Le lot C part de cet artefact : il ne le recrée pas. Ses liens privés ne figurent que dans le journal ; le dépôt renverra vers `docs/maquettes/000-charte/`.

- [x] Inventaire des écrans du MVP : liste des entrées (avec état vide), saisie, détail d'une entrée et ses étiquettes, écran d'aide (3114), téléchargement du modèle, réglages (export, suppression totale), bilan de la semaine.
- [x] Artefact « Design System » Tidemark : ton visuel (calme, sans infantiliser, adapté à un sujet sensible), jetons clair et sombre, échelle typographique, composants communs (sélecteur d'humeur, carte d'entrée, puce d'étiquette, boutons, champ de texte, bandeau d'erreur, indicateur de chargement).
- [x] Contraste AA vérifié pour chaque paire texte et fond, dans les deux thèmes.
- [ ] Polices et icônes choisies parmi celles qu'on peut embarquer, licence compatible avec un dépôt public. Polices faites (OFL) ; jeu d'icônes reporté au lot D.
- [ ] Source et captures versionnées dans `docs/maquettes/000-charte/`. Source faite ; captures reportées au lot E.

## Lot D : socle Flutter

Branche : `chore/socle-flutter`. Après acceptation de l'ADR-001 et validation de la charte.

- [x] Mise à jour de Flutter (3.35.3 → 3.47.7) et création du projet, iOS + Android.
- [x] Thème transcrit depuis la charte : jetons dans `lib/ui/theme/`, `ThemeData` clair et sombre, polices embarquées.
- [x] Vérification en CI : aucune couleur codée en dur hors de `lib/ui/theme/`. Garde-fou contrôlé par mutation.
- [x] Interface `MoodAnalyzer` (nom à confirmer par le glossaire) et son implémentation factice, seule utilisée par les tests et la CI.
- [x] Stockage local chiffré : choix de la base et de la gestion de la clé (trousseau iOS, Keystore Android). Choix structurant : ADR-002, accepté par Yanis le 2026-10-14. La numérotation des ADR est propre à Tidemark : les ADR de la chaîne sont toujours cités avec leur lien vers `agentic-dev-workflow`.
- [x] Workflow CI Flutter : `dart format --set-exit-if-changed`, `dart analyze`, `flutter test`.
- [x] `.claude/quality.json` renseigné, section « Stack et commandes » et « Architecture » du `CLAUDE.md` complétées.
- [ ] Architecture technique : vue d'ensemble, modèle de données, sécurité. Vue d'ensemble et sécurité faites ; modèle de données avec la spec du lot E (ADR-002).

## Lots E à I : fonctionnalités

Chaque lot suit la même séquence, en PR séparées si la spec est longue à valider :

1. Spec par `/spec`, au statut « brouillon », avec sa maquette en artefact « Design » (voir « Maquettes en artefacts Claude »). Validation de la spec et de la maquette par Yanis.
2. Tests par le subagent `test-writer`, committés seuls, rouges pour la bonne raison.
3. Implémentation jusqu'au vert, à partir de la maquette et des jetons ; revue `reviewer` et `security-reviewer`.
4. Test humain sur l'iPhone et l'émulateur, maquette à côté ; captures côte à côte dans la PR ; journal, PR.

| Lot | Branche | Points de vigilance |
| --- | --- | --- |
| E | `feat/saisie-entree` | Données chiffrées au repos ; aucune permission réseau utilisée par le code de l'app. Écran de lancement natif aux couleurs de la charte (aujourd'hui blanc ou noir sur Android, hors de portée du garde-fou des couleurs). |
| F | `feat/garde-fou-detresse` | Avant le lot G : aucune entrée en détresse n'atteint le modèle. Écran d'aide fixe, jamais généré, et soigné comme les autres : sobre, lisible, numéro appelable d'un geste. Contrôle par mutation sur chaque règle. Liste de termes rédigée pour le projet et validée par Yanis. |
| G | `feat/modele-local` puis `feat/etiquetage` | Deux specs. Téléchargement : consentement, taille annoncée, progression, échec réseau et reprise, empreinte du fichier vérifiée, état « modèle absent » ; un seul hôte contacté, aucune donnée de l'utilisateur dans la requête. Étiquetage : sortie JSON validée contre un schéma ; sortie invalide → entrée sans étiquette, jamais de plantage. Tests sur l'implémentation factice uniquement. |
| H | `feat/export-suppression` | Suppression totale : base, clé, modèle téléchargé. Format d'export à trancher dans la spec. |
| I | `feat/bilan-semaine` | Chiffres calculés en Dart, le modèle ne fait que les mettre en mots ; aucun chiffre du bilan ne vient du modèle. |

## Lot J : publication

Branche : `docs/readme-final`.

- [ ] README lisible en 2 minutes : démo (GIF sur l'iPhone), schéma, notions IA, maquette et écran réel côte à côte, lancement en 3 commandes, mesures du spike, limites.
- [ ] Vérification : aucune donnée réelle, aucun secret dans l'historique (gitleaks), licences du modèle, des polices et des dépendances, aucune référence à l'espace de travail privé (`docs/projets/`) restée sans explication.
- [ ] Frictions de la chaîne remontées en issues dans `agentic-dev-workflow`.
- [ ] `docs/projets/tidemark.md` de l'espace de travail mis à jour : bilan et retour à P2.

## Décisions

Décisions de cadrage de Yanis (2026-10-14). Leurs effets sur le produit (hors périmètre, RM6) sont dans le [cahier des charges](cahier-des-charges-fonctionnel.md) ; leurs motifs restent ici.

1. **Pas de dictée.** La reconnaissance vocale du système peut envoyer l'audio à un serveur : serveurs d'Apple par défaut sur iOS (la reconnaissance locale, `requiresOnDeviceRecognition`, n'existe que pour certaines langues et certains appareils), serveurs de Google possibles sur Android. La garder exigerait un modèle de transcription local et un ADR.
2. **Détection de détresse par règles seules.** Pas de classifieur : un modèle ajoute des faux négatifs difficiles à tester. Le classifieur est une piste d'amélioration, documentée dans le README.
3. **Appareils : iPhone 15 Pro physique, émulateur Android et simulateurs iOS sur le Mac.** Aucun Android physique : les mesures de performance ne valent que pour l'iPhone, Android n'est vérifié qu'en fonctionnement. Cette limite figure dans l'ADR-001 et dans le README.
4. **Écrans soignés, maquettés en artefacts Claude** puis transcrits en Flutter : voir « Exigence de finition » et « Maquettes en artefacts Claude ».

## Frictions de la chaîne

À remonter en issues dans `agentic-dev-workflow`, avec l'accord de Yanis.

- `/install-github-app` ajoute deux workflows qui doublent `ai-review.yml` ; le guide d'adoption pourrait prévenir de les supprimer, ou de configurer le secret à la main.
- Le `plan.md` du template est local et non versionné, ce qui contredit la spec 004 (le dépôt est la seule mémoire). Ce dépôt le versionne dans `docs/plan.md`.
- La skill `/spec` ne prévoit pas d'étape de maquette, alors que la règle « Maquettes dans la spec » l'exige pour un projet avec écrans. Ce dépôt la décrit dans son plan.
