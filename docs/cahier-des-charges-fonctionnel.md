# Cahier des charges fonctionnel

Ce que fait le produit, pour qui, et selon quelles règles. Ce document est la référence pour les acteurs, le glossaire et les règles métier. Chaque spec de `docs/specs/` détaille une fonctionnalité ; ce document la résume et renvoie vers elle.

Il est mis à jour dans la PR qui change ce qu'il décrit : nouvelle fonctionnalité, acteur, droit, terme ou règle métier, changement de statut d'une spec. Une section sans objet pour le projet reste, avec « Sans objet » et une phrase d'explication.

## Objectif et périmètre

Tidemark est un journal d'humeur mobile (iOS et Android) pour une personne qui veut suivre son humeur au jour le jour et en comprendre les tendances. Elle note son humeur de 1 à 5 avec quelques mots ; l'app en tire des étiquettes (émotions, thèmes) et un bilan de la semaine. Ce qui la distingue : l'IA tourne entièrement sur le téléphone, et aucune donnée de la personne ne le quitte.

Hors périmètre :

- Compte, connexion, synchronisation entre appareils, sauvegarde dans le cloud.
- Analytics, publicité.
- Toute IA distante : l'analyse se fait sur le téléphone ou pas du tout.
- Conseil médical, diagnostic, accompagnement thérapeutique.
- Dictée et classifieur de détresse (décisions de Yanis du 2026-10-14, motifs dans le [plan](plan.md#décisions)).
- Notifications et rappels, thèmes personnalisés par l'utilisateur.

## Acteurs et droits

Qui utilise le produit et ce que chacun peut faire. La mise en œuvre technique des droits est dans [`architecture-technique.md`](architecture-technique.md#sécurité).

| Acteur | Rôle | Peut | Ne peut pas |
| --- | --- | --- | --- |
| Personne qui tient son journal | Seule utilisatrice de l'app, sur son téléphone, sans compte | Créer des entrées, consulter ses entrées, leurs étiquettes et le bilan, supprimer une entrée, télécharger le modèle, exporter ses données, tout supprimer | Modifier une entrée (RM15), envoyer ses données hors du téléphone par l'app, sauf par un export qu'elle déclenche elle-même (RM23), obtenir un conseil médical ou une réponse générée en cas de détresse |

Le modèle local n'est pas un acteur : c'est un composant, derrière l'interface `MoodAnalyzer`.

## Glossaire

Les termes du métier et leur nom dans le code. Les specs, le code et les PR utilisent ces termes, et aucun synonyme.

| Terme | Nom dans le code | Définition |
| --- | --- | --- |
| Entrée | `Entry` | Ce que la personne note à un moment donné : une humeur, un texte éventuel, une date et heure. |
| Humeur | `mood` | Valeur entière de 1 à 5, avec un libellé fixe (RM3). |
| Texte | `text` | Les mots que la personne ajoute à son entrée, facultatifs (RM13), 2 000 caractères au plus (RM27). |
| Étiquette | `Tag` | Émotion ou thème que le modèle local associe à une entrée. |
| Type d'étiquette | `TagKind` | `emotion` ou `theme`. |
| Analyse | `analysis` | Traitement d'une entrée par le modèle local, qui produit ses étiquettes. |
| Analyseur | `MoodAnalyzer` | Interface qui isole le modèle local ; une implémentation factice sert aux tests et à la CI. |
| Statut d'analyse | `AnalysisStatus` : `pending`, `tagged`, `untagged`, `skipped` | Où en est l'analyse d'une entrée : en attente, étiquetée, sans étiquette (RM9), non analysée (sans texte, RM24, ou détresse, RM17). Propre à l'entrée ([spec 001](specs/001-saisie-et-liste-des-entrees.md)). |
| Résultat d'analyse | `AnalysisResult` : `Tagged`, `Untagged` | Ce que rend l'analyseur : « étiquetée » (`Tagged`, avec ses étiquettes) ou « sans étiquette » (`Untagged`, RM9). Le statut « non analysée » n'est pas un résultat de l'analyseur, qui n'est pas appelé : il relève de l'entrée (`AnalysisStatus.skipped`). |
| Modèle local | `LocalModel` | Fichier du modèle d'IA, téléchargé une fois puis exécuté sur le téléphone. |
| Détresse | `distress` | Signe qu'une personne est peut-être en danger, repéré dans le texte d'une entrée ou dans une série d'humeurs très basses (RM25). |
| Détecteur de détresse | `DistressDetector` | Règles déterministes qui repèrent la détresse dans le texte et dans la suite des humeurs (RM6, RM25). |
| Écran d'aide | `HelpScreen` | Écran fixe affiché en cas de détresse, avec le 3114 ; jamais généré par le modèle (RM7). |
| Bilan de la semaine | `WeeklyReview` | Synthèse des entrées d'une semaine : chiffres calculés par l'app, mis en mots par le modèle local (RM10). |
| Export | `export` | Copie de toutes les données de la personne dans un fichier JSON (RM20). |
| Suppression totale | `wipe` | Effacement de toutes les données de l'app sur le téléphone (RM12). |

## Règles métier

Chaque règle est numérotée (RM1, RM2…) et renvoie vers la spec qui l'a introduite ou précisée. Une règle non tranchée va dans « Questions ouvertes », jamais ici. Tant que les specs n'existent pas, la règle renvoie vers sa source : `CLAUDE.md`, le [plan](plan.md) ou une décision datée de Yanis.

### Statuts et transitions

| Objet | De | Vers | Condition | Qui |
| --- | --- | --- | --- | --- |
| Modèle local | absent | en téléchargement | La personne accepte le téléchargement (taille annoncée, RM18) | La personne |
| Modèle local | en téléchargement | prêt | Fichier complet et empreinte vérifiée | App |
| Modèle local | en téléchargement | absent | Échec réseau, empreinte fausse ou annulation ; un nouveau téléchargement repart de zéro (RM26) | App, la personne |
| Modèle local | prêt | absent | Suppression totale | La personne |
| Analyse d'une entrée | en attente | étiquetée | Le modèle rend une sortie conforme au schéma | App |
| Analyse d'une entrée | en attente | sans étiquette | Sortie non conforme ou erreur du modèle (RM9) | App |
| Analyse d'une entrée | en attente | non analysée | Détresse détectée : l'entrée est enregistrée, jamais analysée (RM8, RM17) | App |
| Analyse d'une entrée | en attente | non analysée | Entrée sans texte : rien à analyser, aucune étiquette enregistrée (RM24) | App |

### Autres règles

- RM1 : aucune donnée de la personne ne quitte le téléphone par l'app. Le seul accès réseau de l'app est le téléchargement du modèle local, qui ne transmet aucune donnée de la personne. Seule exception : l'export que la personne déclenche elle-même (RM23). Toute exception passe par un ADR (source : `CLAUDE.md`).
- RM2 : les entrées sont chiffrées au repos sur le téléphone (source : plan, lot E).
- RM3 : l'humeur est un entier de 1 à 5. Libellés fixes : 1 « Très bas », 2 « Bas », 3 « Neutre », 4 « Bien », 5 « Très bien » (source : décision de Yanis du 2026-10-14, libellés d'humeur).
- RM4 : l'app ne donne aucun conseil médical, aucun diagnostic, aucun jugement sur l'humeur (source : `CLAUDE.md`).
- RM5 : toute entrée avec un texte passe par le détecteur de détresse avant toute analyse (source : plan, lot F).
- RM6 : la détection de détresse repose sur des règles déterministes, sans modèle. La liste des termes est rédigée pour le projet et validée par Yanis (source : décision de Yanis du 2026-10-14).
- RM7 : en cas de détresse détectée, l'app affiche l'écran d'aide fixe avec le 3114 (numéro national de prévention du suicide), jamais une réponse générée par le modèle (source : `CLAUDE.md`).
- RM8 : une entrée où la détresse est détectée n'est jamais transmise au modèle (source : plan, lot F).
- RM9 : une sortie du modèle non conforme au schéma des étiquettes laisse l'entrée sans étiquette ; l'app ne plante pas et ne montre pas la sortie brute (source : plan, lot G).
- RM10 : dans le bilan de la semaine, tous les chiffres sont calculés par l'app ; le modèle ne fait que les mettre en mots et n'en produit aucun (source : plan, lot I).
- RM11 : le téléchargement du modèle n'a lieu qu'avec l'accord de la personne, après l'annonce de sa taille ; l'empreinte du fichier est vérifiée avant usage (source : plan, lot G).
- RM12 : la suppression totale efface les entrées, la clé de chiffrement et le modèle local téléchargé (source : plan, lot H).
- RM13 : le texte d'une entrée est facultatif : une entrée peut n'avoir qu'une humeur (source : décision de Yanis du 2026-10-14).
- RM14 : le nombre d'entrées par jour n'est pas limité (source : décision de Yanis du 2026-10-14).
- RM15 : une entrée peut être supprimée, pas modifiée (source : décision de Yanis du 2026-10-14).
- RM16 : la date et l'heure d'une entrée sont celles de sa saisie ; pas d'entrée pour un jour passé (source : décision de Yanis du 2026-10-14).
- RM17 : une entrée où la détresse est détectée est enregistrée, sans analyse (source : décision de Yanis du 2026-10-14).
- RM18 : le modèle local est proposé au téléchargement à la première entrée à analyser, quel que soit le réseau (Wi-Fi ou données mobiles), toujours après l'annonce de sa taille (source : décision de Yanis du 2026-10-14).
- RM19 : les étiquettes viennent d'une liste fermée d'émotions et de thèmes, définie dans la spec de l'étiquetage ; la personne ne peut pas les corriger dans le MVP (source : décision de Yanis du 2026-10-14).
- RM20 : l'export produit un fichier JSON qui contient toutes les entrées et leurs étiquettes (source : décision de Yanis du 2026-10-14).
- RM21 : le bilan porte sur une semaine du lundi au dimanche, et n'est produit qu'à partir de 3 entrées dans la semaine (source : décision de Yanis du 2026-10-14).
- RM22 : l'app est en français seulement ; l'étiquetage et le bilan sont évalués en français (source : décision de Yanis du 2026-10-14).
- RM23 : la personne exporte vers la destination de son choix, par la feuille de partage du système (Fichiers, AirDrop, mail…). C'est la seule exception à RM1 : elle est toujours déclenchée par la personne, jamais par l'app, et un ADR la documente au lot H (source : décision de Yanis du 2026-10-14).
- RM24 : une entrée sans texte n'est pas analysée : l'humeur seule ne donne pas d'étiquette, et aucune analyse n'est enregistrée pour elle (source : décision de Yanis du 2026-10-14).
- RM25 : une série d'humeurs très basses déclenche l'écran d'aide, même sans texte. Le seuil (quelles humeurs, combien d'entrées, sur quelle durée) est fixé dans la spec du lot F et validé par Yanis (source : décision de Yanis du 2026-10-14).
- RM26 : un téléchargement du modèle interrompu repart de zéro (source : décision de Yanis du 2026-10-14).
- RM27 : le texte d'une entrée compte 2 000 caractères au plus (spec : [`docs/specs/001-saisie-et-liste-des-entrees.md`](specs/001-saisie-et-liste-des-entrees.md)).
- RM28 : la suppression d'une entrée est définitive et demande une confirmation (spec : [`docs/specs/001-saisie-et-liste-des-entrees.md`](specs/001-saisie-et-liste-des-entrees.md)).

## Parcours utilisateur

### Personne qui tient son journal

1. Elle ouvre l'app pour la première fois et découvre qu'elle fonctionne sans compte.
2. Le soir, elle note son humeur et, si elle veut, quelques mots (saisie d'une entrée).
3. À sa première entrée à analyser, elle accepte de télécharger le modèle local, après avoir vu sa taille (téléchargement du modèle).
4. Si son texte contient des signes de détresse, l'écran d'aide s'affiche à la place de toute analyse (détection de détresse).
5. Sinon, l'app propose des étiquettes, analysées sur le téléphone (étiquetage automatique).
6. Elle parcourt ses entrées passées et leurs étiquettes, et peut en supprimer une (saisie d'une entrée, liste).
7. En fin de semaine, elle lit son bilan (bilan de la semaine).
8. Elle peut à tout moment exporter ses données, ou tout supprimer (export et suppression totale).

## Fonctionnalités

Une ligne par fonctionnalité, regroupées par phase. Statuts : à spécifier, spec brouillon, spec validée, livrée. Phases et lots : [plan](plan.md#périmètre).

| Phase | Fonctionnalité | Spec | Statut |
| --- | --- | --- | --- |
| MVP (lot E) | Saisie d'une entrée et liste des entrées, stockage local chiffré | [001](specs/001-saisie-et-liste-des-entrees.md) | spec brouillon |
| MVP (lot F) | Détection de détresse et écran d'aide | — | à spécifier |
| MVP (lot G) | Téléchargement du modèle local | — | à spécifier |
| MVP (lot G) | Étiquetage automatique | — | à spécifier |
| MVP (lot H) | Export et suppression totale | — | à spécifier |
| Si le temps le permet (lot I) | Bilan de la semaine | — | à spécifier |

## Questions ouvertes

Questions métier non tranchées. Une fois la réponse donnée, elle rejoint la section concernée, et la question est retirée.

1. **Entrée sans analyse** : une entrée avec texte, saisie quand le modèle est absent ou restée sans étiquette après une erreur, est-elle analysée plus tard ? Automatiquement ou à la demande ? (posée le 2026-10-14, Yanis, lot G)
