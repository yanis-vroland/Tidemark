# Spec 010 : ce qui a compté, et coquillage ramassé

Statut : proposée (rédigée par l'agent en autonomie, à la demande de Yanis du 2026-11-05 ; validation au merge de la PR, [issue #48](https://github.com/yanis-vroland/Tidemark/issues/48))
Date : 2026-11-05

## Besoin

En tant que personne qui tient son journal, je veux noter en un geste ce qui a compté dans ma journée, sans avoir à l'écrire, afin de m'en souvenir en relisant mon entrée.

En tant que personne qui tient son journal, je veux un petit moment agréable après avoir noté mon humeur, afin d'avoir envie de revenir, sans que l'app me félicite d'un jour difficile.

## Définitions

- **Sujet** (`Topic`) : ce qui a compté pour la personne, qu'elle choisit elle-même à la saisie, dans une liste fixe et ordonnée de six, par leur libellé : « sommeil », « travail », « amis », « famille », « sport », « nature » (noms dans le code : `sleep`, `work`, `friends`, `family`, `sport`, `nature`). Un sujet n'est pas une étiquette : une étiquette est proposée par le modèle local (RM19), un sujet est choisi par la personne.
- **Coquillage** : image d'une entrée enregistrée sur la plage de la semaine (spec 009). Ce n'est pas une donnée : c'est une entrée.

## Critères d'acceptation

### Sujets à la saisie

- CA1 : Étant donné l'écran de saisie, quand il s'affiche, alors une section « Ce qui a compté » montre les six sujets dans l'ordre de la liste, en autocollants à bascule ; aucun n'est choisi au départ.
- CA2 : Étant donné la section, quand la personne touche un sujet, alors il est choisi (fond `ink`, texte `surface`) ; le toucher de nouveau le retire. De 0 à 6 sujets peuvent être choisis ; aucun n'est obligatoire.
- CA3 : Étant donné la section, quand un lecteur d'écran la parcourt, alors chaque sujet s'annonce comme un bouton à bascule avec son libellé et son état (choisi ou non), et le groupe porte le titre « Ce qui a compté ».
- CA4 : Étant donné une humeur et des sujets choisis, quand la personne enregistre, alors l'entrée est enregistrée avec ses sujets, dans l'ordre de la liste, avec ou sans texte. Le statut d'analyse ne dépend pas des sujets : une entrée sans texte reste « non analysée » (RM24).
- CA5 : Étant donné des sujets choisis puis « Annuler » sans texte écrit, quand la personne quitte la saisie, alors rien n'est enregistré, sans confirmation (spec 001, CA13 inchangé : seuls un texte écrit demande confirmation, CA30).
- CA6 : Étant donné une entrée avec des sujets, quand l'analyse ou le garde-fou de détresse s'exécutent, alors ils ne reçoivent que le texte : aucun sujet n'est transmis au modèle (RM36) ni au détecteur de détresse.

### Sujets affichés et conservés

- CA7 : Étant donné une entrée avec au moins un sujet, quand son détail s'affiche, alors une section « Ce qui a compté » montre ses sujets en autocollants (fond `ink`, texte `surface`), avant la section « Étiquettes » ; sans sujet, la section n'apparaît pas.
- CA8 : Étant donné la liste, quand une carte s'affiche, alors elle ne montre pas les sujets : la carte et son annonce sont inchangées (RM59).
- CA9 : Étant donné la base en version 4 (spec 004), quand l'app s'ouvre avec cette version, alors la base passe en version 5 sans perte : chaque entrée garde son humeur, son texte, sa date, son statut et ses étiquettes, et n'a aucun sujet ; le réglage « bienvenue vue » (spec 009) est créé à faux.
- CA10 : Étant donné une entrée avec des sujets, quand elle est supprimée (spec 001, CA19), alors ses sujets sont effacés avec elle ; après une suppression totale (spec 005), plus aucun sujet n'existe.
- CA11 : Étant donné le journal, quand la personne exporte ses données, alors le fichier est au format version 2 : identique à la version 1 (spec 005, « Format »), avec `formatVersion` à `2` et, pour chaque entrée, `topics` après `tags` : la liste des libellés de ses sujets dans l'ordre de la liste, vide sans sujet.

### Coquillage ramassé

- CA12 : Étant donné une humeur de 3 à 5 enregistrée sans détresse, quand l'enregistrement réussit, alors l'écran de saisie est remplacé par la célébration : fond `hero`, un coquillage `mood-n` qui apparaît en 0,7 s, le titre « Coquillage ramassé », la phrase « Ton Ne de la semaine. Il rejoint ta plage, à côté des autres. » (« Ton 1er de la semaine. Il ouvre ta plage. » pour le premier), une rangée des coquillages de la semaine en cours aux couleurs de leurs humeurs, de la plus ancienne à la plus récente (7 au plus, puis « +N »), et le bouton « Continuer ». N compte toutes les entrées de la semaine en cours, celle-ci comprise (comme spec 009, CA9).
- CA13 : Étant donné une humeur de 1 ou 2 enregistrée sans détresse, quand l'enregistrement réussit, alors la célébration est douce : titre « Entrée enregistrée », phrase « Elle rejoint ta plage. », un seul coquillage immobile, sans rangée ni bulles d'air ni apparition animée.
- CA14 : Étant donné une détresse détectée à l'enregistrement (spec 002), quand l'enregistrement réussit, alors l'écran d'aide s'affiche directement, sans célébration (spec 002, CA13 inchangé).
- CA15 : Étant donné une erreur à l'enregistrement, quand elle survient, alors la célébration ne s'affiche pas : la saisie garde le bandeau d'erreur (spec 001, CA14).
- CA16 : Étant donné la célébration, quand la personne touche « Continuer » ou fait un geste de retour, alors la proposition du modèle s'ouvre si elle doit s'ouvrir d'elle-même (RM31, condition de la spec 003 inchangée) ; sinon, l'accueil réapparaît, avec l'entrée en tête de la liste. Remplace « la liste réapparaît » de la spec 001, CA9 et CA10 (elle réapparaît après la célébration), et le moment où la proposition s'ouvre dans la spec 003 (après la célébration, au lieu de juste après l'enregistrement).
- CA17 : Étant donné une erreur à la lecture des entrées de la semaine pour la célébration, quand elle survient, alors la célébration s'affiche avec la phrase « Il rejoint ta plage. », sans rang ni rangée.
- CA18 : Étant donné la célébration, quand un lecteur d'écran la parcourt, alors le titre est annoncé en premier, la rangée s'annonce « N coquillages cette semaine » (« 1 coquillage cette semaine »), le coquillage et les bulles ne sont pas annoncés.
- CA19 : Étant donné le téléphone qui demande de réduire les animations, quand la célébration s'affiche, alors le coquillage apparaît sans animation et aucune bulle d'air ne monte (spec 008, CA9).
- CA20 : Étant donné la taille de texte à 200 % et le thème sombre, quand la célébration et la section « Ce qui a compté » s'affichent, alors rien n'est tronqué et les valeurs sombres des jetons s'appliquent.

## Cas limites et erreurs

- Sujets et détresse : une entrée en détresse garde ses sujets (enregistrés avec elle) ; l'écran d'aide n'en parle pas.
- Sujets et bilan : le bilan ne les compte pas (hors périmètre).
- Un même libellé peut être un sujet et une étiquette (« travail », « nature ») : ils restent dans deux sections distinctes du détail.
- Célébration après la 8e entrée de la semaine : les 7 coquillages les plus récents puis « +1 ».
- Sujet inconnu en base (version plus récente de l'app puis retour arrière) : il est ignoré à la lecture et à l'export, sans rendre le journal illisible.

## Hors périmètre

- Sujets personnalisés, ajout ou retrait de sujets dans la liste.
- Sujets dans le bilan de la semaine ou transmis au modèle.
- Modification des sujets après l'enregistrement (RM15).
- Récompenses, séries, badges : la célébration ne compare jamais à un objectif.

## Maquette

Voir la [spec 008](008-charte-ludique.md#maquette) : écrans `Saisie` (section « Ce qui a compté »), `Detail`, `Enregistre`, `EnregistreDoux`, dans [`docs/maquettes/008-refonte-ludique/`](../maquettes/008-refonte-ludique/).

## Questions ouvertes

Aucune. Décisions de l'agent, par délégation de Yanis : célébration douce pour les humeurs 1 et 2 ; les sujets s'ajoutent aux étiquettes du modèle sans les remplacer ; liste fixe de six sujets.
