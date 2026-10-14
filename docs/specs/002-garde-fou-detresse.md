# Spec 002 : garde-fou de détresse et écran d'aide

Statut : brouillon
Date : 2026-10-14

## Besoin

En tant que personne qui tient son journal, si j'écris des mots qui signalent un danger, ou si mes dernières humeurs sont toutes très basses, je veux voir aussitôt où trouver de l'aide humaine, sans que l'app me réponde avec un texte généré ni envoie mes mots au modèle.

Lot F du [plan](../plan.md). Règles du [cahier des charges](../cahier-des-charges-fonctionnel.md) appliquées : RM4, RM5, RM6, RM7, RM8, RM17, RM25, RM29. Maquette : voir « Maquette ».

Ce lot vient avant le lot G : aucune entrée n'est encore analysée. Il fixe ce qui sera vrai quand le modèle arrivera, c'est-à-dire qu'aucune entrée en détresse ne lui sera transmise.

## Écrans

- **Écran d'aide** (`HelpScreen`) : texte fixe, le 3114 appelable d'un geste, le 112 pour un danger immédiat, « Revenir à mon journal ». Il s'ouvre après l'enregistrement d'une entrée, à la place de la liste.
- **Réglages** : nouvel écran, ouvert par une icône « Réglages » en haut de la liste. Dans ce lot, il porte seulement la sensibilité aux humeurs basses. L'export et la suppression totale y viendront au lot H.
- **Liste des entrées** (spec 001) : ajout de l'icône « Réglages » à côté du titre.

## Règles de détection

### Texte (RM6)

1. Le texte est normalisé :
   - en minuscules ;
   - accents retirés (« é » devient « e ») ; « œ » devient « oe » et « æ » devient « ae » ;
   - tout caractère autre qu'une lettre ou un chiffre (apostrophe, ponctuation, émoji, retour à la ligne) devient une espace ;
   - les espaces successives sont réduites à une seule.
2. Il y a détresse si au moins une expression de la liste apparaît dans le texte normalisé comme une suite de **mots entiers**. Par exemple, « mourir » ne déclenche pas « mourire », mais « j'ai envie de mourir !! » déclenche « envie de mourir ».
3. La négation n'est pas prise en compte : « je ne veux pas mourir » déclenche aussi. C'est le choix du rappel maximal (Yanis, 2026-10-14) : une fausse alerte coûte peu, un oubli peut coûter cher.

Les expressions sont écrites sous leur forme normalisée.

### Liste des termes (à valider par Yanis)

Rédigée pour le projet. Le code reprend cette liste à l'identique ; un test le vérifie en relisant ce bloc (CA14).

```text
# Suicide et passage à l'acte
suicide
suicides
suicider
suicidee
suicidaire
suicidaires
me tuer
me supprimer
en finir
mettre fin a mes jours
mettre fin a ma vie
mettre un terme a ma vie
me foutre en l air
me jeter sous un train
me jeter par la fenetre
sauter par la fenetre
sauter d un pont
me pendre
me noyer
faire une overdose
avaler tous mes medicaments
prendre tous mes medicaments
avaler toute la boite
lettre d adieu
dire adieu a tout le monde
# Envie de mourir
envie de mourir
veux mourir
voudrais mourir
aimerais mourir
prefere mourir
prefererais mourir
plutot mourir
mieux mort
mieux morte
envie de crever
veux crever
jveux mourir
jveux crever
plus envie de vivre
pas envie de vivre
aucune envie de vivre
plus de raison de vivre
aucune raison de vivre
a quoi bon vivre
marre de vivre
fatigue de vivre
fatiguee de vivre
las de vivre
lasse de vivre
ne plus me reveiller
jamais me reveiller
disparaitre pour toujours
dormir pour toujours
# Se faire du mal
me faire du mal
me scarifier
scarifie
scarifiee
scarification
scarifications
me couper les veines
m ouvrir les veines
me taillader
me blesser expres
automutilation
auto mutilation
# Désespoir
mieux sans moi
personne ne me regretterait
personne ne me regrettera
je suis un fardeau
un poids pour tout le monde
aucune issue
plus aucune issue
```

Exclus volontairement, parce qu'ils sont trop fréquents dans un usage banal (« ce boulot me tue », « je suis mort de rire ») : « me tue », « mort », « mourir » seul. Ils sont à revoir avec Yanis si la liste lui semble trop courte.

### Série d'humeurs basses (RM25, RM29)

La personne choisit un degré de sensibilité dans les Réglages. Il en existe trois, et aucun ne désactive le garde-fou (RM29) :

| Degré | Nom dans le code | Déclenche quand les… | …toutes à 1 (« Très bas »), sur au plus |
| --- | --- | --- | --- |
| Haute | `high` | 2 dernières entrées | 3 jours |
| Normale (par défaut) | `normal` | 3 dernières entrées | 7 jours |
| Basse | `low` | 5 dernières entrées | 14 jours |

- « Les N dernières entrées » : les N entrées les plus récentes du journal, nouvelle entrée comprise, triées sur l'instant de saisie.
- « Sur au plus D jours » : au plus D × 24 heures entre la plus ancienne et la plus récente des N.
- Une seule entrée d'une autre humeur parmi les N casse la série. Avec moins de N entrées dans le journal, il n'y a pas de série.
- La série est évaluée après chaque enregistrement. Une nouvelle entrée à 1 qui prolonge la série déclenche donc de nouveau l'écran d'aide.
- Une entrée supprimée ne compte plus.

## Critères d'acceptation

### Détection à l'enregistrement

- CA1 : Étant donné un texte qui contient une expression de la liste, quand la personne enregistre l'entrée, alors l'entrée est enregistrée avec le statut « non analysée » (RM17) et l'écran d'aide s'affiche à la place de la liste.
- CA2 : Étant donné un texte qui contient une expression de la liste avec des majuscules, des accents, une apostrophe typographique, de la ponctuation ou des retours à la ligne (« J’ai ENVIE de… mourir. »), quand la personne enregistre, alors la détresse est détectée.
- CA3 : Étant donné un texte où une expression n'apparaît qu'à l'intérieur d'un mot plus long, quand la personne enregistre, alors la détresse n'est pas détectée.
- CA4 : Étant donné un texte sans aucune expression de la liste, quand la personne enregistre, alors l'entrée garde le statut « en attente » et la liste réapparaît, sauf si une série d'humeurs basses est atteinte (CA6).
- CA5 : Étant donné un texte avec une négation (« je ne veux pas mourir »), quand la personne enregistre, alors la détresse est détectée.
- CA6 : Étant donné le degré « Normale » et deux entrées à 1 dans les 7 derniers jours, quand la personne enregistre une troisième entrée à 1, avec ou sans texte, alors l'écran d'aide s'affiche ; le statut de l'entrée ne change pas pour autant : « en attente » avec un texte, « non analysée » sans texte.
- CA7 : Étant donné chacun des trois degrés, quand les N dernières entrées sont toutes à 1 et tiennent en D jours, alors l'écran d'aide s'affiche ; avec N − 1 entrées à 1, une entrée d'une autre humeur parmi les N, ou un écart de plus de D jours, il ne s'affiche pas.
- CA8 : Étant donné une entrée en détresse dans son texte qui complète aussi une série, quand elle est enregistrée, alors l'écran d'aide s'affiche une seule fois.
- CA9 : Étant donné un enregistrement qui échoue (spec 001, CA14), quand l'erreur survient, alors aucune détection n'a lieu et l'écran d'aide ne s'affiche pas.

### Écran d'aide

- CA10 : Étant donné l'écran d'aide, quand il s'affiche, alors il montre exactement les textes de la maquette : le titre « Parler peut aider », « Ton entrée est bien enregistrée… », le 3114 avec « Numéro national de prévention du suicide » et « Gratuit, 24 h/24, 7 j/7 », les boutons « Appeler le 3114 » et « Appeler le 112 », et « Revenir à mon journal ». Aucun texte ne vient du modèle ni ne dépend du contenu de l'entrée (RM7, RM4).
- CA11 : Étant donné l'écran d'aide, quand la personne touche « Appeler le 3114 » (ou « Appeler le 112 »), alors l'app ouvre le composeur du téléphone avec ce numéro (`tel:3114`, `tel:112`), sans l'appeler à sa place.
- CA12 : Étant donné un téléphone qui ne peut pas lancer d'appel (tablette, simulateur), quand la personne touche un des boutons d'appel, alors la mention « L'appel n'a pas pu être lancé » s'affiche, suivie de « Compose le numéro depuis ton téléphone : 3114, ou 112 en cas de danger immédiat. »
- CA13 : Étant donné l'écran d'aide, quand la personne touche « Revenir à mon journal » ou fait un geste de retour, alors la liste s'affiche avec la nouvelle entrée en tête ; l'écran de saisie ne réapparaît pas.

### Liste des termes

- CA14 : Étant donné la liste des termes de cette spec, quand les tests s'exécutent, alors la liste du code est identique au bloc « Liste des termes » de ce fichier (même ensemble d'expressions, lignes `#` et vides ignorées), et chaque expression de la liste, insérée dans une phrase fictive, est détectée.

### Entrées enregistrées avant ce lot (RM5)

- CA15 : Étant donné des entrées « en attente » avec un texte, quand l'app démarre, alors chacune passe par le détecteur ; celles en détresse prennent le statut « non analysée », les autres restent « en attente ». Aucun écran d'aide ne s'affiche au démarrage (Yanis, 2026-10-14).
- CA16 : Étant donné une erreur pendant cette vérification au démarrage, quand elle survient, alors l'app s'ouvre normalement sur la liste, et la vérification est refaite au démarrage suivant.

### Réglages

- CA17 : Étant donné la liste des entrées, quand la personne touche l'icône « Réglages », alors l'écran Réglages s'affiche ; l'icône s'annonce « Réglages » au lecteur d'écran.
- CA18 : Étant donné l'écran Réglages, quand il s'affiche, alors il montre la section « Écran d'aide », les trois degrés avec leur description, le degré choisi (« Normale (recommandée) » si la personne n'a rien choisi) et la mention « Ce réglage ne peut pas être désactivé… ».
- CA19 : Étant donné l'écran Réglages, quand la personne choisit un autre degré, alors il est enregistré aussitôt, sans bouton « Enregistrer », et s'applique à l'enregistrement suivant ; il est conservé après un redémarrage.
- CA20 : Étant donné un enregistrement du degré qui échoue, quand l'erreur survient, alors le bandeau « Le réglage n'a pas été enregistré » s'affiche avec « Le réglage précédent reste en place. Réessaie. », et le degré précédent reste coché.
- CA21 : Étant donné une lecture du degré qui échoue ou une valeur inconnue en base, quand une série est évaluée, alors le degré « Normale » s'applique : le garde-fou ne se désactive jamais sur une erreur.
- CA22 : Étant donné la lecture du degré en cours, quand l'écran Réglages s'affiche, alors seuls le retour « Journal » et le titre sont visibles.

### Accessibilité et thème

- CA23 : Étant donné l'écran d'aide, quand un lecteur d'écran le parcourt, alors le titre est annoncé en premier ; les boutons s'annoncent « Appeler le 3114 » et « Appeler le 112 » ; le numéro affiché s'annonce chiffre par chiffre (« 3 1 1 4 »).
- CA24 : Étant donné les degrés de l'écran Réglages, quand un lecteur d'écran les parcourt, alors chacun s'annonce comme un bouton radio avec son nom, sa description et son état (coché ou non).
- CA25 : Étant donné la taille de texte du système à 200 %, quand l'écran d'aide et l'écran Réglages s'affichent, alors aucun texte n'est tronqué ni ne déborde ; l'écran d'aide défile et ses boutons restent atteignables.
- CA26 : Étant donné le thème sombre du système, quand l'écran d'aide et l'écran Réglages s'affichent, alors ils utilisent les couleurs du thème sombre de la charte. L'écran d'aide n'utilise jamais la couleur `danger` (charte).

## Données

- **Détecteur** (`DistressDetector`) : code Dart pur, sans état ni accès à la base, testable sans Flutter.
  - `bool detectInText(String text)` : applique les règles du texte.
  - `bool detectLowMoodSeries(List<Entry> latest, LowMoodSensitivity sensitivity)` : `latest` contient les entrées les plus récentes, de la plus récente à la plus ancienne.
- **Sensibilité aux humeurs basses** (`LowMoodSensitivity`) : `high`, `normal`, `low`. Chacune porte son nombre d'entrées et sa durée.
- **Réglages** (`SettingsRepository`) : lecture (`watchLowMoodSensitivity`) et écriture (`setLowMoodSensitivity`) du degré.
  - Implémentation `DriftSettingsRepository`, sur une table `settings` de la base chiffrée : une ligne, avec le degré stocké par son nom ; schéma passé en version 2 par une migration.
  - `FakeSettingsRepository` dans `test/support/`.
  - Le degré est effacé avec la base à la suppression totale (lot H).
- **Dépôt des entrées** (`EntryRepository`) :
  - `addEntry` reçoit le statut décidé par l'appelant (`pending` ou `skipped`) au lieu de le déduire du texte seul ;
  - nouvelles opérations `latestEntries(int count)` et `pendingEntriesWithText()` ;
  - nouvelle opération `markSkipped(Iterable<int> ids)`, pour la vérification au démarrage.
- **Appel** : le paquet `url_launcher` ouvre `tel:3114` et `tel:112`. Il n'envoie aucune donnée et n'ouvre aucune connexion réseau (RM1). Dépendance justifiée dans la PR.

## Maquette

Artefact Claude de type « Design » ([lien privé](https://claude.ai/artifact/Pc9xuXHEV16GeFgqNwqSFB)), construit sur la charte. La copie versionnée, qui fait foi, est dans [`docs/maquettes/002-garde-fou-detresse/`](../maquettes/002-garde-fou-detresse/).

Écrans :

- **Écran d'aide** : nominal et « appel impossible », en clair et en sombre.
- **Réglages** : nominal en clair et en sombre, chargement, erreur en clair et en sombre.
- **Liste** : avec l'icône « Réglages », en clair et en sombre.

Il n'y a ni état vide ni chargement pour l'écran d'aide : son contenu est fixe, sans lecture.

## Cas limites et erreurs

- Texte qui ne contient qu'un émoji ou de la ponctuation : la normalisation donne une chaîne vide, et la détresse n'est pas détectée par le texte. La série reste évaluée.
- Expression coupée par un retour à la ligne (« envie de\nmourir ») : détectée, puisque le retour à la ligne devient une espace.
- Changement de degré entre deux entrées : le nouveau degré s'applique à la série entière, entrées anciennes comprises.
- Deux entrées enregistrées à la même seconde : l'ordre suit l'identifiant, comme dans la liste (spec 001).
- Composeur absent (iPad sans téléphonie, simulateur) : CA12.
- Retour à l'app après un appel : l'écran d'aide est toujours affiché, et rien n'a changé.

## Hors périmètre

- Classifieur de détresse (décision de Yanis du 2026-10-14, [plan](../plan.md#décisions)).
- Accès permanent à l'écran d'aide hors détection : non retenu (Yanis, 2026-10-14).
- Analyse des entrées par le modèle (lot G). Le lot G ne transmet au modèle que des entrées « en attente », toutes passées par le détecteur, soit à l'enregistrement (CA1), soit au démarrage (CA15).
- Numéros d'aide hors de France, autres langues que le français (RM22).
- Export et suppression totale dans les Réglages (lot H).

## Questions ouvertes

1. **Liste des termes** : à valider par Yanis, avec les exclusions (« me tue », « mort »).
2. **Degrés de sensibilité** : valeurs du tableau proposées par l'agent, à valider par Yanis, comme la règle « aucun degré ne désactive le garde-fou » (RM29).
3. **Texte de l'écran d'aide** : le titre « Parler peut aider » et la phrase d'accueil sont proposés par l'agent, à valider par Yanis.
