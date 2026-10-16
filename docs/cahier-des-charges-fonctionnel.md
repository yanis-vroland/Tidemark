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
| Texte | `text` | Les mots que la personne ajoute à son entrée, facultatifs (RM13), 2 000 caractères visibles au plus (RM27). |
| Étiquette | `Tag` | Émotion ou thème que le modèle local associe à une entrée. |
| Type d'étiquette | `TagKind` | `emotion` ou `theme`. |
| Analyse | `analysis` | Traitement d'une entrée par le modèle local, qui produit ses étiquettes. |
| Dépôt des entrées | `EntryRepository` | Interface par laquelle les écrans lisent, ajoutent et suppriment les entrées ; la base chiffrée est derrière ([spec 001](specs/001-saisie-et-liste-des-entrees.md)). |
| Lieu de la clé | `KeyStore` | Interface du lieu où la clé de la base est gardée : trousseau iOS ou Keystore Android (ADR-002). |
| Analyseur | `MoodAnalyzer` | Interface qui isole le modèle local ; une implémentation factice sert aux tests et à la CI. |
| File d'analyse | `AnalysisQueue` | Ce qui analyse les entrées « en attente », une à la fois, dès que le modèle est prêt (RM34, [spec 004](specs/004-etiquetage-automatique.md)). |
| Liste des étiquettes | `TagVocabulary` | Liste fermée des émotions et des thèmes (RM19, RM33), définie dans la [spec 004](specs/004-etiquetage-automatique.md). |
| Statut d'analyse | `AnalysisStatus` : `pending`, `tagged`, `untagged`, `skipped` | Où en est l'analyse d'une entrée : en attente, étiquetée, sans étiquette (RM9), non analysée (sans texte, RM24, ou détresse, RM17). Propre à l'entrée ([spec 001](specs/001-saisie-et-liste-des-entrees.md)). |
| Résultat d'analyse | `AnalysisResult` : `Tagged`, `Untagged` | Ce que rend l'analyseur : « étiquetée » (`Tagged`, avec ses étiquettes) ou « sans étiquette » (`Untagged`, RM9). Le statut « non analysée » n'est pas un résultat de l'analyseur, qui n'est pas appelé : il relève de l'entrée (`AnalysisStatus.skipped`). |
| Modèle local | `LocalModel` | Fichier du modèle d'IA, téléchargé une fois puis exécuté sur le téléphone. |
| État du modèle | `LocalModelStatus` : `absent`, `downloading`, `ready` | Où en est le modèle local : absent, en téléchargement (transfert ou vérification), prêt ([spec 003](specs/003-telechargement-du-modele.md)). |
| Téléchargeur du modèle | `ModelDownloader` | Interface qui télécharge le modèle local, vérifie son empreinte et dit son état ; une implémentation factice sert aux tests, qui ne font aucune requête réseau ([spec 003](specs/003-telechargement-du-modele.md)). |
| Écran du modèle | `ModelDownloadScreen` | Écran qui propose le téléchargement du modèle (taille annoncée), puis montre sa progression, son échec ou sa réussite ([spec 003](specs/003-telechargement-du-modele.md)). |
| Empreinte | `sha256` | Empreinte SHA-256 attendue du fichier du modèle, vérifiée avant usage (RM11). |
| Détresse | `distress` | Signe qu'une personne est peut-être en danger, repéré dans le texte d'une entrée ou dans une série d'humeurs très basses (RM25). |
| Détecteur de détresse | `DistressDetector` | Règles déterministes qui repèrent la détresse dans le texte et dans la suite des humeurs (RM6, RM25). |
| Écran d'aide | `HelpScreen` | Écran fixe affiché en cas de détresse, avec le 3114 ; jamais généré par le modèle (RM7). |
| Sensibilité aux humeurs basses | `LowMoodSensitivity` : `high`, `normal`, `low` | Degré choisi par la personne qui fixe la série d'humeurs très basses déclenchant l'écran d'aide (RM25, RM29). |
| Réglages | `SettingsRepository` (données), `SettingsScreen` (écran) | Choix de la personne, et l'écran où elle les fait. `SettingsRepository` est l'interface par laquelle l'app les lit et les enregistre, dont la sensibilité aux humeurs basses ([spec 002](specs/002-garde-fou-detresse.md)). |
| Bilan de la semaine | `WeeklyReview` | Synthèse des entrées d'une semaine : chiffres calculés par l'app, mis en mots par le modèle local (RM10). |
| Export | `export`, `JournalExporter` | Copie de toutes les données de la personne dans un fichier JSON, au format versionné de la [spec 005](specs/005-export-et-suppression-totale.md) (RM20, RM40). `JournalExporter` construit le fichier. |
| Feuille de partage | `ShareSheet` | Interface de la feuille de partage du système, seule voie de sortie du fichier d'export (RM23, [ADR-003](adr/003-export-par-la-feuille-de-partage.md)). |
| Suppression totale | `wipe`, `JournalWiper` | Effacement de toutes les données de l'app sur le téléphone, qui revient à l'état du premier lancement (RM12, RM42). `JournalWiper` en exécute les étapes. |
| Suppression en cours | `wipe-pending` (fichier) | Marqueur écrit avant la première étape de la suppression totale et effacé après la dernière ; tant qu'il existe, la base n'est pas ouverte et la suppression reprend (RM43). |
| Marqueur d'installation | `installed` (fichier) | Fichier vide créé au premier lancement et effacé par le système à la désinstallation ; son absence signale une nouvelle installation (RM45, ADR-002). |

## Règles métier

Chaque règle est numérotée (RM1, RM2…) et renvoie vers la spec qui l'a introduite ou précisée. Une règle non tranchée va dans « Questions ouvertes », jamais ici. Tant que les specs n'existent pas, la règle renvoie vers sa source : `CLAUDE.md`, le [plan](plan.md) ou une décision datée de Yanis.

### Statuts et transitions

| Objet | De | Vers | Condition | Qui |
| --- | --- | --- | --- | --- |
| Modèle local | absent | en téléchargement | La personne accepte le téléchargement (taille annoncée, RM18) | La personne |
| Modèle local | en téléchargement | prêt | Fichier complet et empreinte vérifiée | App |
| Modèle local | en téléchargement | absent | Échec réseau, empreinte fausse ou annulation ; un nouveau téléchargement repart de zéro (RM26) | App, la personne |
| Modèle local | prêt | absent | Suppression totale | La personne |
| Données de l'app | présentes | suppression en cours | La personne écrit « SUPPRIMER » et confirme (RM42) | La personne |
| Données de l'app | suppression en cours | absentes (premier lancement) | Toutes les étapes faites, y compris après une reprise au démarrage (RM43) | App |
| Analyse d'une entrée | en attente | étiquetée | Le modèle rend une sortie conforme au schéma | App |
| Analyse d'une entrée | en attente | sans étiquette | Sortie non conforme ou erreur du modèle (RM9) | App |
| Analyse d'une entrée | en attente | non analysée | Détresse détectée : l'entrée est enregistrée, jamais analysée (RM8, RM17), y compris par la vérification faite juste avant l'analyse (RM35) | App |
| Analyse d'une entrée | en attente | non analysée | Entrée sans texte : rien à analyser, aucune étiquette enregistrée (RM24) | App |
| Analyse d'une entrée | en attente | en attente | Modèle absent, en téléchargement ou impossible à charger : l'entrée attend que le modèle soit prêt (RM34) | App |

### Autres règles

Les numéros RM37 à RM39 et RM46 à RM49 ne sont pas attribués : les specs des lots G, H et I ont été rédigées en parallèle, avec des plages séparées.

- RM1 : aucune donnée de la personne ne quitte le téléphone par l'app. Le seul accès réseau de l'app est le téléchargement du modèle local, qui ne transmet aucune donnée de la personne. Seule exception : l'export que la personne déclenche elle-même (RM23, [ADR-003](adr/003-export-par-la-feuille-de-partage.md)). Toute exception passe par un ADR (source : `CLAUDE.md`).
- RM2 : les entrées sont chiffrées au repos sur le téléphone (source : plan, lot E).
- RM3 : l'humeur est un entier de 1 à 5. Libellés fixes : 1 « Très bas », 2 « Bas », 3 « Neutre », 4 « Bien », 5 « Très bien » (source : décision de Yanis du 2026-10-14, libellés d'humeur).
- RM4 : l'app ne donne aucun conseil médical, aucun diagnostic, aucun jugement sur l'humeur (source : `CLAUDE.md`).
- RM5 : toute entrée avec un texte passe par le détecteur de détresse avant toute analyse, y compris une entrée enregistrée avant l'arrivée du détecteur (source : plan, lot F ; spec 001).
- RM6 : la détection de détresse repose sur des règles déterministes, sans modèle. La liste des termes est rédigée pour le projet et validée par Yanis (source : décision de Yanis du 2026-10-14).
- RM7 : en cas de détresse détectée, l'app affiche l'écran d'aide fixe avec le 3114 (numéro national de prévention du suicide), jamais une réponse générée par le modèle (source : `CLAUDE.md`).
- RM8 : une entrée où la détresse est détectée n'est jamais transmise au modèle (source : plan, lot F).
- RM9 : une sortie du modèle non conforme au schéma des étiquettes laisse l'entrée sans étiquette ; l'app ne plante pas et ne montre pas la sortie brute (source : plan, lot G).
- RM10 : dans le bilan de la semaine, tous les chiffres sont calculés par l'app ; le modèle ne fait que les mettre en mots et n'en produit aucun (source : plan, lot I).
- RM11 : le téléchargement du modèle n'a lieu qu'avec l'accord de la personne, après l'annonce de sa taille ; l'empreinte du fichier est vérifiée avant usage (source : plan, lot G).
- RM12 : la suppression totale efface les entrées, leurs étiquettes, les réglages, la clé de chiffrement et le modèle local téléchargé (source : plan, lot H ; spec : [`docs/specs/005-export-et-suppression-totale.md`](specs/005-export-et-suppression-totale.md)).
- RM13 : le texte d'une entrée est facultatif : une entrée peut n'avoir qu'une humeur (source : décision de Yanis du 2026-10-14).
- RM14 : le nombre d'entrées par jour n'est pas limité (source : décision de Yanis du 2026-10-14).
- RM15 : une entrée peut être supprimée, pas modifiée (source : décision de Yanis du 2026-10-14).
- RM16 : la date et l'heure d'une entrée sont celles de sa saisie ; pas d'entrée pour un jour passé (source : décision de Yanis du 2026-10-14).
- RM17 : une entrée où la détresse est détectée est enregistrée, sans analyse (source : décision de Yanis du 2026-10-14).
- RM18 : le modèle local est proposé au téléchargement à la première entrée à analyser, quel que soit le réseau (Wi-Fi ou données mobiles), toujours après l'annonce de sa taille (source : décision de Yanis du 2026-10-14).
- RM19 : les étiquettes viennent d'une liste fermée d'émotions et de thèmes, définie dans la spec de l'étiquetage ; la personne ne peut pas les corriger dans le MVP (source : décision de Yanis du 2026-10-14).
- RM20 : l'export produit un fichier JSON qui contient toutes les entrées et leurs étiquettes (source : décision de Yanis du 2026-10-14 ; format : [spec 005](specs/005-export-et-suppression-totale.md)).
- RM21 : le bilan porte sur une semaine du lundi au dimanche, et n'est produit qu'à partir de 3 entrées dans la semaine (source : décision de Yanis du 2026-10-14).
- RM22 : l'app est en français seulement ; l'étiquetage et le bilan sont évalués en français (source : décision de Yanis du 2026-10-14).
- RM23 : la personne exporte vers la destination de son choix, par la feuille de partage du système (Fichiers, AirDrop, mail…). C'est la seule exception à RM1 : elle est toujours déclenchée par la personne, jamais par l'app, et l'[ADR-003](adr/003-export-par-la-feuille-de-partage.md) la documente (source : décision de Yanis du 2026-10-14).
- RM24 : une entrée sans texte n'est pas analysée : l'humeur seule ne donne pas d'étiquette, et aucune analyse n'est enregistrée pour elle (source : décision de Yanis du 2026-10-14).
- RM25 : une série d'humeurs très basses déclenche l'écran d'aide, même sans texte. Le seuil est réglable par la personne, en trois degrés de sensibilité (décision de Yanis du 2026-10-14) ; leurs valeurs sont dans la spec (spec : [`docs/specs/002-garde-fou-detresse.md`](specs/002-garde-fou-detresse.md)).
- RM26 : un téléchargement du modèle interrompu repart de zéro (source : décision de Yanis du 2026-10-14).
- RM27 : le texte d'une entrée compte 2 000 caractères visibles au plus (un émoji composé compte pour un) (spec : [`docs/specs/001-saisie-et-liste-des-entrees.md`](specs/001-saisie-et-liste-des-entrees.md)).
- RM28 : la suppression d'une entrée est définitive et demande une confirmation (spec : [`docs/specs/001-saisie-et-liste-des-entrees.md`](specs/001-saisie-et-liste-des-entrees.md)).
- RM29 : aucun degré de sensibilité ne désactive le garde-fou ; la détection par le texte ne dépend pas de ce réglage, et une erreur de lecture du réglage applique le degré par défaut (spec : [`docs/specs/002-garde-fou-detresse.md`](specs/002-garde-fou-detresse.md)).
- RM30 : le téléchargement du modèle ne contacte que Hugging Face : une URL HTTPS épinglée sur une révision, puis ses redirections, seulement vers `huggingface.co` ou un hôte en `.huggingface.co` ou `.hf.co`, en HTTPS. La requête ne porte aucune donnée de la personne ni aucun identifiant de l'appareil (spec : [`docs/specs/003-telechargement-du-modele.md`](specs/003-telechargement-du-modele.md)).
- RM31 : la proposition de téléchargement s'ouvre d'elle-même une seule fois, après l'enregistrement de la première entrée « en attente » ; ensuite, la personne la retrouve dans les Réglages et dans le détail d'une entrée en attente (spec : [`docs/specs/003-telechargement-du-modele.md`](specs/003-telechargement-du-modele.md)).
- RM32 : le téléchargement ne tourne que l'app ouverte, y compris pendant que la personne écrit ; s'il est interrompu, il repart de zéro (RM26) (spec : [`docs/specs/003-telechargement-du-modele.md`](specs/003-telechargement-du-modele.md)).
- RM33 : la liste fermée compte 12 émotions et 12 thèmes, en français, sans aucun nom de trouble ; une entrée reçoit de 0 à 3 émotions et de 0 à 2 thèmes, avec au moins une étiquette (spec : [`docs/specs/004-etiquetage-automatique.md`](specs/004-etiquetage-automatique.md)).
- RM34 : les entrées « en attente » sont analysées automatiquement, sans bloquer la saisie, dès que le modèle est prêt (au démarrage, après chaque enregistrement, à la fin du téléchargement, au retour de l'app au premier plan), une à la fois, la plus récente d'abord, et seulement quand l'app est au premier plan : une analyse interrompue par la mise en arrière-plan laisse l'entrée « en attente ». Une entrée « sans étiquette » ou « non analysée » n'est jamais analysée de nouveau ; un modèle impossible à charger laisse les entrées « en attente » (spec : [`docs/specs/004-etiquetage-automatique.md`](specs/004-etiquetage-automatique.md)).
- RM35 : juste avant chaque analyse, le texte passe de nouveau par le détecteur de détresse ; une entrée détectée devient « non analysée » sans être transmise au modèle, et sans écran d'aide (spec : [`docs/specs/004-etiquetage-automatique.md`](specs/004-etiquetage-automatique.md)).
- RM36 : seul le texte de l'entrée est transmis au modèle, sans l'humeur ni la date (spec : [`docs/specs/004-etiquetage-automatique.md`](specs/004-etiquetage-automatique.md)).
- RM40 : l'export contient toutes les entrées, y compris celles sans texte et celles en détresse, leurs étiquettes et le réglage de sensibilité aux humeurs basses, au format JSON versionné (`formatVersion`) ; il n'est possible que si le journal compte au moins une entrée (spec : [`docs/specs/005-export-et-suppression-totale.md`](specs/005-export-et-suppression-totale.md)).
- RM41 : le fichier d'export n'est pas chiffré, et l'app le dit sous le bouton d'export. Il n'existe que dans le cache de l'app, le temps du partage : il est effacé à la fermeture de la feuille de partage, et les dossiers temporaires d'export sont purgés au démarrage et avant chaque export (spec : [`docs/specs/005-export-et-suppression-totale.md`](specs/005-export-et-suppression-totale.md)).
- RM42 : la suppression totale exige d'écrire « SUPPRIMER » (sans tenir compte de la casse ni des espaces autour). Elle efface aussi les fichiers temporaires d'export, puis l'app revient à l'état du premier lancement (spec : [`docs/specs/005-export-et-suppression-totale.md`](specs/005-export-et-suppression-totale.md)).
- RM43 : la suppression totale efface la base avant la clé, jamais l'inverse. Interrompue, elle reprend au démarrage suivant, avant toute ouverture de la base (spec : [`docs/specs/005-export-et-suppression-totale.md`](specs/005-export-et-suppression-totale.md)).
- RM44 : quand la clé de la base est introuvable, l'app propose la suppression totale pour repartir de zéro, sans jamais la lancer d'elle-même (spec : [`docs/specs/005-export-et-suppression-totale.md`](specs/005-export-et-suppression-totale.md)).
- RM45 : au démarrage, une nouvelle installation (ni marqueur d'installation ni base) efface toute clé restée dans le trousseau ; une base présente sans marqueur n'est jamais privée de sa clé (spec : [`docs/specs/005-export-et-suppression-totale.md`](specs/005-export-et-suppression-totale.md)).

- RM50 : le bilan compte toutes les entrées de la semaine, quel que soit leur statut d'analyse, chacune dans la semaine de son jour local de saisie. Ses chiffres : nombre d'entrées, humeur moyenne au dixième, répartition des humeurs, jours notés, au plus 3 étiquettes fréquentes, et l'évolution par rapport à la semaine précédente si celle-ci a un bilan (spec : [`docs/specs/006-bilan-de-la-semaine.md`](specs/006-bilan-de-la-semaine.md)).
- RM51 : pour le bilan, le modèle ne reçoit que des faits sans chiffre calculés par l'app, jamais le texte, la date ni l'humeur d'une entrée (spec : [`docs/specs/006-bilan-de-la-semaine.md`](specs/006-bilan-de-la-semaine.md)).
- RM52 : une semaine dont une entrée est à « Très bas » ou en détresse n'a pas de texte généré : son bilan s'en tient aux chiffres, sans mention de l'écran d'aide (spec : [`docs/specs/006-bilan-de-la-semaine.md`](specs/006-bilan-de-la-semaine.md)).
- RM53 : le texte du bilan n'est montré que s'il passe des règles déterministes : aucun chiffre ni mot de nombre, aucune expression de conseil, de soin ou de jugement de la liste de la spec, aucune détresse détectée, 300 caractères visibles au plus. Sinon, le bilan s'affiche avec ses seuls chiffres, sans plantage (spec : [`docs/specs/006-bilan-de-la-semaine.md`](specs/006-bilan-de-la-semaine.md)).
- RM54 : le texte du bilan n'est jamais enregistré ; il reste en mémoire tant que l'app est ouverte (spec : [`docs/specs/006-bilan-de-la-semaine.md`](specs/006-bilan-de-la-semaine.md)).
- RM55 : le bilan s'ouvre depuis la liste, sur la semaine en cours ; la personne peut remonter semaine par semaine jusqu'à celle de sa première entrée (spec : [`docs/specs/006-bilan-de-la-semaine.md`](specs/006-bilan-de-la-semaine.md)).

## Parcours utilisateur

### Personne qui tient son journal

1. Elle ouvre l'app pour la première fois et découvre qu'elle fonctionne sans compte.
2. Le soir, elle note son humeur et, si elle veut, quelques mots (saisie d'une entrée).
3. À sa première entrée à analyser, elle accepte de télécharger le modèle local, après avoir vu sa taille (téléchargement du modèle).
4. Si son texte contient des signes de détresse, ou si ses dernières humeurs sont toutes « Très bas », l'écran d'aide s'affiche à la place de la liste, et l'entrée n'est jamais analysée (détection de détresse). Elle choisit dans les Réglages la sensibilité aux humeurs basses.
5. Sinon, l'app propose des étiquettes, analysées sur le téléphone, en arrière-plan, dès que le modèle est prêt (étiquetage automatique).
6. Elle parcourt ses entrées passées et leurs étiquettes, et peut en supprimer une (saisie d'une entrée, liste).
7. Depuis la liste, elle ouvre le bilan de sa semaine, ou d'une semaine passée : ses chiffres et, quand c'est possible, un court texte écrit sur le téléphone (bilan de la semaine).
8. Elle peut à tout moment exporter ses données, ou tout supprimer (export et suppression totale).

## Fonctionnalités

Une ligne par fonctionnalité, regroupées par phase. Statuts : à spécifier, spec brouillon, spec validée, implémentée (mergée, test humain en attente), livrée (test humain positif). Phases et lots : [plan](plan.md#périmètre).

| Phase | Fonctionnalité | Spec | Statut |
| --- | --- | --- | --- |
| MVP (lot E) | Saisie d'une entrée et liste des entrées, stockage local chiffré | [001](specs/001-saisie-et-liste-des-entrees.md) | implémentée (PR #13) ; CA31 à CA36 en attente de validation |
| MVP (lot F) | Détection de détresse et écran d'aide, réglage de la sensibilité | [002](specs/002-garde-fou-detresse.md) | implémentée (PR #19) |
| MVP (lot G) | Téléchargement du modèle local | [003](specs/003-telechargement-du-modele.md) | implémentée (PR #22) |
| MVP (lot G) | Étiquetage automatique | [004](specs/004-etiquetage-automatique.md) | implémentée (PR #23) |
| MVP (lot H) | Export et suppression totale | [005](specs/005-export-et-suppression-totale.md) | spec validée |
| Si le temps le permet (lot I) | Bilan de la semaine | [006](specs/006-bilan-de-la-semaine.md) | spec validée |

## Questions ouvertes

Questions métier non tranchées. Une fois la réponse donnée, elle rejoint la section concernée, et la question est retirée.

Points de la [spec 004](specs/004-etiquetage-automatique.md) que la spec ne fixe pas, et que l'implémentation (PR #23) a tranchés sans les écrire (relevé du 2026-10-15). Yanis avait délégué les décisions métier de cette spec à l'agent, mais ces choix ont été faits dans le code, sans passer par la spec ni par sa validation : ils remontent ici pour être confirmés et écrits dans la spec, ou changés. Le comportement actuel est décrit.

- **Écriture du résultat qui échoue (CA8)** : la spec dit que l'entrée reste « en attente », sans dire quand elle est reprise. Aujourd'hui, la file s'arrête (`lib/analysis/analysis_queue.dart`, l. 158 à 163) et libère le modèle (l. 166 à 170) ; l'entrée est analysée de nouveau, par un nouvel appel au modèle, au prochain réveil de la file : tout changement de la liste des entrées (un enregistrement, une suppression), un changement d'état du modèle ou le lancement suivant. Si l'écriture échoue toujours, chaque changement du journal relance une analyse de la même entrée ; comme la file prend toujours la plus récente d'abord, aucune entrée plus ancienne n'est plus analysée. Faut-il réessayer ainsi, attendre le lancement suivant, ou limiter le nombre d'essais ?
- **Ordre à égalité de date (RM34, CA6)** : la date de saisie est à la seconde, et la spec dit « la plus récente d'abord » sans traiter l'égalité. Aujourd'hui, à date égale, l'entrée de plus grand identifiant, donc la dernière enregistrée, passe d'abord (l. 130 à 133).
- **Touche d'une puce dans la liste (CA26)** : la spec dit qu'il ne se passe rien. Dans le détail, c'est le cas. Dans la liste, les puces sont dans la carte : les toucher ouvre le détail, comme le reste de la carte ; la puce elle-même n'a aucune action. Est-ce le comportement voulu ?
- **Annonce d'un changement de statut (CA28)** : la spec demande que, dans la section « Étiquettes » du détail, un changement de statut de l'analyse soit annoncé, sans dire lequel. Aujourd'hui, dans le détail, « Analyse en cours sur ton téléphone… » est une région dynamique (`liveRegion`), annoncée à son apparition ; l'arrivée des étiquettes ou de « Aucune étiquette n'a été proposée » n'a pas d'annonce propre. Quels changements annoncer ? Question voisine, hors du CA28 : dans la liste, la carte a un libellé unique qui masque ses éléments, et la mention d'analyse n'y est pas annoncée ; faut-il l'annoncer ?
- **Libellé de carte avec étiquettes (CA27 et CA36 de la spec 001)** : CA36 borne l'extrait du texte à 120 caractères, CA27 ajoute « étiquettes : … » à la fin. Aujourd'hui, le libellé lit l'humeur, son chiffre, l'heure, l'extrait borné, puis toutes les étiquettes (jusqu'à 5). Faut-il borner le libellé complet ?
