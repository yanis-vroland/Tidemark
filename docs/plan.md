# Plan : Tidemark

Plan du projet, du 2026-10-13 au **2026-11-03** (3 semaines, date ferme). Il est rédigé pour l'agent de code qui l'exécute, sous la supervision de Yanis. Contrairement au `plan.md` du template, il est versionné : le dépôt est la seule mémoire ([spec 004](https://github.com/yanis-vroland/agentic-dev-workflow/blob/main/docs/specs/004-reprise-de-session.md)).

## Objectif

Deux preuves, par ordre de priorité :

1. **La méthode sur mobile** : plan, spec avec maquettes, tests d'abord, implémentation, chacun par une PR relue, avec la chaîne [agentic-dev-workflow](https://github.com/yanis-vroland/agentic-dev-workflow) (la « chaîne P1 », premier projet du portfolio).
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
| Indispensable | Saisie d'une entrée : humeur de 1 à 5 et texte libre, stockage local chiffré | — | D |
| Indispensable | Détection de détresse → écran d'aide fixe (3114) | Règles déterministes | E |
| Indispensable | Téléchargement du modèle, seul accès réseau admis | — | F |
| Indispensable | Étiquetage automatique (émotions, thèmes) | LLM local, JSON validé | F |
| Indispensable | Export et suppression totale | — | G |
| Si le temps le permet | Bilan de la semaine | LLM local + calculs en Dart | H |
| Hors MVP | Dictée | — | voir « Décisions » |
| Hors MVP | Classifieur de détresse | Modèle | voir « Décisions » |

Hors périmètre : comptes, synchronisation, cloud, notifications, thèmes personnalisés.

## Calendrier

| Semaine | Dates | Lots | Jalon |
| --- | --- | --- | --- |
| 1 | 13 → 19 oct. | A, B, C | ADR-001 accepté, projet Flutter qui tourne sur iOS et Android, CI verte |
| 2 | 20 → 26 oct. | D, E, F | Saisie, garde-fou et étiquetage livrés |
| 3 | 27 oct. → 3 nov. | G, H, I | Export et suppression livrés, README final, dépôt public |

Point d'arrêt le **2026-10-24** : si le lot C n'est pas mergé, Yanis décide entre réduire à iOS seul ou couper le lot G (export et suppression). Le lot F n'est pas une option de coupe : sans lui, la preuve n° 2 tombe.

## Tâches de Yanis

- [ ] **[Yanis]** Merger la PR #3 (nettoyage des workflows).
- [ ] **[Yanis]** Accord pour créer le label `agent-corrigé`.
- [x] **[Yanis]** Répondre aux questions de cadrage avant le lot B (2026-10-14).
- [ ] **[Yanis]** Valider l'ADR-001, puis chaque spec et sa maquette.
- [ ] **[Yanis]** Test humain de chaque fonctionnalité sur l'iPhone 15 Pro et sur l'émulateur Android.
- [ ] **[Yanis]** Passer le dépôt en public (lot I).

## Lot A : cadrage

Branche : `docs/plan-projet` (cette PR), puis `docs/cahier-des-charges`.

- [x] Plan du projet (`docs/plan.md`).
- [ ] Cahier des charges : objectif et périmètre, acteur unique (la personne qui tient son journal), glossaire (entrée, humeur, étiquette, bilan, détresse), règles métier tranchées, fonctionnalités du tableau ci-dessus au statut « à spécifier ». Les règles non tranchées vont dans les questions ouvertes. Les décisions sur la dictée et le classifieur y sont reportées (hors périmètre), avec un simple renvoi ici.
- [x] README : renvoi vers le plan.

## Lot B : spike du moteur d'IA local (2 jours)

Branche : `spike/moteur-ia`. Le code du spike n'est pas mergé : seuls l'ADR et ses mesures le sont.

Candidats : `flutter_gemma` et `llama_cpp_dart`. Foundation Models d'Apple est écarté d'office, puisqu'il n'existe pas sur Android (décision iOS + Android du 2026-10-13) ; l'ADR le mentionne comme option rejetée. À réexaminer seulement si la cible est ramenée à iOS seul.

- [ ] Pour chaque candidat, étiquetage d'une entrée fictive en JSON sur l'iPhone 15 Pro (mesures) et sur l'émulateur Android (fonctionnement seulement : un émulateur utilise le processeur du Mac, ses temps ne valent pas ceux d'un téléphone, et l'accélération GPU peut y manquer).
- [ ] Un candidat qui ne tourne pas sur l'émulateur Android est éliminé, ou l'ADR explique pourquoi l'émulateur n'est pas représentatif.
- [ ] Mesures sur l'iPhone 15 Pro consignées dans l'ADR, avec le modèle utilisé : taille du modèle téléchargé, mémoire, temps de chargement, temps d'étiquetage, taux de JSON valide sur 20 entrées fictives.
- [ ] Vérification qu'aucun appel réseau n'a lieu après le téléchargement du modèle (mode avion).
- [ ] Licence du modèle compatible avec un dépôt public.
- [ ] ADR-001 « Moteur d'IA local » rédigé au statut « proposé ».

## Lot C : socle Flutter

Branche : `chore/socle-flutter`. Après acceptation de l'ADR-001.

- [ ] Mise à jour de Flutter (3.35.3 installé, daté de septembre 2025) et création du projet, iOS + Android.
- [ ] Interface `MoodAnalyzer` (nom à confirmer par le glossaire) et son implémentation factice, seule utilisée par les tests et la CI.
- [ ] Stockage local chiffré : choix de la base et de la gestion de la clé (trousseau iOS, Keystore Android). Choix structurant : ADR-002, au statut « proposé ». La numérotation des ADR est propre à Tidemark : les ADR de la chaîne sont toujours cités avec leur lien vers `agentic-dev-workflow`.
- [ ] Workflow CI Flutter : `dart format --set-exit-if-changed`, `dart analyze`, `flutter test`.
- [ ] `.claude/quality.json` renseigné, section « Stack et commandes » et « Architecture » du `CLAUDE.md` complétées.
- [ ] Architecture technique : vue d'ensemble, modèle de données, sécurité.

## Lots D à H : fonctionnalités

Chaque lot suit la même séquence, en PR séparées si la spec est longue à valider :

1. Spec par `/spec`, avec la maquette générée par Claude (états nominal, vide, chargement, erreur), au statut « brouillon ». Validation par Yanis.
2. Tests par le subagent `test-writer`, committés seuls, rouges pour la bonne raison.
3. Implémentation jusqu'au vert, revue `reviewer` et `security-reviewer`.
4. Test humain sur iOS et Android, journal, PR.

| Lot | Branche | Points de vigilance |
| --- | --- | --- |
| D | `feat/saisie-entree` | Données chiffrées au repos ; aucune permission réseau utilisée par le code de l'app. |
| E | `feat/garde-fou-detresse` | Avant le lot F : aucune entrée en détresse n'atteint le modèle. Écran d'aide fixe, jamais généré. Contrôle par mutation sur chaque règle. Liste de termes rédigée pour le projet et validée par Yanis. |
| F | `feat/modele-local` puis `feat/etiquetage` | Deux specs. Téléchargement : consentement, taille annoncée, progression, échec réseau et reprise, empreinte du fichier vérifiée, état « modèle absent » ; un seul hôte contacté, aucune donnée de l'utilisateur dans la requête. Étiquetage : sortie JSON validée contre un schéma ; sortie invalide → entrée sans étiquette, jamais de plantage. Tests sur l'implémentation factice uniquement. |
| G | `feat/export-suppression` | Suppression totale : base, clé, modèle téléchargé. Format d'export à trancher dans la spec. |
| H | `feat/bilan-semaine` | Chiffres calculés en Dart, le modèle ne fait que les mettre en mots ; aucun chiffre du bilan ne vient du modèle. |

## Lot I : publication

Branche : `docs/readme-final`.

- [ ] README lisible en 2 minutes : démo (GIF sur appareil), schéma, notions IA, lancement en 3 commandes, mesures du spike, limites.
- [ ] Vérification : aucune donnée réelle, aucun secret dans l'historique (gitleaks), licences du modèle et des dépendances, aucune référence à l'espace de travail privé (`docs/projets/`) restée sans explication.
- [ ] Frictions de la chaîne remontées en issues dans `agentic-dev-workflow`.
- [ ] `docs/projets/tidemark.md` de l'espace de travail mis à jour : bilan et retour à P2.

## Décisions

Décisions de cadrage de Yanis (2026-10-14), à reporter dans le cahier des charges au lot A :

1. **Pas de dictée.** La reconnaissance vocale du système peut envoyer l'audio à un serveur : serveurs d'Apple par défaut sur iOS (la reconnaissance locale, `requiresOnDeviceRecognition`, n'existe que pour certaines langues et certains appareils), serveurs de Google possibles sur Android. La garder exigerait un modèle de transcription local et un ADR.
2. **Détection de détresse par règles seules.** Pas de classifieur : un modèle ajoute des faux négatifs difficiles à tester. Le classifieur est une piste d'amélioration, documentée dans le README.
3. **Appareils : iPhone 15 Pro physique, émulateur Android et simulateurs iOS sur le Mac.** Aucun Android physique : les mesures de performance ne valent que pour l'iPhone, Android n'est vérifié qu'en fonctionnement. Cette limite figure dans l'ADR-001 et dans le README.

## Frictions de la chaîne

À remonter en issues dans `agentic-dev-workflow`, avec l'accord de Yanis.

- `/install-github-app` ajoute deux workflows qui doublent `ai-review.yml` ; le guide d'adoption pourrait prévenir de les supprimer, ou de configurer le secret à la main.
- Le `plan.md` du template est local et non versionné, ce qui contredit la spec 004 (le dépôt est la seule mémoire). Ce dépôt le versionne dans `docs/plan.md`.
