# Spec 005 : export et suppression totale

Statut : proposée, en attente de validation par Yanis (spec, maquette et [ADR-003](../adr/003-export-par-la-feuille-de-partage.md), au statut « proposé »). Décisions métier déléguées à l'agent par Yanis le 2026-10-14 : voir « Questions ouvertes ».
Date : 2026-10-14

## Besoin

En tant que personne qui tient son journal, je veux pouvoir en faire une copie que j'envoie où je veux, et pouvoir tout effacer d'un coup, afin de rester maîtresse de mes données : les garder si je change de téléphone, ou n'en laisser aucune trace.

Lot H du [plan](../plan.md). Règles du [cahier des charges](../cahier-des-charges-fonctionnel.md) appliquées : RM1, RM12, RM20, RM23, RM29, RM40 à RM45. Stockage et parade du marqueur d'installation : [ADR-002](../adr/002-stockage-local-chiffre.md). Exception à RM1 pour l'export : [ADR-003](../adr/003-export-par-la-feuille-de-partage.md). Maquette : voir « Maquette ».

## Écrans

- **Réglages** (`SettingsScreen`, spec 002) : nouvelle section « Mes données », sous la section « Écran d'aide ». Elle porte le bouton « Exporter mes données » et le bouton « Tout supprimer », en couleur `danger`. L'écran défile.
- **Confirmation de la suppression totale** (`WipeConfirmationScreen`) : nouvel écran plein, ouvert par « Tout supprimer » (Réglages) ou par « Tout supprimer et repartir de zéro » (écran « clé introuvable »). La personne doit y écrire « SUPPRIMER ».
- **Liste des entrées** (spec 001) : après une suppression totale réussie, état vide avec le message « Toutes tes données ont été supprimées ».
- **Écran « journal impossible à ouvrir »** (`StartupErrorApp`, spec 001, CA35) : dans le cas « clé introuvable », ajout du bouton « Tout supprimer et repartir de zéro ». Nouveau cas : « La suppression n'est pas terminée », quand une suppression interrompue ne peut pas être reprise au démarrage.
- **Feuille de partage du système** : ce n'est pas un écran de l'app. Elle n'est pas dessinée.

## Règles

### Export (RM20, RM23, RM40, RM41)

1. L'export n'a lieu que sur un appui de la personne sur « Exporter mes données ». L'app n'exporte jamais d'elle-même, et rien n'est envoyé ailleurs que vers la feuille de partage du système, où la personne choisit la destination (ADR-003).
2. Étapes, dans cet ordre :
   1. purger les dossiers temporaires d'export (voir « Données ») ;
   2. lire toutes les entrées, leurs étiquettes et le réglage de sensibilité ; toute erreur de lecture fait échouer l'export, sans fichier partiel ;
   3. écrire le fichier `tidemark-export-AAAA-MM-JJ-HHMM.json` (date et heure locales du début de l'export) dans le dossier temporaire d'export ;
   4. ouvrir la feuille de partage avec ce seul fichier, de type `application/json` ;
   5. quand la feuille de partage se ferme, que la personne ait partagé ou annulé, ou si son ouverture échoue : effacer le fichier.
3. Le fichier n'est pas chiffré. La mention sous le bouton le dit, en permanence : « Il n'est pas chiffré : choisis bien où tu l'envoies. » Il n'y a pas de dialogue de confirmation en plus : la feuille de partage s'annule d'un geste.
4. Journal sans entrée : le bouton est désactivé, avec la mention « Ton journal est vide : il n'y a rien à exporter. »
5. L'export contient toutes les entrées, y compris celles sans texte et celles en détresse (statut « non analysée »). Il contient aussi le réglage de sensibilité aux humeurs basses : c'est une donnée de la personne (glossaire, « Export »).

### Format du fichier d'export (version 1)

Fichier JSON en UTF-8 sans BOM, indenté de 2 espaces, terminé par un saut de ligne. Les caractères non ASCII sont écrits tels quels ; seuls `"`, `\` et les caractères de contrôle (U+0000 à U+001F) sont échappés, `/` ne l'est pas : c'est le comportement de `JsonEncoder.withIndent('  ')` de Dart. Champs, dans cet ordre :

| Champ | Type | Contenu |
| --- | --- | --- |
| `formatVersion` | entier | `1`. Tout changement du format (champ ajouté, retiré, renommé ou de sens différent) l'augmente de 1. |
| `app` | texte | `"Tidemark"`. |
| `exportedAt` | texte | Date et heure locales de l'export, ISO 8601 à la seconde avec le décalage (`2026-10-14T21:52:07+02:00`). |
| `settings.lowMoodSensitivity` | texte | `high`, `normal` ou `low` (spec 002). |
| `entries` | liste | Toutes les entrées, de la plus ancienne à la plus récente (instant de saisie, puis identifiant). |
| `entries[].createdAt` | texte | Date et heure de saisie, ISO 8601 à la seconde, avec le décalage enregistré à la saisie (spec 001), pas celui du moment de l'export. |
| `entries[].mood` | entier | De 1 à 5 (RM3). |
| `entries[].moodLabel` | texte | Libellé fixe de l'humeur (RM3), pour une lecture sans l'app. |
| `entries[].text` | texte ou `null` | Le texte tel qu'enregistré, ou `null` sans texte (RM13). |
| `entries[].analysisStatus` | texte | `pending`, `tagged`, `untagged` ou `skipped` (glossaire). |
| `entries[].tags` | liste | Les étiquettes de l'entrée : `{"kind": "emotion" ou "theme", "label": "<libellé de la liste fermée>"}`, triées par type (`emotion` avant `theme`), puis par libellé comparé unité de code UTF-16 par unité de code UTF-16 (`String.compareTo` de Dart, sans règle propre à la langue). Liste vide sans étiquette, et pour toutes les entrées tant que le lot G n'est pas livré. |

L'identifiant interne d'une entrée n'est pas exporté. Exemple, avec des données fictives :

```json
{
  "formatVersion": 1,
  "app": "Tidemark",
  "exportedAt": "2026-10-14T21:52:07+02:00",
  "settings": {
    "lowMoodSensitivity": "normal"
  },
  "entries": [
    {
      "createdAt": "2026-10-13T22:05:00+02:00",
      "mood": 2,
      "moodLabel": "Bas",
      "text": "Encore une nuit trop courte.\nJe repousse tout à demain.",
      "analysisStatus": "tagged",
      "tags": [
        { "kind": "emotion", "label": "fatigue" },
        { "kind": "theme", "label": "sommeil" }
      ]
    },
    {
      "createdAt": "2026-10-14T08:15:00+02:00",
      "mood": 3,
      "moodLabel": "Neutre",
      "text": null,
      "analysisStatus": "skipped",
      "tags": []
    }
  ]
}
```

Les libellés d'étiquettes de l'exemple sont indicatifs : la liste fermée est fixée par la spec de l'étiquetage (lot G, RM19). Cette spec doit garder la forme `{kind, label}`, ou augmenter `formatVersion`.

### Suppression totale (RM12, RM42, RM43)

La suppression demande d'écrire « SUPPRIMER » dans un champ, sans tenir compte de la casse ni des espaces au début et à la fin. Puis l'app efface, dans cet ordre :

1. **Marqueur de suppression en cours** : écrire le fichier `wipe-pending`. S'il ne peut pas être écrit, rien n'est effacé et la suppression s'arrête (CA20).
2. **Base** : fermer la base si elle est ouverte, effacer `journal.db-wal`, `journal.db-shm` et `journal.db-journal`, puis `journal.db`. Les entrées, les étiquettes et les réglages sont dans la base (spec 002) : ils partent avec elle.
3. **Clé** : effacer toute clé de l'app du trousseau ou du Keystore (`KeyStore.deleteAll`).
4. **Modèle local** : effacer le dossier du modèle, fichier complet ou téléchargement partiel.
5. **Fichiers temporaires d'export** : purger les dossiers temporaires d'export.
6. **Fin** : effacer `wipe-pending`, ouvrir une base neuve (nouvelle clé, spec 001, CA23) et afficher la liste vide avec le message de fin.

Garanties :

- **La clé n'est effacée qu'après la base.** Une base sans sa clé ne reste donc jamais sur le téléphone à cause de la suppression ; et comme l'app ne crée jamais de clé tant qu'un fichier `journal.db` existe (spec 001), elle ne peut pas produire une base illisible avec une nouvelle clé.
- **Chaque étape est idempotente** : une cible déjà absente compte comme effacée (modèle jamais téléchargé, base absente parce que la clé était introuvable…).
- **Une suppression interrompue reprend** : tant que `wipe-pending` existe, l'app n'ouvre pas la base. Au démarrage, elle rejoue les étapes 2 à 6 avant toute autre chose. Après un échec en cours de route, « Réessayer » les rejoue aussi.
- **Le marqueur d'installation n'est pas effacé** : l'app reste installée.

### Clé introuvable (spec 001, CA35 ; RM44)

L'écran « Ton journal n'a pas pu être ouvert », dans le cas « clé introuvable », propose « Tout supprimer et repartir de zéro ». Ce bouton ouvre la même confirmation, avec une liste adaptée (les entrées sont illisibles sans leur clé, et l'export est impossible). L'app ne lance jamais la suppression d'elle-même : la personne peut vouloir retrouver sa clé (restauration du trousseau) avant de tout perdre. Pour toute autre cause (« Ferme l'app, puis rouvre-la »), aucun bouton de suppression n'est proposé : la cause peut être passagère.

### Marqueur d'installation (ADR-002, RM45)

Le fichier vide `installed`, dans le dossier de la base, est effacé par le système à la désinstallation. Au démarrage, après la reprise d'une éventuelle suppression interrompue et avant l'ouverture de la base :

| Marqueur `installed` | Fichier `journal.db` | Action |
| --- | --- | --- |
| présent | — | Rien. |
| absent | absent | Nouvelle installation : effacer toute clé restée dans le trousseau (`KeyStore.deleteAll`), puis créer le marqueur. La base neuve aura une clé neuve. |
| absent | présent | Installation antérieure à cette spec (lots E et F) : ne rien effacer, créer le marqueur. Effacer la clé rendrait le journal illisible. |

Un échec d'effacement de la clé ou d'écriture du marqueur n'empêche pas l'app de s'ouvrir : le marqueur n'est pas créé, et tout est retenté au démarrage suivant.

## Critères d'acceptation

### Réglages

- CA1 : Étant donné l'écran Réglages chargé, quand il s'affiche, alors la section « Mes données » apparaît sous la section « Écran d'aide », avec la phrase « Tout reste sur ce téléphone. Tu peux en faire une copie, ou tout effacer. », le bouton « Exporter mes données » suivi de la mention « Un fichier JSON avec toutes tes entrées et leurs étiquettes. Il n'est pas chiffré : choisis bien où tu l'envoies. », puis le bouton « Tout supprimer » en `danger` suivi de la mention « Efface définitivement tes entrées, tes réglages, la clé de ton journal et le modèle d'IA téléchargé. »
- CA2 : Étant donné la lecture des réglages en cours (spec 002, CA22), quand l'écran Réglages s'affiche, alors la section « Mes données » n'est pas visible.

### Export

- CA3 : Étant donné un journal avec au moins une entrée, quand la personne touche « Exporter mes données », alors le bouton devient « Préparation de l'export… », désactivé, « Tout supprimer » est désactivé, un geste de retour ne fait rien, puis la feuille de partage s'ouvre avec un seul fichier, nommé `tidemark-export-AAAA-MM-JJ-HHMM.json` (date et heure locales du début de l'export, par exemple `tidemark-export-2026-10-14-2152.json`), de type `application/json`.
- CA4 : Étant donné des entrées fictives connues et le degré « Haute », quand l'export est produit, alors le fichier est identique, octet pour octet, au JSON attendu au format de la version 1 : champs et ordre de la section « Format », échappement et tri des étiquettes tels que décrits, `formatVersion` à 1, `settings.lowMoodSensitivity` à `high`, entrées de la plus ancienne à la plus récente.
- CA5 : Étant donné une entrée saisie le 2026-10-14 à 21:40 avec un décalage de +02:00, quand l'export est produit alors que le téléphone est dans un autre fuseau, alors son `createdAt` vaut `2026-10-14T21:40:00+02:00`.
- CA6 : Étant donné une entrée sans texte et une entrée en détresse, quand l'export est produit, alors les deux y figurent : `text` à `null` pour la première, `analysisStatus` à `skipped` et `tags` vide pour les deux.
- CA7 : Étant donné une entrée avec des étiquettes, quand l'export est produit, alors chaque étiquette figure sous la forme `{"kind", "label"}`, `emotion` avant `theme`, puis par libellé en unités de code UTF-16 (« écoute » après « zen ») ; avant le lot G, `tags` est vide pour toutes les entrées.
- CA8 : Étant donné un texte avec des accents, un émoji composé, des guillemets, une barre oblique inverse et des retours à la ligne, quand le fichier exporté est relu par un lecteur JSON standard, alors le texte relu est identique au texte enregistré.
- CA9 : Étant donné la feuille de partage ouverte, quand elle se ferme, que la personne ait partagé ou annulé, alors le fichier temporaire est effacé, aucun message ne s'affiche et les deux boutons reviennent à leur état normal.
- CA10 : Étant donné un fichier d'export resté dans un dossier temporaire d'export (app arrêtée pendant le partage, copie gardée par la feuille de partage sur Android), quand l'app démarre ou qu'un nouvel export commence, alors les dossiers temporaires d'export sont vidés.
- CA11 : Étant donné une erreur pendant l'export (lecture de la base ou du réglage, écriture du fichier, ouverture de la feuille de partage), quand elle survient, alors le bandeau « L'export n'a pas abouti » s'affiche avec « Aucun fichier n'a été partagé. Vérifie la place libre sur le téléphone, puis réessaie. », le bouton devient « Réessayer l'export », et aucun fichier temporaire ne reste.
- CA12 : Étant donné un journal sans entrée, quand l'écran Réglages s'affiche, alors « Exporter mes données » est désactivé et la mention devient « Ton journal est vide : il n'y a rien à exporter. »
- CA13 : Étant donné l'app, quand elle démarre, enregistre une entrée ou ouvre les Réglages, alors aucun export n'est produit et la feuille de partage ne s'ouvre pas ; un appui sur « Exporter mes données » l'ouvre une seule fois, et le fichier n'est remis qu'à elle (RM1, RM23).

### Suppression totale

- CA14 : Étant donné l'écran Réglages, quand la personne touche « Tout supprimer », alors l'écran de confirmation s'affiche avec le titre « Tout supprimer ? », la liste de ce qui sera effacé (entrées et étiquettes, réglages, clé, modèle d'IA téléchargé), l'avertissement « Rien ne pourra être récupéré. Pour garder une copie, exporte d'abord tes données depuis les Réglages. », le champ « Pour confirmer, écris SUPPRIMER », le bouton « Tout supprimer définitivement » désactivé et « Annuler ».
- CA15 : Étant donné l'écran de confirmation, quand la personne écrit « SUPPRIMER », « supprimer » ou « Supprimer », avec ou sans espaces au début et à la fin, alors le bouton s'active ; avec tout autre texte (« SUPPRIME », « SUPPRIMER. », « SUP PRIMER »), il reste désactivé. Le champ propose le clavier en majuscules (`TextCapitalization.characters`), sans correction automatique ni apprentissage du clavier.
- CA16 : Étant donné l'écran de confirmation, quand la personne touche « Annuler » ou fait un geste de retour, alors l'écran Réglages réapparaît et rien n'est effacé.
- CA17 : Étant donné « SUPPRIMER » écrit, quand la personne touche « Tout supprimer définitivement », alors le bouton devient « Suppression… », désactivé, le champ est désactivé, « Annuler » et le retour disparaissent, la mention « Si l'app se ferme, la suppression reprendra au prochain lancement. » s'affiche, et les étapes ont lieu dans l'ordre de la section « Suppression totale ».
- CA18 : Étant donné une suppression réussie, quand elle se termine, alors la liste vide s'affiche avec le message « Toutes tes données ont été supprimées » et « Ton journal repart de zéro, sur ce téléphone. » ; la base, ses fichiers `-wal`, `-shm` et `-journal`, la clé, le dossier du modèle et les dossiers temporaires d'export n'existent plus ; une nouvelle base a une nouvelle clé, différente de l'ancienne ; le degré de sensibilité est revenu à « Normale ».
- CA19 : Étant donné une suppression réussie, quand la personne enregistre une nouvelle entrée, alors la liste ne montre qu'elle.
- CA20 : Étant donné une erreur à l'écriture du marqueur `wipe-pending`, quand la personne confirme, alors rien n'est effacé, le bandeau « La suppression n'a pas commencé » s'affiche avec « Rien n'a été effacé. Réessaie. », et « Annuler » reste disponible.
- CA21 : Étant donné une erreur à une étape suivante (base, clé, modèle, fichiers temporaires), quand elle survient, alors les étapes suivantes n'ont pas lieu, `wipe-pending` reste, le bandeau « La suppression n'est pas terminée » s'affiche avec « Une partie de tes données a peut-être déjà été effacée. Réessaie : la suppression reprend où elle s'est arrêtée. », le bouton devient « Réessayer » (sans réécrire « SUPPRIMER »), et ni « Annuler » ni le retour ne sont proposés.
- CA22 : Étant donné le fichier `wipe-pending` présent au démarrage (app fermée pendant une suppression), quand l'app démarre, alors elle rejoue les étapes 2 à 6 avant d'ouvrir la base, puis affiche la liste vide avec le message de CA18.
- CA23 : Étant donné cette reprise au démarrage en échec, quand l'erreur survient, alors l'écran « La suppression n'est pas terminée » s'affiche avec le texte de CA21 et un bouton « Réessayer » ; la base n'est pas ouverte et aucune clé n'est créée.
- CA24 : Étant donné une étape de la suppression qui échoue, quelle qu'elle soit, quand l'erreur survient, alors la clé existe encore si `journal.db` existe encore, et aucune nouvelle clé n'est créée tant que `journal.db` existe (contrôle par mutation sur l'ordre des étapes).
- CA25 : Étant donné une cible déjà absente (modèle jamais téléchargé, base absente, clé absente, dossier temporaire absent), quand son étape s'exécute, alors elle réussit.

### Clé introuvable

- CA26 : Étant donné une base dont la clé est introuvable au démarrage, quand l'écran « Ton journal n'a pas pu être ouvert » s'affiche, alors il garde les textes de la spec 001 (CA35) et ajoute « Sans cette clé, elles ne pourront plus être lues. Tu peux tout supprimer et commencer un nouveau journal. » et le bouton « Tout supprimer et repartir de zéro », en `danger` ; pour toute autre cause, ce texte et ce bouton n'apparaissent pas.
- CA27 : Étant donné cet écran, quand la personne touche « Tout supprimer et repartir de zéro », alors la confirmation s'affiche avec « Retour », la liste « tes entrées et leurs étiquettes, illisibles sans leur clé ; tes réglages ; le modèle d'IA téléchargé. » et « Rien ne pourra être récupéré. Sans sa clé, ton journal ne peut pas être exporté. » ; après confirmation, la suppression a lieu comme en CA17 et CA18.
- CA28 : Étant donné une clé introuvable, quand l'app démarre, alors elle n'efface rien d'elle-même : la suppression n'a lieu qu'après la confirmation de la personne.

### Marqueur d'installation

- CA29 : Étant donné ni marqueur `installed` ni `journal.db`, et une clé restée dans le trousseau, quand l'app démarre, alors la clé restante est effacée, le marqueur est créé, puis une base neuve est créée avec une clé neuve, différente de l'ancienne.
- CA30 : Étant donné `journal.db` présent sans marqueur `installed` (installation antérieure à cette spec), quand l'app démarre, alors aucune clé n'est effacée, le marqueur est créé et le journal s'ouvre avec ses entrées.
- CA31 : Étant donné le marqueur `installed` présent, quand l'app démarre, alors aucune clé n'est effacée.
- CA32 : Étant donné une erreur à l'effacement de la clé restante ou à l'écriture du marqueur, quand l'app démarre, alors elle s'ouvre normalement sur la liste, et tout est retenté au démarrage suivant.

### Accessibilité et thème

- CA33 : Étant donné un lecteur d'écran, quand il parcourt la section « Mes données » et la confirmation, alors les boutons s'annoncent par leur libellé (« Exporter mes données », « Tout supprimer », « Tout supprimer définitivement »), avec leur état désactivé ou occupé ; le champ s'annonce « Pour confirmer, écris SUPPRIMER » ; les messages « Préparation de l'export… », « Suppression… », les bandeaux d'erreur et le message de fin de CA18 sont annoncés dès leur apparition.
- CA34 : Étant donné la taille de texte du système à 200 %, quand l'écran Réglages, la confirmation, la liste après suppression et l'écran « journal impossible à ouvrir » s'affichent, alors aucun texte n'est tronqué ni ne déborde, les écrans défilent et tous les boutons restent atteignables.
- CA35 : Étant donné le thème sombre du système, quand ces écrans s'affichent, alors ils utilisent les couleurs du thème sombre de la charte ; « Tout supprimer », « Tout supprimer définitivement » et « Tout supprimer et repartir de zéro » ont leur texte et leur bordure en `danger`, sur fond `surface-raised`, jamais un fond `danger` plein.

## Données

- **Export** :
  - `JournalExporter` : code Dart pur, `String buildExport({entries, sensitivity, exportedAt})` rend le JSON du format version 1 ; testable sans Flutter ni base.
  - `ShareSheet` : interface de la feuille de partage, `Future<void> shareFile(File file, {String mimeType})`. Implémentation `SharePlusShareSheet` sur le paquet `share_plus` (ADR-003) ; `FakeShareSheet` dans `test/support/`, qui garde les fichiers reçus.
  - `EntryRepository` : nouvelle opération `allEntriesWithTags()`, de la plus ancienne à la plus récente.
  - Dossiers temporaires d'export : `<cache de l'app>/tidemark-export/` (fichier de l'app) et `<cache de l'app>/share_plus/` (copie faite par `share_plus` sur Android, qui ne l'efface qu'au partage suivant). Le cache de l'app n'est pas sauvegardé par le système.
- **Suppression** :
  - `JournalWiper` : exécute les étapes dans l'ordre, chacune idempotente ; dépend de `KeyStore`, d'un accès aux fichiers injectable et de la fermeture de la base.
  - `KeyStore` (spec 001) : nouvelle opération `deleteAll()`, qui efface toute clé de l'app.
  - Dossier `Application Support/tidemark/` : `journal.db` et ses fichiers, `installed`, `wipe-pending`, et le dossier du modèle `model/`. **Contrainte pour le lot G** : le modèle et tout téléchargement partiel vivent dans `Application Support/tidemark/model/`, exclu des sauvegardes comme la base.
- **Démarrage** (`startApp`, spec 001) : reprise de `wipe-pending`, puis marqueur `installed`, puis ouverture de la base. `StartupErrorApp` gagne le cas « suppression non terminée ».
- **Dépendance** : `share_plus` 13.3.1 (BSD-3-Clause), version épinglée exactement ; justifiée dans la PR d'implémentation et dans l'ADR-003.

## Maquette

Artefact Claude de type « Design » ([lien privé](https://claude.ai/artifact/Fe2pd6Z9VV6Utfpg59JA9x)), construit sur la charte. La copie versionnée, qui fait foi, est dans [`docs/maquettes/005-export-et-suppression-totale/`](../maquettes/005-export-et-suppression-totale/).

Écrans, chacun en clair et en sombre :

- **Réglages**, page entière (l'écran défile) : nominal, export en cours, export en erreur, journal vide.
- **Confirmation** : champ vide, « SUPPRIMER » écrit, suppression en cours, suppression non commencée (CA20), suppression interrompue (CA21) ; et la variante ouverte depuis l'écran « clé introuvable ».
- **Liste après la suppression**.
- **Démarrage** : clé introuvable avec le nouveau bouton ; suppression à reprendre en échec.

Non dessinée : la feuille de partage (écran du système). Captures PNG absentes : voir le README de la maquette. Jetons : voir le README de la maquette.

## Cas limites et erreurs

- **Partage sur Android** : `share_plus` rend la main dès que la personne a choisi l'app de destination, qui peut lire le fichier un peu plus tard. Le fichier de l'app est effacé à ce moment ; la copie que `share_plus` garde dans `cache/share_plus` reste lisible par l'app de destination jusqu'au démarrage suivant ou à l'export suivant (CA10). À vérifier au test humain avec une app de messagerie et Fichiers ; si une destination échoue, la spec sera corrigée.
- **App tuée pendant le partage** : le fichier temporaire reste dans le cache de l'app (privé, non sauvegardé) jusqu'au démarrage suivant (CA10).
- **Fichier exporté, puis suppression totale** : la suppression n'efface pas les copies envoyées ailleurs (mail, Fichiers, autre téléphone). La confirmation ne le dit pas : elle parle de « ce téléphone ».
- **Gros journal** : aucune limite de taille ; le JSON est construit en mémoire (quelques mégaoctets pour plusieurs milliers d'entrées de 2 000 caractères au plus).
- **Changement de jour pendant l'export** : la date et l'heure du nom de fichier sont celles du début de l'export.
- **Deux exports dans la même minute** : même nom de fichier. Dans l'app, sans effet (purge avant chaque export) ; dans la destination, le système renomme ou remplace selon l'app choisie.
- **Suppression qui échoue à chaque essai** (trousseau ou Keystore inaccessible, stockage en lecture seule) : l'app reste sur « La suppression n'est pas terminée », sans retour au journal. C'est voulu : une base à moitié effacée ne doit pas être rouverte, et la personne a demandé de tout effacer. Issue de secours : désinstaller l'app, ce qui efface la base, le modèle et les marqueurs (la clé orpheline sur iOS est effacée à la réinstallation, RM45). Le README le dira (lot J).
- **Suppression pendant un téléchargement du modèle** (lot G) : le téléchargement est annulé avant l'étape 4. À reprendre dans la spec du lot G.
- **Suppression pendant une analyse** (lot G) : l'analyse en cours est abandonnée et son résultat n'est pas enregistré. À reprendre dans la spec du lot G.
- **Trousseau iOS jamais nettoyé** : si l'app est désinstallée sans suppression totale et jamais réinstallée, la clé orpheline reste dans le trousseau (ADR-002). Limite à écrire dans le README (lot J).

## Hors périmètre

- Import d'un fichier d'export (restauration sur un nouveau téléphone).
- Export chiffré par un mot de passe, export partiel (par période), autres formats (CSV, PDF).
- Export automatique ou sauvegarde programmée.
- Effacement des copies déjà partagées.
- Suppression sélective (seulement les étiquettes, seulement le modèle).

## Questions ouvertes

Aucune. Décisions prises par l'agent, à la demande de Yanis (2026-10-14) :

1. **Réglage dans l'export** : le degré de sensibilité est exporté (`settings.lowMoodSensitivity`) ; l'identifiant interne des entrées ne l'est pas.
2. **Format** : JSON version 1 de la section « Format », entrées de la plus ancienne à la plus récente, `text` à `null` sans texte, libellé d'humeur ajouté pour une lecture sans l'app.
3. **Fichier non chiffré** : dit par une mention permanente sous le bouton, sans dialogue en plus ; fichier effacé à la fermeture de la feuille de partage, dossiers temporaires purgés au démarrage et avant chaque export.
4. **Journal vide** : export désactivé.
5. **Confirmation forte** : écrire « SUPPRIMER », sans tenir compte de la casse ni des espaces autour, sur un écran plein plutôt qu'un dialogue (lisible à 200 %).
6. **Ordre de la suppression** : marqueur `wipe-pending`, base, clé, modèle, fichiers temporaires ; la clé toujours après la base ; reprise au démarrage tant que le marqueur existe.
7. **Fin de la suppression** : retour à la liste vide, avec un message de fin, sans redémarrage de l'app.
8. **Clé introuvable** : la suppression totale est proposée sur l'écran d'erreur, jamais lancée d'elle-même ; rien n'est proposé pour les autres causes.
9. **Marqueur d'installation** : la clé restante n'est effacée que si aucune base n'existe, pour ne pas rendre illisible le journal d'une installation antérieure à cette spec.
10. **Couleur `danger`** : en texte et en bordure, jamais en fond plein (aucun jeton `on-danger` dans la charte).
11. **Nom du fichier** : avec l'heure (`AAAA-MM-JJ-HHMM`), pour que deux exports du même jour ne se remplacent pas chez le destinataire (revue IA de la PR #16).
12. **Octets du format** : échappement de `jsonEncode`, tri des étiquettes `emotion` puis `theme` et par unités de code UTF-16 (revue IA de la PR #16).
13. **Échec répété de la suppression** : pas de retour au journal ; la désinstallation est l'issue de secours (revue IA de la PR #16).
