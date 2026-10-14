# Cahier des charges fonctionnel

Ce que fait le produit, pour qui, et selon quelles règles. Ce document est la référence pour les acteurs, le glossaire et les règles métier. Chaque spec de `docs/specs/` détaille une fonctionnalité ; ce document la résume et renvoie vers elle.

Il est mis à jour dans la PR qui change ce qu'il décrit : nouvelle fonctionnalité, acteur, droit, terme ou règle métier, changement de statut d'une spec. Une section sans objet pour le projet reste, avec « Sans objet » et une phrase d'explication.

## Objectif et périmètre

Tidemark est un journal d'humeur mobile (iOS et Android) pour une personne qui veut suivre son humeur au jour le jour et en comprendre les tendances. Elle note son humeur de 1 à 5 avec quelques mots ; l'app en tire des étiquettes (émotions, thèmes) et un bilan de la semaine. Ce qui la distingue : l'IA tourne entièrement sur le téléphone, et aucune donnée de la personne ne le quitte.

Hors périmètre :

- Compte, connexion, synchronisation entre appareils, sauvegarde dans le cloud.
- Analytics, publicité, partage vers un réseau social.
- Toute IA distante : l'analyse se fait sur le téléphone ou pas du tout.
- Conseil médical, diagnostic, accompagnement thérapeutique.
- Dictée et classifieur de détresse (décisions de Yanis du 2026-10-14, motifs dans le [plan](plan.md#décisions)).
- Notifications et rappels, thèmes personnalisés par l'utilisateur.

## Acteurs et droits

Qui utilise le produit et ce que chacun peut faire. La mise en œuvre technique des droits est dans [`architecture-technique.md`](architecture-technique.md#sécurité).

| Acteur | Rôle | Peut | Ne peut pas |
| --- | --- | --- | --- |
| Personne qui tient son journal | Seule utilisatrice de l'app, sur son téléphone, sans compte | Créer des entrées, consulter ses entrées, leurs étiquettes et le bilan, télécharger le modèle, exporter ses données, tout supprimer | Envoyer ses données hors du téléphone par l'app (sauf l'export, qu'elle déclenche elle-même), obtenir un conseil médical ou une réponse générée en cas de détresse |

Le modèle local n'est pas un acteur : c'est un composant, derrière l'interface `MoodAnalyzer`.

## Glossaire

Les termes du métier et leur nom dans le code. Les specs, le code et les PR utilisent ces termes, et aucun synonyme.

| Terme | Nom dans le code | Définition |
| --- | --- | --- |
| Entrée | `Entry` | Ce que la personne note à un moment donné : une humeur, un texte éventuel, une date et heure. |
| Humeur | `mood` | Note entière de 1 à 5, avec un libellé fixe (RM3). |
| Texte | `note` | Les mots que la personne ajoute à son entrée. |
| Étiquette | `Tag` | Émotion ou thème que le modèle local associe à une entrée. |
| Type d'étiquette | `TagKind` | `emotion` ou `theme`. |
| Analyse | `analysis` | Traitement d'une entrée par le modèle local, qui produit ses étiquettes. |
| Analyseur | `MoodAnalyzer` | Interface qui isole le modèle local ; une implémentation factice sert aux tests et à la CI. |
| Modèle local | `LocalModel` | Fichier du modèle d'IA, téléchargé une fois puis exécuté sur le téléphone. |
| Détresse | `distress` | Signe, repéré dans le texte d'une entrée, qu'une personne est peut-être en danger. |
| Détecteur de détresse | `DistressDetector` | Règles déterministes qui repèrent la détresse dans le texte (RM6). |
| Écran d'aide | `HelpScreen` | Écran fixe affiché en cas de détresse, avec le 3114 ; jamais généré par le modèle (RM7). |
| Bilan de la semaine | `WeeklyReview` | Synthèse des entrées d'une semaine : chiffres calculés par l'app, mis en mots par le modèle local (RM10). |
| Export | `export` | Copie de toutes les données de la personne dans un fichier qu'elle garde. |
| Suppression totale | `wipe` | Effacement de toutes les données de l'app sur le téléphone (RM12). |

## Règles métier

Chaque règle est numérotée (RM1, RM2…) et renvoie vers la spec qui l'a introduite ou précisée. Une règle non tranchée va dans « Questions ouvertes », jamais ici. Tant que les specs n'existent pas, la règle renvoie vers sa source : `CLAUDE.md`, le [plan](plan.md) ou la [charte](https://claude.ai/artifact/LxwwPXPaLTB1ciS6m7NVeu).

### Statuts et transitions

| Objet | De | Vers | Condition | Qui |
| --- | --- | --- | --- | --- |
| Modèle local | absent | en téléchargement | La personne accepte le téléchargement (taille annoncée) | Personne |
| Modèle local | en téléchargement | prêt | Fichier complet et empreinte vérifiée | App |
| Modèle local | en téléchargement | absent | Échec réseau, empreinte fausse ou annulation ; reprise possible | App, personne |
| Modèle local | prêt | absent | Suppression totale | Personne |
| Analyse d'une entrée | en attente | étiquetée | Le modèle rend une sortie conforme au schéma | App |
| Analyse d'une entrée | en attente | sans étiquette | Sortie non conforme ou erreur du modèle (RM9) | App |
| Analyse d'une entrée | en attente | non analysée | Détresse détectée dans le texte (RM8) | App |

### Autres règles

- RM1 : aucune donnée de la personne ne quitte le téléphone. Le seul accès réseau de l'app est le téléchargement du modèle local, qui ne transmet aucune donnée de la personne. Toute exception passe par un ADR (source : `CLAUDE.md`).
- RM2 : les entrées sont chiffrées au repos sur le téléphone (source : plan, lot E).
- RM3 : l'humeur est un entier de 1 à 5. Libellés fixes : 1 « Très bas », 2 « Bas », 3 « Neutre », 4 « Bien », 5 « Très bien » (source : charte, validée par Yanis le 2026-10-14).
- RM4 : l'app ne donne aucun conseil médical, aucun diagnostic, aucun jugement sur l'humeur (source : `CLAUDE.md`).
- RM5 : toute entrée avec un texte passe par le détecteur de détresse avant toute analyse (source : plan, lot F).
- RM6 : la détection de détresse repose sur des règles déterministes, sans modèle. La liste des termes est rédigée pour le projet et validée par Yanis (source : décision de Yanis du 2026-10-14).
- RM7 : en cas de détresse détectée, l'app affiche l'écran d'aide fixe avec le 3114 (numéro national de prévention du suicide), jamais une réponse générée par le modèle (source : `CLAUDE.md`).
- RM8 : une entrée où la détresse est détectée n'est jamais transmise au modèle (source : plan, lot F).
- RM9 : une sortie du modèle non conforme au schéma des étiquettes laisse l'entrée sans étiquette ; l'app ne plante pas et ne montre pas la sortie brute (source : plan, lot G).
- RM10 : dans le bilan de la semaine, tous les chiffres sont calculés par l'app ; le modèle ne fait que les mettre en mots et n'en produit aucun (source : plan, lot I).
- RM11 : le téléchargement du modèle n'a lieu qu'avec l'accord de la personne, après l'annonce de sa taille ; l'empreinte du fichier est vérifiée avant usage (source : plan, lot G).
- RM12 : la suppression totale efface les entrées, la clé de chiffrement et le modèle local téléchargé (source : plan, lot H).

## Parcours utilisateur

### Personne qui tient son journal

1. Elle ouvre l'app pour la première fois et découvre qu'elle fonctionne sans compte (moment du téléchargement du modèle : question ouverte 6).
2. Elle accepte de télécharger le modèle local, après avoir vu sa taille (téléchargement du modèle).
3. Le soir, elle note son humeur et quelques mots (saisie d'une entrée).
4. Si son texte contient des signes de détresse, l'écran d'aide s'affiche à la place de toute analyse (détection de détresse).
5. Sinon, l'app propose des étiquettes, analysées sur le téléphone (étiquetage automatique).
6. Elle parcourt ses entrées passées et leurs étiquettes (saisie d'une entrée, liste).
7. En fin de semaine, elle lit son bilan (bilan de la semaine).
8. Elle peut à tout moment exporter ses données, ou tout supprimer (export et suppression totale).

## Fonctionnalités

Une ligne par fonctionnalité, regroupées par phase. Statuts : à spécifier, spec brouillon, spec validée, livrée. Phases et lots : [plan](plan.md#périmètre).

| Phase | Fonctionnalité | Spec | Statut |
| --- | --- | --- | --- |
| MVP (lot E) | Saisie d'une entrée et liste des entrées, stockage local chiffré | — | à spécifier |
| MVP (lot F) | Détection de détresse et écran d'aide | — | à spécifier |
| MVP (lot G) | Téléchargement du modèle local | — | à spécifier |
| MVP (lot G) | Étiquetage automatique | — | à spécifier |
| MVP (lot H) | Export et suppression totale | — | à spécifier |
| Si le temps le permet (lot I) | Bilan de la semaine | — | à spécifier |

## Questions ouvertes

Questions métier non tranchées. Une fois la réponse donnée, elle rejoint la section concernée, et la question est retirée. Toutes sont posées le 2026-10-14 à Yanis, qui doit y répondre avant la spec du lot concerné.

1. **Texte obligatoire ?** Une entrée peut-elle n'avoir qu'une humeur, sans texte ? La maquette d'exploration le propose (« facultatif »). Lot E.
2. **Entrées par jour** : une seule par jour, ou autant que la personne veut ? Lot E.
3. **Modifier ou supprimer une entrée** isolée, après coup ? Lot E.
4. **Date d'une entrée** : toujours le moment de la saisie, ou une entrée pour un jour passé ? Lot E.
5. **Après l'écran d'aide** : l'entrée en détresse est-elle enregistrée quand même (sans analyse), ou abandonnée ? Lot F.
6. **Moment du téléchargement du modèle** : à la première ouverture, ou à la première entrée à analyser ? Wi-Fi seulement ? Lot G.
7. **Vocabulaire des étiquettes** : une liste fermée d'émotions et de thèmes (testable, schéma strict), ou des étiquettes libres ? La personne peut-elle corriger une étiquette ? Lot G.
8. **Format d'export** : JSON, CSV, PDF lisible ? Lot H.
9. **Semaine du bilan** : du lundi au dimanche, ou les 7 derniers jours ? Nombre minimal d'entrées pour produire un bilan ? Lot I.
10. **Langue** : l'app est-elle en français seulement ? Le choix du modèle (lot B) en dépend.
