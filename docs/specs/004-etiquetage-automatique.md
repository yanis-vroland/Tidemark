# Spec 004 : étiquetage automatique

Statut : validée (Yanis, merge de la PR #18, 2026-10-14 ; décisions métier déléguées à l'agent)
Date : 2026-10-14

## Besoin

En tant que personne qui tient son journal, je veux que mes entrées reçoivent d'elles-mêmes quelques étiquettes d'émotions et de thèmes, proposées par un modèle qui tourne sur mon téléphone, afin de repérer ce qui revient dans mes journées sans rien envoyer hors de mon téléphone.

Second volet du lot G du [plan](../plan.md) (branche `feat/etiquetage`), après le téléchargement du modèle ([spec 003](003-telechargement-du-modele.md)). Règles du [cahier des charges](../cahier-des-charges-fonctionnel.md) appliquées : RM1, RM4, RM5, RM8, RM9, RM17, RM19, RM22, RM24, RM33, RM34, RM35, RM36. Moteur, modèle et schéma : [ADR-001](../adr/001-moteur-ia-local.md). Maquette : voir « Maquette ».

Prérequis : le garde-fou de détresse ([spec 002](002-garde-fou-detresse.md), `DistressDetector` dans `lib/distress/distress_detector.dart`, PR #19) est implémenté et mergé avant ce volet. Aucune entrée en détresse n'atteint le modèle (RM8), quoi qu'il arrive au démarrage.

## Écrans

- **Liste des entrées** (spec 001) : la carte d'une entrée étiquetée montre ses puces d'étiquette (`TagChip`) sous le texte ; la carte de l'entrée en cours d'analyse montre « Analyse en cours sur ton téléphone… » (`LoadingNote`).
- **Détail d'une entrée** (spec 001) : section « Étiquettes », avec les émotions et les thèmes, et la mention « Analysé sur ton téléphone » ; ou l'état de l'analyse (en cours, en attente, modèle absent, modèle impossible à charger, aucune étiquette).

Aucun nouvel écran.

## Règles

### Liste fermée des étiquettes (RM19, RM22, RM33)

Reprise du vocabulaire du spike (`docs/adr/001-mesures/entrees-fictives.json`), en français, en minuscules, avec accents. Le code reprend cette liste à l'identique ; un test le vérifie en relisant ce bloc (CA1).

Le format du bloc est un contrat lu par ce test : un bloc `text`, juste sous ce titre ; une ligne `# Émotions`, puis une étiquette par ligne ; une ligne `# Thèmes`, puis une étiquette par ligne ; ni ligne vide, ni commentaire, ni espace en fin de ligne. Toute retouche de forme passe par la mise à jour du test.

```text
# Émotions
joie
calme
gratitude
fierté
espoir
tristesse
anxiété
colère
fatigue
solitude
frustration
ennui
# Thèmes
travail
études
famille
amis
couple
santé
sommeil
sport
nature
argent
maison
loisirs
```

Aucune étiquette ne nomme un trouble ou un diagnostic (RM4) : ni « dépression », ni « burn-out », ni « crise ». Par entrée : **0 à 3 émotions, 0 à 2 thèmes, au moins une étiquette en tout**. Une entrée peut ne recevoir aucune émotion : forcer une émotion pousserait le modèle à en inventer une, ce qui serait un jugement.

### Ce qui est envoyé au modèle (RM1, RM36)

- Seul le **texte** de l'entrée, tel qu'il est enregistré. Ni l'humeur, ni la date, ni une autre entrée.
- Consigne fixe, en français, dans le code (`lib/analysis/`) : « Tu étiquettes une entrée de journal d'humeur écrite en français. Choisis de 0 à 3 émotions et de 0 à 2 thèmes, uniquement dans les listes autorisées, et au moins une étiquette en tout. Ne donne aucun conseil. Réponds seulement par l'objet JSON demandé. » Le texte de l'entrée est le message de l'utilisateur.
- Paramètres de l'ADR-001 : température 0,2, sortie limitée à 128 jetons, sortie contrainte par le schéma ci-dessous ; accélération GPU sur iOS, processeur seul sur Android.

### Schéma de sortie

Passé au moteur (`llamadart`) pour contraindre la sortie, puis revérifié par l'app : la contrainte du moteur n'est pas une garantie (RM9).

Écart avec le spike : le schéma exact du spike n'est pas versionné dans `docs/adr/001-mesures/`, et les bornes `minItems` et `maxItems` et la règle « au moins une étiquette » sont propres à cette spec. Au test humain, les 20 entrées fictives du spike sont étiquetées de nouveau sur l'iPhone 15 Pro avec ce schéma ; le taux de JSON valide et le rappel sont consignés dans la PR d'implémentation, à côté de ceux de l'ADR-001 (20/20, 0,51).

```json
{
  "type": "object",
  "properties": {
    "emotions": {
      "type": "array",
      "items": { "enum": ["joie", "calme", "gratitude", "fierté", "espoir", "tristesse", "anxiété", "colère", "fatigue", "solitude", "frustration", "ennui"] },
      "minItems": 0,
      "maxItems": 3
    },
    "themes": {
      "type": "array",
      "items": { "enum": ["travail", "études", "famille", "amis", "couple", "santé", "sommeil", "sport", "nature", "argent", "maison", "loisirs"] },
      "minItems": 0,
      "maxItems": 2
    }
  },
  "required": ["emotions", "themes"],
  "additionalProperties": false
}
```

Les listes `enum` du schéma sont générées depuis la liste fermée, jamais recopiées à la main.

### Validation de la sortie (RM9)

`TagOutputParser.parse(String raw)` rend `Tagged` ou `Untagged`, sans jamais lever d'exception. La sortie est **conforme** si, et seulement si :

1. après suppression des espaces en début et en fin, c'est un objet JSON, seul (aucun texte avant ou après) ;
2. il a exactement les clés `emotions` et `themes`, chacune un tableau de chaînes ;
3. chaque chaîne est une étiquette de la liste de son type, à l'identique (casse et accents compris : « Joie » ou « anxiete » ne sont pas conformes) ;
4. après suppression des doublons (le premier est gardé), il y a au plus 3 émotions, au plus 2 thèmes, et au moins une étiquette en tout.

Conforme : `Tagged`, avec les émotions puis les thèmes, dans l'ordre de la sortie. Sinon : `Untagged`. La sortie brute n'est jamais enregistrée, affichée ni journalisée.

### File d'analyse (RM34, RM35)

- **Quelles entrées** : seulement celles au statut « en attente » (`pending`), qui ont toutes un texte (spec 001). Une entrée « étiquetée », « sans étiquette » ou « non analysée » n'est jamais analysée, ni de nouveau, ni à la demande.
- **Quand** : la file (`AnalysisQueue`) se lance quand le modèle est `ready` (spec 003) : au démarrage, après la vérification des entrées en attente par le détecteur de détresse (spec 002, CA15), réussie ou non ; après chaque enregistrement d'une entrée « en attente » ; dès que le téléchargement du modèle se termine. Rien ne se lance si le modèle est `absent` ou `downloading` : les entrées restent « en attente ».
- **Ordre** : une entrée à la fois, la plus récente d'abord (celle que la personne vient d'écrire est étiquetée la première). Jamais deux analyses en même temps.
- **Défense en profondeur** (spec 002) : juste avant chaque analyse, `DistressDetector.detectInText` (`lib/distress/distress_detector.dart`) est appliqué au texte. Détresse détectée : l'entrée passe en « non analysée » (`skipped`), le modèle n'est pas appelé, aucun écran d'aide ne s'affiche (comme pour la vérification au démarrage, spec 002 CA15).
- **Chargement du modèle** : `MoodAnalyzer.prepare()` charge le modèle avant la première analyse de la file. S'il ne peut pas être chargé (fichier altéré, mémoire), aucune entrée ne change de statut et la file appelle `ModelDownloader.verifyAfterLoadFailure()` (spec 003, CA32) : empreinte fausse → fichier effacé, modèle `absent`, et la personne peut le retélécharger (CA23) ; empreinte juste → la file passe à l'état « indisponible » jusqu'au démarrage suivant, et le détail le dit (CA31). Le modèle est libéré quand la file est vide, pour rendre la mémoire au téléphone (1,3 Go, ADR-001).
- **Résultat** : `Tagged` → les étiquettes et le statut « étiquetée » sont enregistrés ensemble, dans une transaction ; `Untagged` → statut « sans étiquette », aucune étiquette. Une analyse qui dure plus de 30 s vaut `Untagged`.
- **Délai** : c'est la file qui mesure les 30 s. Au-delà, elle appelle `MoodAnalyzer.cancel()` et attend sa fin avant de passer à l'entrée suivante : la génération native est arrêtée (annulation de `llamadart` si elle existe, sinon `release()` du modèle, qui sera rechargé par `prepare()`). Un simple délai côté Dart ne suffit pas : il laisserait le moteur générer pendant l'analyse suivante.
- **Interruption** : le statut n'est écrit qu'avec le résultat. Une analyse interrompue (app fermée, mise en arrière-plan) laisse l'entrée « en attente », reprise au prochain lancement de la file.

## Critères d'acceptation

### Liste fermée et validation

- CA1 : Étant donné la liste fermée de cette spec, quand les tests s'exécutent, alors les listes d'émotions et de thèmes du code sont identiques aux sections `# Émotions` et `# Thèmes` du bloc « Liste fermée des étiquettes » de ce fichier (mêmes étiquettes, même ordre), et les listes `enum` du schéma passé au moteur en sont tirées ; un bloc qui ne respecte pas son format fait échouer le test avec un message qui le dit.
- CA2 : Étant donné une sortie conforme (`{"emotions": ["fatigue", "calme"], "themes": ["travail"]}`), quand elle est validée, alors le résultat est `Tagged` avec `fatigue` et `calme` (émotions) puis `travail` (thème), dans cet ordre.
- CA3 : Étant donné chacune des sorties suivantes, quand elle est validée, alors le résultat est `Untagged`, sans exception : chaîne vide ; texte qui n'est pas du JSON ; JSON tronqué ; tableau au lieu d'un objet ; clé `emotions` ou `themes` absente ; clé en plus ; valeur qui n'est pas un tableau ; élément qui n'est pas une chaîne ; étiquette hors liste ; étiquette de la liste dans le mauvais tableau (`"themes": ["joie"]`) ; variante de casse ou d'accent (« Joie », « anxiete ») ; 4 émotions ; 3 thèmes ; aucune étiquette en tout ; texte avant ou après l'objet.
- CA4 : Étant donné une sortie avec des doublons (`["joie", "joie", "calme"]`) ou des espaces autour de l'objet, quand elle est validée, alors les doublons sont retirés et les espaces ignorés avant les contrôles : le résultat est `Tagged` (`joie`, `calme`).
- CA5 : Étant donné une sortie avec 0 émotion et 1 thème, quand elle est validée, alors le résultat est `Tagged` avec ce seul thème.

### File d'analyse

- CA6 : Étant donné le modèle `ready` et trois entrées « en attente », quand l'app démarre, alors, après la vérification de détresse au démarrage, les trois sont analysées une à la fois, de la plus récente à la plus ancienne, et chacune prend le statut de son résultat.
- CA7 : Étant donné une entrée « en attente » dont le texte contient une expression de la liste de détresse (entrée antérieure au lot F, ou vérification au démarrage échouée ou pas encore faite), quand la file l'atteint, alors elle passe en « non analysée », le modèle ne reçoit pas son texte (`FakeMoodAnalyzer.received` ne le contient pas) et aucun écran d'aide ne s'affiche ; la file continue avec l'entrée suivante.
- CA8 : Étant donné une analyse qui rend `Tagged`, quand le résultat est enregistré, alors les étiquettes et le statut « étiquetée » sont écrits dans la même transaction ; si l'écriture échoue, l'entrée reste « en attente », sans étiquette partielle.
- CA9 : Étant donné une analyse qui rend `Untagged`, ou qui dure plus de 30 s, quand elle se termine (ou que `cancel()` a rendu la main), alors l'entrée prend le statut « sans étiquette », sans aucune étiquette, et la file passe à l'entrée suivante.
- CA10 : Étant donné une entrée analysée, quand le modèle est appelé, alors il reçoit exactement le texte de l'entrée, et rien d'autre (ni humeur ni date).
- CA11 : Étant donné des entrées « étiquetée », « sans étiquette » et « non analysée », quand la file tourne, au démarrage ou après un enregistrement, alors aucune n'est transmise au modèle.
- CA12 : Étant donné le modèle `absent` ou `downloading`, quand l'app démarre ou que la personne enregistre une entrée « en attente », alors aucune analyse n'a lieu et l'entrée reste « en attente » ; quand le modèle passe à `ready`, alors la file se lance sans redémarrage de l'app.
- CA13 : Étant donné le modèle `ready`, quand la personne enregistre une entrée « en attente », alors elle est analysée, avant les entrées « en attente » plus anciennes qui restent dans la file.
- CA14 : Étant donné une analyse en cours, quand la personne enregistre une autre entrée, alors la nouvelle entrée rejoint la file : il n'y a jamais deux appels à `analyze` en même temps. Avec un analyseur factice qui ne se termine jamais de lui-même, après 30 s, la file appelle `cancel()`, attend qu'il rende la main, puis seulement appelle `analyze` pour l'entrée suivante.
- CA15 : Étant donné un modèle qui ne peut pas être chargé (`prepare()` rend `false`), quand la file se lance, alors aucune entrée ne change de statut, `analyze` n'est pas appelé, et `verifyAfterLoadFailure()` est appelé une fois ; si le modèle repasse à `absent`, la file attend un nouveau téléchargement (CA12) ; sinon, elle ne se relance qu'au démarrage suivant.
- CA16 : Étant donné une entrée supprimée pendant son analyse, quand le résultat arrive, alors il est ignoré, sans erreur, et aucune étiquette ne reste dans la base.

### Stockage

- CA17 : Étant donné une entrée étiquetée, quand elle est supprimée, alors ses étiquettes sont supprimées avec elle, par la clé étrangère `ON DELETE CASCADE` (RM15) ; un test vérifie que les clés étrangères sont actives sur la base chiffrée (`PRAGMA foreign_keys` vaut 1).
- CA18 : Étant donné des entrées étiquetées, quand l'app est fermée puis relancée, alors chaque entrée a les mêmes étiquettes, dans le même ordre ; la liste et le détail se mettent à jour dès qu'une analyse se termine, sans action de la personne.

### Affichage

- CA19 : Étant donné une entrée « étiquetée », quand sa carte s'affiche dans la liste, alors elle montre ses puces sous le texte, émotions puis thèmes, sans la mention « Analysé sur ton téléphone ».
- CA20 : Étant donné l'entrée en cours d'analyse, quand sa carte s'affiche, alors elle montre « Analyse en cours sur ton téléphone… » à la place des puces ; les autres cartes d'entrées « en attente », « sans étiquette » ou « non analysée » ne montrent ni puce ni mention.
- CA21 : Étant donné le détail d'une entrée « étiquetée », quand il s'affiche, alors il montre, sous le texte, la section « Étiquettes » avec la ligne « Émotions » et ses puces, la ligne « Thèmes » et ses puces (une ligne sans étiquette n'est pas affichée), puis « Analysé sur ton téléphone ».
- CA22 : Étant donné le détail d'une entrée « en attente » et le modèle `ready`, quand il s'affiche, alors la section « Étiquettes » montre « Analyse en cours sur ton téléphone… » seulement si cette entrée est celle que la file analyse ; si elle attend son tour, elle montre « En attente d'analyse sur ton téléphone. », sans indicateur.
- CA31 : Étant donné la file « indisponible » (CA15, empreinte juste) et une entrée « en attente », quand son détail s'affiche, alors la section « Étiquettes » montre « Pas encore analysée : le modèle n'a pas pu être chargé. Nouvel essai au prochain lancement de Tidemark. », sans bouton.
- CA23 : Étant donné le détail d'une entrée « en attente » et le modèle `absent`, quand il s'affiche, alors la section « Étiquettes » montre « Pas encore analysée : le modèle d'analyse n'est pas sur ton téléphone. » et le bouton « Télécharger le modèle (1,1 Go) », qui ouvre l'écran du modèle sur la proposition (spec 003). Avec le modèle `downloading`, elle montre « Pas encore analysée : le modèle est en cours de téléchargement. », sans bouton.
- CA24 : Étant donné le détail d'une entrée « sans étiquette », quand il s'affiche, alors la section « Étiquettes » montre seulement « Aucune étiquette n'a été proposée pour cette entrée. », en `ink-muted`, sans couleur `danger` ni sortie du modèle.
- CA25 : Étant donné le détail d'une entrée « non analysée » (sans texte ou en détresse), quand il s'affiche, alors il n'a pas de section « Étiquettes » ni aucune mention de l'analyse : rien n'y signale une détection de détresse.
- CA26 : Étant donné des puces d'étiquette, quand la personne les touche, alors rien ne se passe : elles ne sont ni cliquables ni modifiables (RM19), et toutes ont la même couleur (`tide-soft`), quelle que soit l'émotion.

### Accessibilité et thème

- CA27 : Étant donné une carte d'entrée étiquetée, quand un lecteur d'écran la parcourt, alors son libellé (spec 001, CA36) se termine par « étiquettes : fatigue, calme, travail ».
- CA28 : Étant donné la section « Étiquettes » du détail, quand un lecteur d'écran la parcourt, alors chaque ligne s'annonce « Émotions : fatigue, calme » et « Thèmes : travail » ; « Analyse en cours sur ton téléphone… » s'annonce comme un statut, et un changement de statut de l'analyse est annoncé.
- CA29 : Étant donné la taille de texte du système à 200 %, quand la liste et le détail montrent des étiquettes, alors les puces passent à la ligne, sans texte tronqué ni débordement.
- CA30 : Étant donné le thème sombre du système, quand la liste et le détail montrent des étiquettes ou l'état de l'analyse, alors ils utilisent les couleurs du thème sombre de la charte.

## Données

Fixées par cette spec, puis reportées dans l'architecture technique avec l'implémentation.

- **Liste fermée** (`TagVocabulary`, `lib/analysis/tag_vocabulary.dart`) : les deux listes, et le schéma JSON qui en est tiré.
- **Validation** (`TagOutputParser`, `lib/analysis/`) : code Dart pur, sans Flutter, testé sur des chaînes (CA2 à CA5).
- **Analyseur** (`MoodAnalyzer`, contrat changé) :
  - nouvelles méthodes `Future<bool> prepare()`, qui charge le modèle et rend `false` s'il ne peut pas l'être ; `Future<void> release()`, qui le libère ; `Future<void> cancel()`, qui arrête la génération en cours et ne rend la main qu'une fois le moteur libre ;
  - `analyze(String text)` rend toujours `Tagged` ou `Untagged`, jamais d'exception ; le délai de 30 s est tenu par la file, pas par l'analyseur ;
  - implémentation `LlamaMoodAnalyzer` sur `llamadart` 0.12.0 (ADR-001) : consigne, schéma, appel du moteur, `TagOutputParser`. Elle n'est **jamais exécutée par les tests ni par la CI** (aucun modèle) : elle est vérifiée au test humain, sur l'iPhone 15 Pro et l'émulateur Android ;
  - `FakeMoodAnalyzer` (`test/support/`) gagne le résultat de `prepare()`, un délai réglable par texte (dont « jamais »), `cancel()` qui termine l'analyse en cours, et un compteur d'appels simultanés (CA14).
- **File d'analyse** (`AnalysisQueue`, `lib/analysis/`) : reçoit `EntryRepository`, `MoodAnalyzer`, `DistressDetector` et l'état du modèle (`ModelDownloader.watch()`, spec 003) ; expose l'identifiant de l'entrée en cours d'analyse (CA20, CA22) et son état (`idle`, `running`, `unavailable`, CA31).
- **Entrée** (`Entry`) : gagne la liste de ses étiquettes (`tags`, vide si aucune), dans l'ordre enregistré.
- **Dépôt des entrées** (`EntryRepository`) : `pendingEntriesWithText()` et `markSkipped(Iterable<int> ids)` existent déjà (spec 002, PR #19) : la file trie elle-même les entrées en attente de la plus récente à la plus ancienne ; nouvelle opération `saveAnalysis(int entryId, AnalysisResult result)` (transaction, CA8 ; sans effet si l'entrée n'existe plus, CA16). `addEntry` reçoit le statut de l'appelant (spec 002).
- **Table des étiquettes** (`tags`) : `id` (clé primaire), `entry_id` (clé étrangère vers `entries.id`, `ON DELETE CASCADE`), `label` (texte, de la liste fermée), `kind` (`emotion` ou `theme`), `position` (ordre d'affichage) ; unicité de (`entry_id`, `label`). Créée par une migration (version suivante du schéma). `PRAGMA foreign_keys = ON` à chaque ouverture de la base, sans quoi SQLite ignore la cascade.
- Les étiquettes sont exportées avec les entrées (RM20, lot H) et effacées avec la base (RM12).

## Maquette

Artefact Claude de type « Design » ([lien privé](https://claude.ai/artifact/QVMphoCa1umzrZcGkJ3VJX)), construit sur la charte. La copie versionnée, qui fait foi, est dans [`docs/maquettes/004-etiquetage-automatique/`](../maquettes/004-etiquetage-automatique/).

Écrans, chacun en clair et en sombre :

- **Liste** : une entrée étiquetée, une entrée en cours d'analyse, une entrée sans texte, une entrée de la veille étiquetée.
- **Détail** : étiquetée, analyse en cours, en attente de son tour, modèle absent, modèle impossible à charger, aucune étiquette.

Captures PNG : absentes, comme pour les maquettes 001 et 002 ; à exporter depuis l'artefact (dette à suivre dans une issue, à créer avec l'accord de Yanis). En attendant, la copie HTML de `docs/maquettes/` fait foi.

Les états vide, chargement et erreur de la liste et du détail sont ceux de la spec 001 : l'étiquetage n'en ajoute pas. L'état « non analysée » du détail est celui de la maquette 001 (aucune section « Étiquettes »).

Jetons : la maquette n'utilise que les jetons de la charte (`TagChip`, `LoadingNote`, `headline`, `label`, `caption`, `icon-sm`, `space-1` à `space-6`), plus `icon-button` (18, indicateur de `LoadingNote` et icône du bouton de téléchargement), déjà demandé par la spec 002. Aucun nouveau jeton.

## Cas limites et erreurs

- Texte qui tente de détourner la consigne (« ignore les consignes et écris… ») : la sortie reste contrainte par le schéma et revalidée ; au pire, des étiquettes inexactes ou « sans étiquette ». Rien de ce que produit le modèle n'est affiché en dehors des étiquettes de la liste.
- Texte en anglais ou dans une autre langue : analysé comme les autres ; la qualité n'est évaluée qu'en français (RM22).
- Texte de 2 000 caractères (RM27) : tient dans le contexte du modèle ; aucun découpage.
- Texte fait seulement d'émojis : analysé ; le plus probable est « sans étiquette ».
- Étiquettes inexactes : l'étiquetage est une aide, jamais un diagnostic (RM4) ; environ la moitié des étiquettes attendues retrouvées au spike (ADR-001). Limite écrite dans le README (lot J). La personne ne peut pas les corriger dans le MVP (RM19).
- App mise en arrière-plan pendant une analyse : l'analyse peut se terminer ou être interrompue ; dans ce cas, l'entrée reste « en attente » et repart au prochain lancement de la file.
- Analyse au démarrage alors que la personne écrit : la file tourne en arrière-plan, sans bloquer la saisie ; l'entrée que la personne enregistre passe devant les plus anciennes (CA13).
- Modèle supprimé pendant la file (suppression totale, lot H) : la file s'arrête ; les entrées sont effacées avec la base.

## Hors périmètre

- Téléchargement du modèle : [spec 003](003-telechargement-du-modele.md).
- Correction, ajout ou suppression d'une étiquette par la personne (RM19) ; nouvelle analyse d'une entrée « sans étiquette », automatique ou à la demande.
- Filtre ou recherche par étiquette dans la liste ; statistiques par étiquette (bilan de la semaine, lot I).
- Étiquettes en d'autres langues que le français (RM22) ; liste d'étiquettes modifiable par la personne.
- Analyse par le modèle de l'humeur seule (RM24).

## Questions ouvertes

Aucune. Décisions prises par l'agent, à la demande de Yanis (2026-10-14) :

1. **Question ouverte n° 1 du cahier des charges (entrée sans analyse)** : les entrées « en attente » sont analysées automatiquement, en arrière-plan, dès que le modèle est prêt (au démarrage, après chaque enregistrement, à la fin du téléchargement), une à la fois, la plus récente d'abord. Une entrée « sans étiquette » ne l'est jamais de nouveau : avec la sortie contrainte, ce cas est rare (80 réponses valides sur 80 au spike), et une nouvelle analyse donnerait le plus souvent le même résultat. Un modèle impossible à charger laisse les entrées « en attente » (RM34).
2. **Liste fermée** : le vocabulaire du spike, sans changement (12 émotions, 12 thèmes), qui ne nomme aucun trouble.
3. **0 à 3 émotions, 0 à 2 thèmes, au moins une étiquette** : pas d'émotion forcée.
4. **Seul le texte est envoyé au modèle**, pas l'humeur : moins de données transmises, et le comportement reste celui mesuré au spike.
5. **Doublons retirés** avant validation, plutôt que de rejeter la sortie : le moteur ne garantit pas l'unicité.
6. **Rien n'est affiché pour une entrée « non analysée »** : aucune mention qui trahirait une détection de détresse.
7. **Délai de 30 s par analyse** (0,8 s mesurés sur iPhone, ADR-001) : au-delà, la génération est annulée, puis « sans étiquette ».
8. **Modèle libéré quand la file est vide** : 1,3 Go rendus au téléphone, au prix d'un rechargement (0,3 s modèle en cache, 12 s à froid) à la prochaine analyse.
9. **Après la revue IA de la PR #18** : détail « En attente d'analyse » distinct de « Analyse en cours » (CA22) ; modèle impossible à charger → empreinte recalculée, puis retéléchargement possible ou état « indisponible » affiché (CA15, CA31) ; annulation de la génération sur dépassement du délai (CA14).
