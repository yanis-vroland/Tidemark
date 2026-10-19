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
| Semaine locale | `LocalWeek` | Semaine du lundi au dimanche, en jours locaux, qui porte un bilan ([spec 006](specs/006-bilan-de-la-semaine.md)). |
| Calculateur du bilan | `WeeklyReviewCalculator` | Code de l'app qui calcule tous les chiffres du bilan, sans modèle (RM10, RM50). |
| Faits du bilan | `ReviewFacts` : `WeekRegularity`, `ReviewTrend` | Seules informations transmises au modèle pour le bilan, sans aucun chiffre : libellé de l'humeur moyenne, régularité, étiquettes fréquentes, tendance (RM51). |
| Rédacteur du bilan | `ReviewWriter` | Interface qui met en mots les faits du bilan avec le modèle local ; une implémentation factice sert aux tests ([spec 006](specs/006-bilan-de-la-semaine.md)). |
| Validateur du bilan | `ReviewTextValidator` | Règles déterministes qu'un texte du bilan doit passer pour être montré (RM53). |
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
| Modèle local | prêt | absent | Empreinte fausse ou fichier illisible, constatés avant le premier chargement du lancement (RM11, [spec 003](specs/003-telechargement-du-modele.md) CA34, [ADR-004](adr/004-integrite-du-moteur-et-du-modele.md)) ou après un échec de chargement (CA32) : fichier effacé, retéléchargement possible | App |
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
- RM35 : juste avant chaque analyse, le texte passe de nouveau par le détecteur de détresse ; une entrée détectée devient « non analysée » sans être transmise au modèle, et sans écran d'aide. Si ce passage en « non analysée » échoue, l'entrée reste « en attente », n'est toujours pas transmise au modèle, et la file suit RM57 (spec : [`docs/specs/004-etiquetage-automatique.md`](specs/004-etiquetage-automatique.md), CA40 ; agent, par délégation de Yanis, 2026-10-16).
- RM36 : seul le texte de l'entrée est transmis au modèle, sans l'humeur ni la date (spec : [`docs/specs/004-etiquetage-automatique.md`](specs/004-etiquetage-automatique.md)).
- RM40 : l'export contient toutes les entrées, y compris celles sans texte et celles en détresse, leurs étiquettes et le réglage de sensibilité aux humeurs basses, au format JSON versionné (`formatVersion`) ; il n'est possible que si le journal compte au moins une entrée (spec : [`docs/specs/005-export-et-suppression-totale.md`](specs/005-export-et-suppression-totale.md)).
- RM41 : le fichier d'export n'est pas chiffré, et l'app le dit sous le bouton d'export. Il n'existe que dans le cache de l'app, le temps du partage : il est effacé à la fermeture de la feuille de partage, et les dossiers temporaires d'export sont purgés au démarrage et avant chaque export (spec : [`docs/specs/005-export-et-suppression-totale.md`](specs/005-export-et-suppression-totale.md)).
- RM42 : la suppression totale exige d'écrire « SUPPRIMER » (sans tenir compte de la casse ni des espaces autour). Elle efface aussi les fichiers temporaires d'export, puis l'app revient à l'état du premier lancement (spec : [`docs/specs/005-export-et-suppression-totale.md`](specs/005-export-et-suppression-totale.md)).
- RM43 : la suppression totale efface la base avant la clé, jamais l'inverse. Interrompue, elle reprend au démarrage suivant, avant toute ouverture de la base (spec : [`docs/specs/005-export-et-suppression-totale.md`](specs/005-export-et-suppression-totale.md)).
- RM44 : quand la clé de la base est introuvable, l'app propose la suppression totale pour repartir de zéro, sans jamais la lancer d'elle-même (spec : [`docs/specs/005-export-et-suppression-totale.md`](specs/005-export-et-suppression-totale.md)).
- RM45 : au démarrage, une nouvelle installation (ni marqueur d'installation ni base) efface toute clé restée dans le trousseau ; une base présente sans marqueur n'est jamais privée de sa clé. Exception acceptée par Yanis le 2026-10-16 : si l'effacement de la clé restante échoue, la base neuve garde cette clé ([architecture, « Marqueur d'installation »](architecture-technique.md#sécurité)) (spec : [`docs/specs/005-export-et-suppression-totale.md`](specs/005-export-et-suppression-totale.md), CA32).

- RM50 : le bilan compte toutes les entrées de la semaine, quel que soit leur statut d'analyse, chacune dans la semaine de son jour local de saisie. Ses chiffres : nombre d'entrées, humeur moyenne au dixième, répartition des humeurs, jours notés, au plus 3 étiquettes fréquentes, et l'évolution par rapport à la semaine précédente si celle-ci a un bilan (spec : [`docs/specs/006-bilan-de-la-semaine.md`](specs/006-bilan-de-la-semaine.md)).
- RM51 : pour le bilan, le modèle ne reçoit que des faits sans chiffre calculés par l'app, jamais le texte, la date ni l'humeur d'une entrée (spec : [`docs/specs/006-bilan-de-la-semaine.md`](specs/006-bilan-de-la-semaine.md)).
- RM52 : une semaine dont une entrée est à « Très bas » ou en détresse n'a pas de texte généré : son bilan s'en tient aux chiffres, sans mention de l'écran d'aide (spec : [`docs/specs/006-bilan-de-la-semaine.md`](specs/006-bilan-de-la-semaine.md)).
- RM53 : le texte du bilan n'est montré que s'il passe des règles déterministes : aucun chiffre ni mot de nombre, aucune expression de conseil, de soin ou de jugement de la liste de la spec, aucune détresse détectée, 300 caractères visibles au plus. Sinon, le bilan s'affiche avec ses seuls chiffres, sans plantage (spec : [`docs/specs/006-bilan-de-la-semaine.md`](specs/006-bilan-de-la-semaine.md)).
- RM54 : le texte du bilan n'est jamais enregistré ; il reste en mémoire tant que l'app est ouverte (spec : [`docs/specs/006-bilan-de-la-semaine.md`](specs/006-bilan-de-la-semaine.md)).
- RM55 : le bilan s'ouvre depuis la liste, sur la semaine en cours ; la personne peut remonter semaine par semaine jusqu'à celle de sa première entrée (spec : [`docs/specs/006-bilan-de-la-semaine.md`](specs/006-bilan-de-la-semaine.md)).

Règles tranchées le 2026-10-16 à partir des questions ouvertes des specs 004 (PR #25) et 006. Yanis (« je valide tout ») a retenu le comportement actuel pour RM56, RM58 et RM59, et accepté de corriger le défaut ou le manque de RM57, RM60 et RM61 ; le contenu de ces trois règles cibles est de l'agent, par délégation de Yanis du même jour. RM57, RM60 et RM61 sont mises en œuvre par la PR #37 ; le détail est dans la spec citée.

- RM56 : à date de saisie égale (date à la seconde), la file d'analyse prend d'abord l'entrée enregistrée en dernier, celle de plus grand identifiant. Comportement actuel retenu (spec : [`docs/specs/004-etiquetage-automatique.md`](specs/004-etiquetage-automatique.md), RM34, CA6).
- RM57 : si l'écriture du résultat d'une analyse échoue, l'entrée reste « en attente » et la file s'arrête jusqu'au prochain événement de RM34 (enregistrement, modèle prêt, retour au premier plan, autre changement du journal). Elle ne relance jamais la même entrée en boucle : l'entrée en échec n'est plus reprise pendant la même série d'événements, puis passe après les autres entrées « en attente », pour que les plus anciennes soient atteintes ; ce rang n'est gardé qu'en mémoire, et une écriture réussie l'efface (spec : [`docs/specs/004-etiquetage-automatique.md`](specs/004-etiquetage-automatique.md), CA8 et CA39).
- RM58 : une puce d'étiquette n'a aucune action propre. Dans le détail, la toucher ne fait rien ; dans la liste, elle fait partie de la carte, et la toucher ouvre le détail comme le reste de la carte. Comportement actuel retenu (spec : [`docs/specs/004-etiquetage-automatique.md`](specs/004-etiquetage-automatique.md), CA26).
- RM59 : le libellé d'une carte de la liste pour le lecteur d'écran lit l'humeur, son chiffre, l'heure, l'extrait du texte borné à 120 caractères, puis toutes les étiquettes de l'entrée (5 au plus) ; le libellé complet n'a pas d'autre borne. Comportement actuel retenu (specs : [`docs/specs/004-etiquetage-automatique.md`](specs/004-etiquetage-automatique.md), CA27 ; [`docs/specs/001-saisie-et-liste-des-entrees.md`](specs/001-saisie-et-liste-des-entrees.md), CA36).
- RM60 : dans la section « Étiquettes » du détail, chaque changement de statut de l'analyse est annoncé au lecteur d'écran : l'apparition de « Analyse en cours sur ton téléphone… », puis la fin de l'analyse, avec les étiquettes ou « Aucune étiquette n'a été proposée », une seule fois ; ouvrir le détail d'une entrée déjà analysée n'annonce rien. Dans la liste, la mention d'analyse n'a pas d'annonce propre : elle se lit avec le libellé de la carte (spec : [`docs/specs/004-etiquetage-automatique.md`](specs/004-etiquetage-automatique.md), CA28).
- RM61 : partout où l'app écrit une date (bilan, intertitres de la liste, détail d'une entrée), le premier jour d'un mois s'écrit « 1er », selon l'usage français (« Du lundi 26 octobre au dimanche 1er novembre », « Dimanche 1er novembre »), y compris dans le libellé lu par le lecteur d'écran ; les autres jours restent en chiffres seuls (specs : [`docs/specs/006-bilan-de-la-semaine.md`](specs/006-bilan-de-la-semaine.md), CA38 ; [`docs/specs/001-saisie-et-liste-des-entrees.md`](specs/001-saisie-et-liste-des-entrees.md), CA3).

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
| MVP (lot E) | Saisie d'une entrée et liste des entrées, stockage local chiffré | [001](specs/001-saisie-et-liste-des-entrees.md) | livrée (PR #13, test humain positif le 2026-10-19) ; CA31 à CA36 en attente de validation |
| MVP (lot F) | Détection de détresse et écran d'aide, réglage de la sensibilité | [002](specs/002-garde-fou-detresse.md) | livrée (PR #19, test humain positif le 2026-10-19) |
| MVP (lot G) | Téléchargement du modèle local | [003](specs/003-telechargement-du-modele.md) | livrée (PR #22, test humain positif le 2026-10-19) |
| MVP (lot G) | Étiquetage automatique | [004](specs/004-etiquetage-automatique.md) | livrée (PR #23, test humain positif le 2026-10-19) |
| MVP (lot H) | Export et suppression totale | [005](specs/005-export-et-suppression-totale.md) | livrée (PR #28, test humain positif le 2026-10-19) |
| Si le temps le permet (lot I) | Bilan de la semaine | [006](specs/006-bilan-de-la-semaine.md) | livrée (PR #27, test humain positif le 2026-10-19) |
| Publication | Logo : icône, écran de lancement, état vide de la liste | [007](specs/007-logo.md) | spec brouillon, implémentée dans la PR en cours |

## Questions ouvertes

Questions métier non tranchées. Une fois la réponse donnée, elle rejoint la section concernée, et la question est retirée.

Aucune question ouverte au 2026-10-16.

- La question « Entrée sans analyse » (2026-10-14, lot G) est tranchée par RM34.
- Les cinq points de la [spec 004](specs/004-etiquetage-automatique.md) relevés le 2026-10-15 (PR #25), que l'implémentation de la PR #23 avait tranchés sans les écrire, sont tranchés le 2026-10-16 : ordre à égalité de date (RM56), touche d'une puce (RM58) et libellé de carte (RM59), comportement actuel retenu par Yanis ; écriture du résultat qui échoue (RM57) et annonce d'un changement de statut (RM60, [issue #29](https://github.com/yanis-vroland/Tidemark/issues/29)), correction acceptée par Yanis, règle cible de l'agent par délégation.
- La question « Premier du mois dans les dates du bilan » (2026-10-15, lot I) est tranchée par RM61 (correction acceptée par Yanis, portée fixée par l'agent par délégation), mise en œuvre par la PR #37.
