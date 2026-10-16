# Spec 006 : bilan de la semaine

Statut : validée (Yanis, merge de la PR #17, 2026-10-14 ; décisions métier déléguées à l'agent)
Date : 2026-10-14

## Besoin

En tant que personne qui tient son journal, je veux voir en un coup d'œil comment s'est passée ma semaine (combien d'entrées, quelle humeur, quels jours, quels thèmes) et en lire un court résumé, afin d'en comprendre la tendance sans qu'aucune donnée ne quitte mon téléphone.

Lot I du [plan](../plan.md) (« si le temps le permet »). Règles du [cahier des charges](../cahier-des-charges-fonctionnel.md) appliquées : RM1, RM4, RM7, RM8, RM10, RM21, RM22, RM50 à RM55. Moteur : [ADR-001](../adr/001-moteur-ia-local.md). Maquette : voir « Maquette ».

Le principe : **l'app calcule, le modèle met en mots.** Tous les chiffres sont calculés en Dart (RM10). Le modèle local reçoit seulement des faits sans chiffre, jamais une entrée, et rend une ou deux phrases que l'app valide par des règles déterministes avant de les montrer. Sans modèle, sans texte valide, ou pour une semaine sensible, le bilan s'affiche avec ses seuls chiffres.

Dépendances : la spec 001 (entrées, jour local) et la spec 002 (`DistressDetector`) sont validées. Les étiquettes et l'état du modèle viennent du lot G (spec 004, étiquetage automatique, et la spec du téléchargement du modèle) : tant que le lot G n'est pas livré, le bilan s'affiche sans étiquettes (CA13) et sans texte (CA27).

Exigence pour la spec 004, étiquetage automatique : aucun libellé de la liste fermée des étiquettes (RM19) ne figure dans les listes de rejet de cette spec (« Liste des mots de nombre », « Liste des expressions interdites »), vérifié par un test. Sinon, toute semaine où cette étiquette domine verrait son texte rejeté.

## Écrans

- **Bilan de la semaine** (`WeeklyReviewScreen`) : nouvel écran, ouvert depuis la liste. Retour « Journal », titre « Ta semaine », semaine affichée avec les flèches « Semaine précédente » et « Semaine suivante », puis, de haut en bas : le texte du bilan, les chiffres clés (entrées, humeur moyenne), l'évolution par rapport à la semaine précédente, la répartition des humeurs, les jours notés, les étiquettes fréquentes. L'écran défile.
- **Liste des entrées** (spec 001) : ajout d'une carte « Bilan de la semaine » en tête, sous le titre.

## Règles de calcul (RM10, RM21, RM50)

- **Semaine** : du lundi 00:00 au dimanche 23:59, en jours locaux. Une entrée compte dans la semaine de son jour local de saisie (décalage enregistré, spec 001), pas du jour local actuel.
- **Entrées comptées** : toutes les entrées de la semaine, quel que soit leur statut d'analyse (en attente, étiquetée, sans étiquette, non analysée). Une entrée supprimée ne compte plus.
- **Seuil** : moins de 3 entrées dans la semaine, pas de bilan (RM21) : ni chiffre, ni texte, ni appel au modèle.
- **Humeur moyenne** : moyenne arithmétique des humeurs des entrées (pas des jours), arrondie au dixième le plus proche, la moitié vers le haut. Calcul en entiers, sans virgule flottante : dixièmes = (20 × somme + nombre) ÷ (2 × nombre), division entière. Affichage avec une virgule (« 3,6 »).
- **Répartition** : nombre d'entrées pour chaque humeur de 1 à 5, zéros compris.
- **Jours notés** : nombre de jours de la semaine avec au moins une entrée (de 1 à 7), et lesquels. Singulier pour un seul jour : « 1 jour sur 7 », « sur 1 jour ».
- **Étiquettes fréquentes** : au plus 3 étiquettes, comptées par nombre d'entrées « étiquetées » qui les portent, triées par nombre décroissant, puis par libellé dans l'ordre alphabétique. Émotions et thèmes sont mêlés.
- **Évolution** : seulement si la semaine précédente compte au moins 3 entrées. Elle compare les moyennes arrondies au dixième (« 3,6, contre 3,0 ») et le nombre d'entrées. Différence des moyennes arrondies : positive, « En hausse de 0,6. » ; négative, « En baisse de 0,6. » ; nulle, « Stable. ».
- **Semaines consultables** : la semaine en cours et chaque semaine précédente, jusqu'à celle de l'entrée la plus ancienne du journal.

## Mise en mots (RM51 à RM54)

### Semaine sensible (RM52)

Une semaine est **sensible** si au moins une de ses entrées :

1. a l'humeur 1 (« Très bas ») ;
2. a un texte et le statut « non analysée » : avec un texte, ce statut ne vient que de la détresse (RM17, RM24) ;
3. a un texte détecté par `DistressDetector.detectInText`, vérifié de nouveau au calcul du bilan (défense en profondeur, comme au lot G).

Le critère 1 couvre toute série d'humeurs très basses (spec 002), qui n'est faite que d'entrées à 1, sans avoir à recalculer la série avec la sensibilité choisie. Pour une semaine sensible, le modèle n'est pas appelé : le bilan s'en tient aux chiffres, avec le même message que pour une sortie rejetée. L'écran ne mentionne ni la détresse ni l'écran d'aide : la spec 002 a écarté tout accès à l'écran d'aide hors détection, et le bilan ne déclenche pas de détection.

### Ce que reçoit le modèle (RM51)

Le rédacteur du bilan (`ReviewWriter`) reçoit seulement les faits du bilan (`ReviewFacts`), calculés par l'app, **sans aucun chiffre** :

| Fait | Nom dans le code | Valeurs |
| --- | --- | --- |
| Humeur moyenne, en mots | `averageMoodLabel` | Libellé de RM3 de la moyenne **exacte** arrondie à l'unité, la moitié vers le haut, en entiers : unité = (2 × somme + nombre) ÷ (2 × nombre), division entière (3,6 → « Bien »). Jamais depuis les dixièmes déjà arrondis : 11 entrées de somme 38 (3,4545…, affichée « 3,5 ») donnent « Neutre » (CA35) |
| Régularité | `regularity` (`WeekRegularity`) | `everyDay` (7 jours notés), `mostDays` (5 ou 6), `someDays` (3 ou 4), `fewDays` (1 ou 2) |
| Étiquettes fréquentes | `topTagLabels` | Libellés de la liste fermée (RM19), au plus 3, dans l'ordre des chiffres |
| Tendance | `trend` (`ReviewTrend`) | Signe de la différence des moyennes arrondies au dixième, comme l'évolution affichée (CA14) : `up`, `down`, `stable` ; `none` sans semaine précédente comparable |

Jamais le texte, la date, l'heure ni l'humeur d'une entrée : aucune entrée n'est transmise au modèle, et RM8 tient pour le bilan quoi qu'il arrive. Pas de chiffre en entrée, pour ne pas en suggérer en sortie.

Le modèle reçoit des consignes fixes, en français (RM22) : une ou deux phrases, tutoiement, ton descriptif et calme, décrire les faits donnés et rien d'autre, aucun chiffre ni nombre écrit en lettres, aucun conseil, aucun jugement, aucun vocabulaire médical. Sa sortie est contrainte par le schéma JSON `{"text": string}` (ADR-001), avec les paramètres de l'ADR-001 (température 0,2) et au plus 160 jetons.

### Validation de la sortie (RM53)

Le texte n'est montré que s'il passe **toutes** ces règles, appliquées par `ReviewTextValidator` (code Dart pur, sans modèle) :

1. La sortie est un objet JSON conforme au schéma, avec un champ `text` non vide une fois les espaces retirés au début et à la fin.
2. Le texte compte au plus 300 caractères visibles (un émoji composé compte pour un, comme RM27).
3. Le texte brut ne contient aucun caractère numérique (catégorie Unicode « nombre » : chiffres de 0 à 9 et de toute écriture, exposants, fractions comme « ½ ») ni les signes « % » et « ‰ ».
4. Le texte normalisé (règles de normalisation de la spec 002 : minuscules, accents retirés, ponctuation remplacée par une espace) ne contient, en **mots entiers**, aucune expression de la « Liste des mots de nombre » ni de la « Liste des expressions interdites » ci-dessous.
5. `DistressDetector.detectInText` ne détecte rien dans le texte.

Une sortie rejetée, une erreur du modèle ou une absence de réponse en 30 secondes donnent le bilan sans texte : l'app ne plante pas, et la sortie brute n'est ni montrée, ni enregistrée, ni journalisée.

### Liste des mots de nombre

Rédigée pour le projet. Le code reprend cette liste à l'identique ; un test le vérifie en relisant ce bloc (CA25). « un » et « une » n'y figurent pas : ce sont aussi des articles.

```text
zero
deux
trois
quatre
cinq
six
sept
huit
neuf
dix
onze
douze
treize
quatorze
quinze
seize
vingt
vingts
trente
quarante
cinquante
soixante
cent
cents
mille
million
millions
milliard
milliards
moitie
tiers
quart
quarts
double
triple
pour cent
pourcent
pourcentage
premier
premiere
deuxieme
second
seconde
troisieme
quatrieme
cinquieme
sixieme
septieme
huitieme
neuvieme
dixieme
demi
demie
quadruple
quintuple
dizaine
douzaine
centaine
```

### Liste des expressions interdites

Rédigée pour le projet, même vérification (CA25). Elle couvre le conseil, le soin et le jugement (RM4) ; la détresse est couverte par la règle 5.

```text
# Conseil et injonction
tu devrais
tu dois
il faut
il faudrait
tu pourrais
tu peux
pourquoi ne pas
essaie
essaye
essayer
pense a
n oublie
n hesite pas
prends soin
prendre soin
prends le temps
prendre le temps
repose toi
accorde toi
occupe toi
laisse toi
autorise toi
offre toi
fais toi
conseil
conseils
conseille
conseiller
recommande
recommandation
# Santé et soin
medecin
medecins
docteur
therapeute
therapie
psychologue
psychiatre
psy
traitement
medicament
medicaments
diagnostic
symptome
symptomes
maladie
malade
depression
depressif
depressive
burn out
burnout
trouble
troubles
sante mentale
soigner
guerir
consulter
consulte
urgence
urgences
aide
appelle
appeler
# Jugement
bravo
felicitations
inquietant
inquietante
inquietants
inquietantes
alarmant
alarmante
alarmants
alarmantes
grave
graves
normal
normale
normaux
anormal
anormale
anormaux
```

Limite assumée : un impératif absent de la liste (« Sors marcher davantage ») n'est pas reconnu, faute d'analyse grammaticale. Les consignes du modèle l'interdisent, la sortie est courte, et les injonctions les plus courantes sont listées ; un tel texte reste sans chiffre ni vocabulaire médical (CA36).

« neuf » (au sens de « nouveau ») ou « aide » au sens banal sont rejetés aussi : un texte rejeté à tort ne coûte qu'un bilan sans texte, un conseil ou un chiffre inventé coûte la confiance.

### Conservation du texte (RM54)

Le texte validé n'est jamais enregistré dans la base. Il est gardé en mémoire tant que l'app est ouverte, pour une semaine et des faits donnés : revenir sur la même semaine sans changement ne rappelle pas le modèle ; une entrée ajoutée ou supprimée qui change les faits relance la mise en mots.

**Ordre des vérifications, à chaque affichage** : la sensibilité de la semaine est évaluée sur ses entrées actuelles **avant** toute lecture de la mémoire. Une semaine sensible n'affiche jamais de texte et efface celui gardé pour elle, même si ses faits n'ont pas changé : une entrée à « Très bas » ou en détresse ajoutée un jour déjà noté peut laisser les faits identiques. Garde-fou couvert par CA34.

## Critères d'acceptation

### Accès depuis la liste

- CA1 : Étant donné au moins une entrée dans le journal, quand la liste s'affiche, alors une carte « Bilan de la semaine » apparaît sous le titre, avant le premier jour, avec les dates de la semaine en cours (« Du lundi 12 au dimanche 18 octobre » ; « Du lundi 28 septembre au dimanche 4 octobre » quand le mois change ; l'année à chaque borne quand l'année change) ; elle s'annonce au lecteur d'écran comme un bouton « Bilan de la semaine, du lundi 12 au dimanche 18 octobre ».
- CA2 : Étant donné la liste vide, en cours de lecture ou en erreur (spec 001), quand elle s'affiche, alors la carte n'apparaît pas.
- CA3 : Étant donné la carte, quand la personne la touche, alors l'écran du bilan s'ouvre sur la semaine en cours, même si elle compte moins de 3 entrées.

### Semaine affichée

- CA4 : Étant donné l'écran du bilan, quand il s'affiche, alors il montre le retour « Journal », le titre « Ta semaine », les dates de la semaine (« 12 – 18 octobre » ; « 28 septembre – 4 octobre » quand le mois change ; avec l'année à chaque borne si elle diffère de l'année en cours), et la mention « Semaine en cours » ou « Semaine dernière » pour ces deux semaines, aucune pour les autres.
- CA5 : Étant donné l'écran du bilan, quand la personne touche « Semaine précédente » ou « Semaine suivante », alors la semaine affichée change. « Semaine suivante » est désactivé sur la semaine en cours, « Semaine précédente » sur la semaine de l'entrée la plus ancienne.
- CA6 : Étant donné une semaine de 0, 1 ou 2 entrées, quand elle s'affiche, alors l'écran montre « Pas encore de bilan pour cette semaine » et « Le bilan demande au moins 3 entrées dans la semaine ; celle-ci en compte 2. » (« celle-ci en compte 1. » pour 1 ; « celle-ci n'en compte aucune. » pour 0), sans chiffre ni texte, et le rédacteur n'est pas appelé (RM21).
- CA7 : Étant donné une entrée saisie le dimanche à 23:30, heure locale, dans un fuseau, et l'app ouverte ensuite dans un autre fuseau, quand le bilan est calculé, alors l'entrée compte dans la semaine de ce dimanche (jour local de saisie, spec 001).

### Chiffres

- CA8 : Étant donné une semaine de 7 entrées, dont une non analysée sans texte, une non analysée avec texte (détresse) et une en attente, quand le bilan s'affiche, alors « Entrées » vaut 7 : toutes les entrées comptent, quel que soit leur statut.
- CA9 : Étant donné des entrées d'humeurs 4, 3, 2, 4, 5, 3, 4, quand le bilan s'affiche, alors « Humeur moyenne » vaut « 3,6 », suivi de « sur 5 ». Étant donné des humeurs 3, 4, 3, 4 (moyenne 3,5), alors elle vaut « 3,5 » ; étant donné 2, 3, 3 (moyenne 2,666…), alors « 2,7 » ; étant donné 3, 3, 4, 4, 4, 4, 4, 4 (moyenne 3,75), alors « 3,8 ».
- CA10 : Étant donné les mêmes 7 entrées, quand la répartition s'affiche, alors elle montre une ligne par humeur, de « Très bas » à « Très bien », avec leur nombre (0, 1, 2, 3, 1), y compris les zéros, et une barre proportionnelle au plus grand nombre.
- CA11 : Étant donné des entrées le lundi, le mardi, le jeudi, le samedi et le dimanche, dont plusieurs le même jour, quand le bilan s'affiche, alors « Jours notés » montre « 5 jours sur 7 », les sept jours de L à D distingués entre notés et non notés, et « Entrées » porte la mention « sur 5 jours ». Étant donné 3 entrées le même jour, alors « 1 jour sur 7 » et « sur 1 jour ».
- CA12 : Étant donné des entrées étiquetées portant « fatigue » (3 entrées), « travail » (3), « calme » (2) et « joie » (1), quand le bilan s'affiche, alors « Étiquettes fréquentes » montre, dans cet ordre, « fatigue · 3 », « travail · 3 », « calme · 2 », et la mention « Analysé sur ton téléphone ». Seules les entrées au statut « étiquetée » comptent.
- CA13 : Étant donné aucune entrée étiquetée dans la semaine, quand le bilan s'affiche, alors la section montre « Aucune étiquette cette semaine. ».
- CA14 : Étant donné une semaine précédente d'au moins 3 entrées, de moyenne 3,0 et de 5 entrées, et une semaine de moyenne 3,6 et de 7 entrées, quand le bilan s'affiche, alors la carte « Par rapport à la semaine précédente » montre « Humeur moyenne : 3,6, contre 3,0. En hausse de 0,6. » et « Entrées : 7, contre 5. » ; avec des moyennes arrondies égales, « Stable. » ; plus basses, « En baisse de … ».
- CA15 : Étant donné une semaine précédente de moins de 3 entrées, quand le bilan s'affiche, alors la carte d'évolution n'apparaît pas.
- CA16 : Étant donné un rédacteur factice qui rend un texte valide, quand le bilan s'affiche, alors chaque chiffre affiché est identique à celui calculé par `WeeklyReviewCalculator` sans rédacteur : aucun chiffre ne vient du modèle (RM10).
- CA17 : Étant donné l'écran du bilan affiché, quand une entrée de la semaine est ajoutée ou supprimée, alors les chiffres sont recalculés au retour sur l'écran.

### Mise en mots

- CA18 : Étant donné une semaine d'au moins 3 entrées, non sensible, et le modèle prêt, quand l'écran s'affiche, alors les chiffres s'affichent sans attendre le modèle, et la carte du texte montre « Mise en mots sur ton téléphone… » et « Les chiffres ci-dessous sont déjà complets. » jusqu'à la réponse.
- CA19 : Étant donné une sortie qui passe la validation, quand elle arrive, alors la carte montre le texte, suivi de « Mis en mots sur ton téléphone, à partir des chiffres ci-dessous ».
- CA20 : Étant donné une semaine sensible (une entrée à 1 ; ou une entrée non analysée avec texte ; ou une entrée dont le texte est détecté par `detectInText`, quel que soit son statut), quand le bilan s'affiche, alors le rédacteur n'est pas appelé et la carte montre « Pas de texte pour cette semaine : le bilan s'en tient aux chiffres. » ; l'écran ne mentionne ni la détresse, ni l'écran d'aide, ni le 3114. Chaque critère de sensibilité est testé seul.
- CA21 : Étant donné une semaine non sensible, quand le rédacteur est appelé, alors il reçoit seulement un `ReviewFacts` : libellé de l'humeur moyenne, régularité, au plus 3 libellés d'étiquettes et tendance. Le test vérifie, sur le rédacteur factice qui enregistre ce qu'il reçoit, qu'aucun texte d'entrée n'y apparaît et qu'aucun chiffre n'apparaît dans sa forme sérialisée.
- CA22 : Étant donné une sortie dont le texte contient un chiffre (« 3 jours »), un chiffre d'une autre écriture, une fraction (« ½ ») ou « % », quand elle est validée, alors elle est rejetée et le bilan s'affiche sans texte, avec « Pas de texte pour cette semaine : le bilan s'en tient aux chiffres. ».
- CA23 : Étant donné une sortie qui contient un mot de nombre de la liste, avec majuscules, accents ou ponctuation (« Trois jours », « la moitié »), quand elle est validée, alors elle est rejetée ; un mot qui ne fait que contenir une expression (« septembre » contient « sept », « deuxièmement » contient « deuxième ») n'est pas rejeté pour cette raison.
- CA24 : Étant donné une sortie qui contient une expression interdite (« Tu devrais consulter. », « Une semaine inquiétante. ») ou une expression de la liste de détresse de la spec 002, quand elle est validée, alors elle est rejetée.
- CA25 : Étant donné les deux listes de cette spec, quand les tests s'exécutent, alors les listes du code sont identiques aux blocs « Liste des mots de nombre » et « Liste des expressions interdites » de ce fichier (même ensemble d'expressions, lignes `#` et vides ignorées), et chaque expression, insérée dans une phrase fictive, fait rejeter la sortie.
- CA26 : Étant donné une sortie non conforme au schéma JSON, un texte vide, un texte de plus de 300 caractères visibles, une erreur du modèle ou aucune réponse en 30 secondes, quand le bilan s'affiche, alors il s'affiche sans texte, avec le même message que CA22, sans plantage, et la sortie brute n'est ni affichée ni enregistrée.
- CA27 : Étant donné le modèle absent (pas téléchargé, ou en cours de téléchargement), quand le bilan d'une semaine d'au moins 3 entrées s'affiche, alors le rédacteur n'est pas appelé, et la carte montre « Pas de texte : le modèle local n'est pas sur ce téléphone. Les chiffres sont calculés sans lui. » ; l'écran ne propose pas le téléchargement (RM18 reste la seule porte d'entrée). Étant donné un rédacteur appelé qui rend quand même `ModelMissing` (modèle supprimé entre-temps), alors la carte montre ce même message ; `WriterFailed` donne celui de CA22.
- CA28 : Étant donné un texte validé pour une semaine, quand la personne change de semaine puis revient, sans entrée ajoutée ni supprimée, alors le même texte s'affiche sans nouvel appel au rédacteur. Le texte n'est jamais écrit dans la base (RM54).
- CA34 : Étant donné un texte en mémoire pour une semaine non sensible, quand une entrée à 1 y est ajoutée un jour déjà noté sans changer les faits du bilan, alors le texte n'est plus affiché, la carte montre le message de CA20 et le rédacteur n'est pas appelé ; même vérification dans un second cas, avec une entrée en détresse d'humeur 3. Après la suppression de cette entrée, revenir sur la semaine relance la mise en mots : le texte effacé n'est pas réutilisé.
- CA35 : Étant donné 11 entrées de somme 38 (moyenne 3,4545…), quand le bilan s'affiche, alors « Humeur moyenne » vaut « 3,5 » et le rédacteur reçoit `averageMoodLabel` « Neutre », arrondi depuis la moyenne exacte ; la tendance transmise suit le signe de l'évolution affichée (CA14).
- CA36 : Étant donné la sortie `{"text": "Une semaine calme. Sors marcher davantage."}`, quand elle est validée, alors elle est acceptée. Ce critère documente la limite assumée des impératifs absents de la liste ; la changer exige de mettre la spec à jour.

### États

- CA29 : Étant donné la lecture des entrées en cours, quand l'écran du bilan s'affiche, alors il montre le retour, le titre, la semaine et « Calcul du bilan sur ton téléphone… », sans chiffre.
- CA30 : Étant donné une erreur de lecture des entrées, quand l'écran du bilan s'affiche, alors il montre le bandeau « Ton bilan n'a pas pu être calculé » avec « Tes entrées sont toujours sur le téléphone. Rien n'a été effacé. Réessaie. », et le bouton « Réessayer », qui relance la lecture.

### Accessibilité et thème

- CA31 : Étant donné l'écran du bilan, quand un lecteur d'écran le parcourt, alors le titre est annoncé en premier ; les flèches s'annoncent « Semaine précédente » et « Semaine suivante », avec leur état désactivé ; un changement de semaine annonce les nouvelles dates ; « Humeur moyenne : 3,6 sur 5 » est lu d'un bloc ; la répartition est annoncée en une phrase (« Répartition des humeurs : Très bas, 0 entrée ; Bas, 1 entrée ; Neutre, 2 entrées ; Bien, 3 entrées ; Très bien, 1 entrée. »), les barres étant ignorées ; les jours notés aussi (« Jours notés : lundi, mardi, jeudi, samedi, dimanche. ») ; chaque étiquette s'annonce « fatigue, 3 entrées ».
- CA32 : Étant donné la taille de texte du système à 200 %, quand l'écran du bilan et la carte de la liste s'affichent, alors aucun texte n'est tronqué ni ne déborde : l'écran défile, les libellés de la répartition passent à la ligne, les flèches restent atteignables.
- CA33 : Étant donné le thème sombre du système, quand l'écran du bilan et la carte de la liste s'affichent, alors ils utilisent les couleurs du thème sombre de la charte ; `danger` ne sert qu'au titre du bandeau d'erreur (CA30) ; les barres de la répartition prennent les couleurs `mood-1` à `mood-5`, toujours avec le libellé et le nombre à côté.

## Données

Fixées par cette spec, puis reportées dans l'architecture technique avec l'implémentation (nouveau contrat `ReviewWriter`).

- **Calculateur** (`WeeklyReviewCalculator`) : code Dart pur, sans état ni accès à la base, testable sans Flutter.
  - `WeeklyReview compute({required LocalWeek week, required List<Entry> entries, required Map<int, List<Tag>> tagsByEntry})` : `entries` contient toutes les entrées du journal ; le calculateur garde celles de la semaine et de la semaine précédente.
  - `LocalWeek` : le lundi de la semaine, en date locale ; `LocalWeek.containing(DateTime localDay)`.
- **Bilan de la semaine** (`WeeklyReview`) : soit `InsufficientWeek(entryCount)` (moins de 3 entrées), soit `ComputedWeek` avec `entryCount`, `averageMoodTenths` (entier : 36 pour 3,6), `moodCounts` (5 entiers), `notedDays` (jours de 1, lundi, à 7, dimanche), `topTags` (au plus 3 couples étiquette et nombre), `comparison` (moyenne et nombre d'entrées de la semaine précédente, ou absent), `isSensitive`, et `facts` (`ReviewFacts`).
- **Faits du bilan** (`ReviewFacts`) : `averageMoodLabel`, `regularity` (`WeekRegularity`), `topTagLabels`, `trend` (`ReviewTrend`). Aucun champ numérique.
- **Rédacteur du bilan** (`ReviewWriter`), interface qui isole le modèle comme `MoodAnalyzer` :
  - `Future<ReviewDraft> write(ReviewFacts facts)`, qui ne lève jamais d'exception. `ReviewDraft` vaut `RawReview(String output)` (la sortie brute du modèle, à valider), `ModelMissing` ou `WriterFailed`.
  - `Future<void> cancel()` : abandonne la mise en mots en cours (délai de 30 s dépassé, écran quitté, autre semaine affichée) ; `write` rend alors `WriterFailed`. Ajouté à l'implémentation (PR #27), nécessaire aux « Cas limites ».
  - Implémentation réelle sur `llamadart` (ADR-001), même modèle que l'étiquetage, une génération à la fois ; `FakeReviewWriter` dans `test/support/`, seul utilisé par les tests et la CI, qui rend une sortie choisie par le test et enregistre ce qu'il reçoit.
  - L'appelant applique le délai de 30 secondes, puis `ReviewTextValidator`.
- **Validateur** (`ReviewTextValidator`) : code Dart pur. `String? validate(String output)` rend le texte à afficher, ou `null` si la sortie est rejetée. Il réutilise la normalisation et `detectInText` de `DistressDetector` (spec 002).
- **Dépôt des entrées** (`EntryRepository`) : inchangé. L'écran lit `watchEntries()` et filtre en Dart (quelques centaines d'entrées par an). Les étiquettes sont lues par l'interface que définit la spec 004, étiquetage automatique.
- **Stockage** : aucun. Ni table, ni migration : le bilan est recalculé à chaque affichage, et le texte reste en mémoire (RM54). La suppression totale (lot H) n'a donc rien de plus à effacer.

## Maquette

Artefact Claude de type « Design » ([lien privé](https://claude.ai/artifact/HpKb64hQ1aWeLVZzyXH9wj)), construit sur la charte. La copie versionnée, qui fait foi, est dans [`docs/maquettes/006-bilan-de-la-semaine/`](../maquettes/006-bilan-de-la-semaine/).

Écrans, chacun en clair et en sombre :

- **Bilan** : nominal (avec texte, interactif : la semaine précédente montre une semaine sensible, la suivante une semaine de 2 entrées), mise en mots en cours, sans texte généré, modèle absent, moins de 3 entrées, chargement, erreur.
- **Liste** : avec la carte « Bilan de la semaine » en tête.

Jetons : la maquette n'utilise que les jetons de la charte, à quatre exceptions près, à ajouter à la charte, à `tokens.json` et au test de fidélité dans la PR d'implémentation : `icon-md` (24) et `icon-button` (18), déjà demandés par la spec 002, `bar-thickness` (8, barre de la répartition) et `day-cell` (40, case d'un jour). Détail dans le [README de la maquette](../maquettes/006-bilan-de-la-semaine/README.md). Captures PNG absentes, comme pour les maquettes 001 et 002 : l'agent ne peut pas exporter l'artefact. Reporté à une issue de suivi, proposée dans la PR #17 et à créer avec l'accord de Yanis ; d'ici là, la spec renvoie vers l'artefact et vers la source HTML versionnée.

## Cas limites et erreurs

- Semaine en cours le lundi matin, sans entrée : CA6, « celle-ci n'en compte aucune ».
- Changement d'heure (passage à l'heure d'été ou d'hiver) : la semaine se calcule en jours locaux, pas en tranches de 7 × 24 heures.
- Semaine à cheval sur deux années (29 décembre – 4 janvier) : les deux bornes portent leur année si l'une diffère de l'année en cours.
- Semaine précédente sensible : elle sert quand même à l'évolution (seuls ses chiffres sont comparés).
- Entrées enregistrées avant le lot F et jamais vérifiées : couvertes par le critère 3 de la semaine sensible.
- Toutes les entrées sans texte : les chiffres s'affichent ; sans étiquette, `topTagLabels` est vide et la section montre CA13 ; le texte peut être généré si la semaine n'est pas sensible.
- Modèle occupé par l'étiquetage d'une entrée : la mise en mots attend son tour, dans la limite des 30 secondes (CA26).
- La personne quitte l'écran pendant la mise en mots : la génération est abandonnée, rien n'est gardé.

## Hors périmètre

- Bilan du mois ou de l'année, graphiques sur plusieurs semaines.
- Notification de fin de semaine (hors périmètre du projet).
- Partage ou export du bilan : l'export (lot H) porte sur les entrées (RM20).
- Correction du texte du bilan par la personne, ou nouvelle génération à la demande.
- Accès à l'écran d'aide depuis le bilan (spec 002, « Hors périmètre »).
- Bilan dans une autre langue que le français (RM22).

## Questions ouvertes

Aucune. Décisions prises par l'agent, à la demande de Yanis (2026-10-14) :

1. **Accès** : une carte « Bilan de la semaine » en tête de la liste, dès la première entrée ; l'écran s'ouvre sur la semaine en cours et permet de remonter semaine par semaine jusqu'à la première entrée (CA1 à CA5). Le plus simple à tester : un seul point d'entrée, une navigation linéaire.
2. **Entrées comptées** : toutes, quel que soit leur statut, y compris celles en détresse : les chiffres restent vrais, et ils sont calculés sans modèle (CA8).
3. **Moyenne** : par entrée, au dixième, la moitié vers le haut, calculée en entiers (CA9).
4. **Ce que reçoit le modèle** : des faits sans chiffre (libellé de la moyenne, régularité, étiquettes, tendance), jamais une entrée (RM51, CA21). Le plus sûr pour RM8 et RM10.
5. **Semaine sensible** : pas de texte généré dès qu'une entrée est à « Très bas » ou en détresse, et aucun rappel de l'écran d'aide, pour rester cohérent avec la spec 002 (RM52, CA20). Le plus sûr : aucun texte généré ne côtoie une semaine difficile, et le critère « humeur 1 » se teste sans dépendre de la sensibilité choisie.
6. **Validation** : règles déterministes (schéma, longueur, caractères numériques, mots de nombre, expressions interdites, détecteur de détresse), listes vérifiées par un test qui relit cette spec (RM53, CA22 à CA26). Rejet à tort assumé.
7. **Modèle absent** : chiffres seuls, message propre, pas de proposition de téléchargement depuis le bilan (CA27).
8. **Conservation** : texte jamais enregistré, gardé en mémoire tant que l'app est ouverte (RM54, CA28) : rien de plus à chiffrer ni à effacer.
9. **Évolution** : seulement si la semaine précédente a un bilan, sur les moyennes arrondies et le nombre d'entrées (CA14, CA15).
10. **Mémoire et sensibilité** (revue IA de la PR #17) : sensibilité évaluée avant toute lecture de la mémoire, texte effacé pour une semaine devenue sensible (CA34).
11. **Arrondis** : libellé transmis au modèle depuis la moyenne exacte, tendance depuis les moyennes affichées (CA35).
12. **Impératifs** : injonctions courantes ajoutées à la liste ; les autres impératifs sont une limite assumée, documentée par CA36, plutôt qu'une analyse grammaticale fragile.
13. **`ModelMissing` et `WriterFailed`** : messages de CA27 et de CA22.
