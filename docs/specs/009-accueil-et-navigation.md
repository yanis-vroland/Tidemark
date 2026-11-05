# Spec 009 : accueil et navigation

Statut : proposée (rédigée par l'agent en autonomie, à la demande de Yanis du 2026-11-05 ; validation au merge de la PR, [issue #48](https://github.com/yanis-vroland/Tidemark/issues/48))
Date : 2026-11-05

## Besoin

En tant que personne qui tient son journal, je veux noter mon humeur dès l'ouverture de l'app et voir ma semaine d'un coup d'œil, afin que tenir mon journal soit rapide et agréable.

En tant que personne qui découvre l'app, je veux comprendre en un écran ce qu'elle fait et que rien ne quitte mon téléphone, afin de commencer en confiance.

Cette spec s'appuie sur la charte v2 ([spec 008](008-charte-ludique.md)) et modifie l'accueil de la spec 001, l'accès au bilan de la spec 006 et l'en-tête du bilan. Les critères remplacés sont cités.

## Définitions

- **Humeur du jour** : humeur de la dernière entrée saisie ce jour local (date de saisie la plus récente, puis plus grand identifiant). Sert seulement aux dessins de la plage et de l'en-tête du bilan ; les chiffres du bilan ne changent pas (RM50).
- **Semaine en cours** : semaine locale (`LocalWeek`, du lundi au dimanche) qui contient la date du jour.
- **Moment de la journée** : « jour » de 05:00 à 17:59, heure locale ; « soir » de 18:00 à 04:59.

## Critères d'acceptation

### Bienvenue

- CA1 : Étant donné un premier lancement (réglage « bienvenue vue » à faux et aucune entrée), quand l'app s'ouvre, alors l'écran de bienvenue s'affiche à la place du journal : le logo et « Tidemark », le titre « Comment va ta marée aujourd'hui ? », trois étapes (« Choisis une bulle, ajoute un mot si tu veux. », « Ramasse un coquillage à chaque entrée. », « Regarde ta semaine monter et descendre. »), la mention « Rien ne quitte ton téléphone. » et le bouton « C'est parti ».
- CA2 : Étant donné l'écran de bienvenue, quand la personne touche « C'est parti », alors le réglage « bienvenue vue » passe à vrai et l'accueil du journal s'affiche ; aux lancements suivants, la bienvenue ne s'affiche plus.
- CA3 : Étant donné un journal qui compte au moins une entrée et le réglage à faux (mise à jour depuis une version sans bienvenue), quand l'app s'ouvre, alors la bienvenue ne s'affiche pas.
- CA4 : Étant donné une suppression totale réussie (spec 005), quand l'app revient à l'état du premier lancement, alors la bienvenue s'affiche de nouveau (le réglage est effacé avec la base), avant le message de fin de suppression (spec 005, CA18), qui s'affiche ensuite sur l'accueil.
- CA5 : Étant donné une erreur à l'écriture du réglage, quand la personne touche « C'est parti », alors l'accueil s'affiche quand même, sans message ; la bienvenue reviendra au lancement suivant.
- CA6 : Étant donné une erreur à la lecture du réglage ou des entrées au démarrage, quand l'app s'ouvre, alors la bienvenue ne s'affiche pas : l'accueil gère l'erreur (spec 001, CA32).

### En-tête de l'accueil

- CA7 : Étant donné l'accueil, quand il s'affiche, alors l'en-tête `hero` montre le surtitre « Ton journal » (annoncé comme titre de l'écran), la salutation « Bonjour » le jour et « Bonsoir » le soir, et le bouton « Réglages » en haut à droite. Remplace la spec 001, CA31, pour la place du titre « Ton journal », toujours visible pendant la lecture.
- CA8 : Étant donné l'en-tête, quand il s'affiche, alors sa scène est décorative et non annoncée : le soir, une lune, des étoiles, une mouette et un voilier qui tangue ; le jour, un soleil et la mouette ; des vagues `hero-wave-1` et `hero-wave-2` qui se déplacent (spec 008, mouvement).
- CA9 : Étant donné la semaine en cours, quand l'accueil s'affiche avec au moins une entrée dans le journal, alors une puce de l'en-tête dit « Aucun coquillage cette semaine », « 1 coquillage cette semaine » ou « N coquillages cette semaine », N étant le nombre d'entrées de la semaine en cours, quel que soit leur statut, chacune dans la semaine de son jour local de saisie (comme RM50).
- CA10 : Étant donné l'app restée ouverte d'un moment de la journée à l'autre, ou d'une semaine à l'autre, quand elle revient au premier plan, alors la salutation, la scène et le compteur sont recalculés.

### Check-in

- CA11 : Étant donné le journal lu (vide ou non), quand l'accueil s'affiche, alors une carte « Comment va ta marée aujourd'hui ? » (jour) ou « Comment va ta marée ce soir ? » (soir) montre cinq bulles `bubble-check` avec leur libellé (RM3) dessous. Pendant la lecture et en cas d'erreur de lecture, la carte n'apparaît pas.
- CA12 : Étant donné la carte du check-in, quand un lecteur d'écran la parcourt, alors chaque bulle s'annonce comme un bouton « Noter Bien, humeur 4 sur 5 ».
- CA13 : Étant donné la carte du check-in, quand la personne touche une bulle, alors l'écran de saisie s'ouvre avec cette humeur déjà choisie : son libellé s'affiche et « Enregistrer » est actif (spec 001, CA8). Le reste de la saisie est inchangé.

### Plage de la semaine

- CA14 : Étant donné au moins une entrée dans le journal, quand l'accueil s'affiche, alors la carte « Ta plage cette semaine » apparaît sous le check-in, avant le premier jour de la liste. Elle montre les sept jours de la semaine en cours, de « L » à « D » ; un jour noté a une bulle `bubble-sm` de l'humeur du jour, d'autant plus haute que l'humeur est haute (8 points par cran au-dessus de 1) ; un jour sans entrée, passé ou à venir, a un cercle pointillé. Remplace la carte « Bilan de la semaine » de la spec 006, CA1.
- CA15 : Étant donné la carte de la plage, quand un lecteur d'écran la parcourt, alors elle s'annonce comme un seul bouton : « Ta plage cette semaine : lundi Bien, mardi pas d'entrée, …, dimanche pas d'entrée. Ouvre le bilan de la semaine. », avec le libellé de l'humeur du jour (RM3) ou « pas d'entrée » pour chaque jour.
- CA16 : Étant donné la carte de la plage, quand la personne la touche, alors l'onglet « Semaine » s'ouvre sur la semaine en cours, même si elle compte moins de 3 entrées. Remplace la spec 006, CA3.
- CA17 : Étant donné le journal vide, en cours de lecture ou en erreur, quand l'accueil s'affiche, alors ni la plage ni le compteur n'apparaissent (comme la spec 006, CA2).
- CA18 : Étant donné l'accueil, quand il s'affiche avec des entrées, alors la liste des entrées regroupées par jour suit la plage (spec 001, CA2, CA3, CA6, inchangés) ; l'état vide garde son texte et le logo (spec 001, CA1 ; spec 007, CA4), sous le check-in.

### Barre de navigation

- CA19 : Étant donné l'accueil ou l'onglet « Semaine », quand il s'affiche, alors une barre de navigation montre « Journal », au centre une bulle `nav-bubble` « + » avec le libellé « Nouvelle entrée », et « Semaine » ; l'onglet ouvert est mis en avant et annoncé comme sélectionné. La barre remplace le bouton « Nouvelle entrée » du bas de la liste (spec 001, CA1).
- CA20 : Étant donné la barre, quand la personne touche « Nouvelle entrée », alors l'écran de saisie s'ouvre sans humeur choisie (spec 001, CA7).
- CA21 : Étant donné la barre, quand la personne passe d'un onglet à l'autre, alors chaque onglet garde son état (défilement de la liste, semaine affichée du bilan).
- CA22 : Étant donné un écran ouvert par-dessus (saisie, détail, Réglages, écran d'aide, modèle, célébration), quand il s'affiche, alors la barre n'y apparaît pas ; le retour ramène à l'onglet d'où il a été ouvert.

### Onglet « Semaine »

- CA23 : Étant donné l'onglet « Semaine », quand il s'affiche, alors il montre l'écran du bilan (spec 006) de la semaine en cours, sans le retour « Journal », que la barre remplace. Le titre « Ta semaine », les dates et les flèches de semaine (spec 006, CA4, CA5) sont inchangés. Remplace le retour « Journal » de la spec 006, CA4.
- CA24 : Étant donné une semaine affichée dans l'onglet, quand l'écran s'affiche, alors l'en-tête `sky` montre la marée de la semaine : pour chaque jour noté, une bulle de l'humeur du jour posée sur une mer `sea` dont la surface passe par ces bulles ; un cercle pointillé pour un jour sans entrée ; les initiales des jours sur une bande `sand`. La scène est décorative ; elle est annoncée par un seul libellé : « Humeur par jour : lundi Bien, mardi pas d'entrée, … ». Elle s'affiche quel que soit le nombre d'entrées de la semaine.
- CA25 : Étant donné une semaine d'au moins 3 entrées, quand le bilan s'affiche, alors « Humeur moyenne », « Jours notés » et « Entrées » sont présentés en autocollants (spec 008) en tête du bilan, avec exactement les valeurs de `WeeklyReviewCalculator` (spec 006, CA16) ; les sections de la spec 006 (répartition, étiquettes fréquentes, évolution, texte) suivent, avec leurs textes inchangés.
- CA26 : Étant donné l'onglet « Semaine » ouvert, quand une entrée est ajoutée ou supprimée, alors la marée et les chiffres sont recalculés au retour sur l'onglet (spec 006, CA17).

### Accessibilité

- CA27 : Étant donné la taille de texte du système à 200 %, quand la bienvenue, l'accueil et l'onglet « Semaine » s'affichent, alors le texte grandit avec le réglage, sans plafond ni rétrécissement, et aucun texte n'est tronqué ni ne déborde : les écrans défilent ; la barre de navigation garde des libellés lisibles.
- CA28 : Étant donné le thème sombre du système, quand ces écrans s'affichent, alors ils prennent les valeurs sombres des jetons.

## Cas limites et erreurs

- Fuseau changé : les jours de la plage et le compteur suivent le jour local de saisie, comme le bilan (spec 006, CA7).
- Plusieurs entrées le même jour : la plage montre l'humeur de la dernière ; le compteur les compte toutes.
- Une entrée en détresse ou non analysée compte comme les autres (dans le compteur et la plage) ; aucun libellé de l'app n'en parle.
- Minuit passé pendant l'usage : voir CA10.
- Lecture du réglage « bienvenue vue » en erreur : traité comme vrai (CA6), pour ne jamais bloquer l'accès au journal.

## Hors périmètre

- Séries de jours, objectifs, rappels : aucune pénalité ni message si un jour manque.
- Choix d'un autre jour que la semaine en cours dans la plage.
- Onglet « Réglages » : les Réglages restent ouverts par le bouton de l'en-tête.

## Maquette

Voir la [spec 008](008-charte-ludique.md#maquette) : écrans `Bienvenue`, `Journal`, `Semaine`, composant `TabBar`, dans [`docs/maquettes/008-refonte-ludique/`](../maquettes/008-refonte-ludique/).

## Questions ouvertes

Aucune. Décisions de l'agent, par délégation de Yanis : humeur du jour = dernière entrée du jour ; « jour » de 05:00 à 17:59 ; bienvenue réaffichée après une suppression totale.
