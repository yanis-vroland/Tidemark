# Spec 008 : charte ludique

Statut : proposée (rédigée par l'agent en autonomie, à la demande de Yanis du 2026-11-05 ; validation au merge de la PR, [issue #48](https://github.com/yanis-vroland/Tidemark/issues/48))
Date : 2026-11-05

## Besoin

En tant que personne qui tient son journal, je veux une app chaleureuse et amusante à ouvrir chaque jour, afin d'avoir envie d'y revenir.

Constat de Yanis (2026-11-05) : le design est « trop vide, trop fade, trop simple » pour un public large. Une refonte ludique a été maquettée puis validée (« on garde tout ») : [maquette](#maquette).

Le principe : **la marée de ton humeur**. Chaque humeur est une bulle à visage, dont le niveau d'eau monte avec l'humeur. Les vagues bougent doucement. Cette spec fixe la charte v2 et l'applique à tous les écrans existants, sauf l'écran d'aide. Les nouveaux parcours sont dans les specs [009](009-accueil-et-navigation.md) (accueil, navigation, bilan) et [010](010-ce-qui-a-compte-et-coquillage.md) (sujets, célébration).

## La charte v2

Elle remplace la charte v1 dans [`docs/maquettes/000-charte/`](../maquettes/000-charte/) : `tokens.json` (version 2), `charte.md`, et l'artefact « Design System » Tidemark. Les jetons non cités ici gardent leur valeur v1.

### Couleurs (clair / sombre)

| Jeton | Clair | Sombre | Usage |
| --- | --- | --- | --- |
| `surface` | `#f7f3ec` | `#0c1719` | Fond de chaque écran : sable clair, plus chaud que v1. |
| `surface-raised` | `#ffffff` | `#15252a` | Cartes, feuilles, champs. |
| `ink` | `#14262b` | `#e6efed` | Texte principal. |
| `ink-muted` | `#4b5e64` | `#b4c5c5` | Texte secondaire. |
| `line` | `#76898d` | `#7d9599` | Bordures, contours pointillés. |
| `mood-1` à `mood-5` | `#5868ad`, `#6b93d3`, `#62b3a5`, `#f0b84a`, `#f78b52` | mêmes valeurs | Eau d'une bulle, coquillage. Identiques dans les deux thèmes : une bulle est un personnage, il ne change pas avec le thème. |
| `mood-1-soft` à `mood-5-soft` | `#dfe3f6`, `#dde9f9`, `#d9f1eb`, `#fdf0cf`, `#ffe2d1` | mêmes valeurs | Fond d'une bulle, d'une carte d'entrée, de l'écran de saisie (clair). |
| `on-mood` | `#14262b` | `#14262b` | Texte, visage et icône posés sur une couleur `mood-*` ou `mood-*-soft`, dans les deux thèmes. |
| `mood-1-night` à `mood-5-night` | `#e9ebf5`, `#e8eff8`, `#e6f2ee`, `#fbf2dc`, `#fde9dc` | `#1a2136`, `#172536`, `#142a29`, `#2c271c`, `#30231d` | Fond de l'écran de saisie selon l'humeur choisie. |
| `bubble-cheek` | `#ff8f7d` | mêmes valeurs | Joues des bulles 4 et 5. |
| `bubble-tear` | `#8fc1ef` | mêmes valeurs | Larme de la bulle 1. |
| `bubble-shine` | `#ffffff` | mêmes valeurs | Reflet d'une bulle, écume des vagues. |
| `hero` | `#1d5f6b` | `#0f3a41` | Fond de l'en-tête de l'accueil (mer), de la célébration. |
| `hero-wave-1`, `hero-wave-2` | `#2a7480`, `#3b8b93` | `#13454c`, `#185058` | Vagues de l'en-tête. |
| `on-hero` | `#ffffff` | `#ffffff` | Texte sur `hero`. |
| `on-hero-muted` | `#d5ebea` | `#c9dfdf` | Texte secondaire sur `hero`. |
| `sky` | `#cfe9ec` | `#0f2d3d` | Ciel de l'en-tête du bilan et de la bienvenue. |
| `on-sky` | `#0f3f48` | `#e6efed` | Texte sur `sky`. |
| `sea` | `#3b8b93` | `#1d5f6b` | Mer de la plage et du bilan. |
| `sun` | `#fdd77a` | mêmes valeurs | Soleil (jour). |
| `moon` | `#fdf0cf` | mêmes valeurs | Lune et étoiles (soir). |
| `sand` | `#f6e4bd` | `#3a3222` | Sable de la plage. |
| `on-sand` | `#6b5320` | `#e8d9b5` | Texte sur `sand`. |

`tide`, `on-tide`, `tide-soft`, `danger`, `brand`, `on-brand`, `brand-accent` sont inchangés. `on-mood-1` et le chiffre d'humeur disparaissent avec la pastille numérotée.

### Typographie

| Style | Famille | Taille / interligne | Graisse | Usage |
| --- | --- | --- | --- | --- |
| `display` | display | 40 / 44, approche −1 | 800 | Titre principal, une fois par écran. |
| `title` | display | 22 / 28 | 700 | Titre de section ou de carte. |
| `stat` | display | 30 / 34 | 800 | Chiffre d'un autocollant du bilan. |
| `headline` | body | 17 / 24 | 600 | Inchangé. |
| `body` | body | 16 / 24 | 400 | Inchangé. |
| `button` | body | 17 / 20 | 700 | Libellé des boutons pleine largeur. |
| `label` | body | 14 / 20 | 600 | Boutons, onglets, puces. |
| `sticker` | body | 15 / 20 | 700 | Texte d'un autocollant. |
| `caption` | body | 13 / 18 | 400 | Inchangé. |

`mood-numeral` est retiré.

### Formes, ombres et tailles

- Rayons : `radius-sm` 8, `radius-md` 16, `radius-lg` 24 (cartes), `radius-xl` 28 (carte du check-in, barre de navigation), `radius-pill`.
- Ombres : `shadow-card` (0, 12, flou 32, `ink` clair à 12 %), `shadow-sticker` (0, 3, sans flou, `ink` clair à 14 %), `shadow-press` (ombre intérieure en bas de 4 points, noir à 18 %, sur les boutons pleins).
- Tailles : `tap-min` 44, `button-height` 56, `bubble-sm` 36 (plage), `bubble-md` 48 (carte d'entrée), `bubble-check` 54 (check-in), `bubble-select` 44 et `bubble-select-on` 52 (sélecteur), `bubble-lg` 120 (détail), `bubble-xl` 150 (saisie), `nav-bubble` 64 (bouton « Nouvelle entrée »), et les tailles v1 `icon-*`, `progress-height`, `ring-width`, `bar-thickness`, `day-cell`, `logo-md`. `mood-dot`, `mood-dot-sm`, `mood-dot-lg` et l'opacité `mood-dimmed` sont retirés.
- Autocollant : fond plein, `radius-pill` ou `radius-lg`, `shadow-sticker`, légère rotation entre −3° et +3°, fixe pour un même élément.

### Mouvement

| Animation | Durée | Où |
| --- | --- | --- |
| Houle (l'eau d'une bulle se déplace) | 3,2 s, en boucle | Bulles |
| Flottement (la bulle monte de 3 points et redescend) | 3,4 s, en boucle, décalée par bulle | Bulles |
| Vagues (translation horizontale) | 9 s et 15 s, en boucle | En-têtes |
| Tangage (le voilier) | 4 s, en boucle | En-tête du soir |
| Bulles d'air qui montent | 8 s, en boucle | Saisie, célébration |
| Apparition du coquillage | 0,7 s, une fois | Célébration |

Les animations en boucle sont dites **d'ambiance**. Elles ne tournent que si l'app les autorise (`AmbientMotion`, activé par `main`) **et** si le téléphone ne demande pas de réduire les animations. Sinon, chaque élément est dessiné immobile, dans sa position de repos.

## La bulle de marée

Composant `MoodBubble(mood, size)`, qui remplace `MoodDot` partout. Un disque `mood-n-soft`, rempli d'eau `mood-n` jusqu'à un niveau qui monte avec l'humeur, avec un reflet et un visage en `on-mood` :

| Humeur | Niveau d'eau (part du diamètre, depuis le bas) | Visage |
| --- | --- | --- |
| 1 « Très bas » | 17 % | Sourcils tombants, bouche en creux, une larme `bubble-tear` |
| 2 « Bas » | 32 % | Petite bouche tombante |
| 3 « Neutre » | 48 % | Bouche droite |
| 4 « Bien » | 64 % | Sourire, joues `bubble-cheek` |
| 5 « Très bien » | 79 % | Yeux plissés, grand sourire, joues, une étincelle `bubble-shine` |

L'humeur ne repose donc jamais sur la couleur seule : le niveau d'eau et le visage changent aussi. La bulle est décorative : le libellé de l'humeur est toujours écrit à côté ou dans la sémantique du parent.

## Critères d'acceptation

### Charte

- CA1 : Étant donné `docs/maquettes/000-charte/tokens.json` en version 2, quand les tests s'exécutent, alors chaque jeton (couleurs des deux thèmes, styles de texte, espacements, rayons, tailles, ombres) a sa constante Dart de même nom et de même valeur dans `lib/ui/theme/`, et inversement : aucune constante orpheline, aucun jeton retiré encore présent (`mood-numeral`, `mood-dot*`, `mood-dimmed`, `on-mood-1`).
- CA2 : Étant donné le code de `lib/`, quand le garde-fou des couleurs s'exécute, alors aucune couleur n'est écrite en dur hors de `lib/ui/theme/`, y compris dans les peintres des bulles, des vagues et des coquillages.
- CA3 : Étant donné les paires de contraste de la section « Contrastes », quand les tests les calculent depuis `tokens.json`, alors chaque paire atteint son seuil, dans les deux thèmes.
- CA4 : Étant donné `charte.md`, quand on le lit, alors il décrit la charte v2 : principe de la marée, bulle, autocollants, mouvement et sa coupure, et l'exception de l'écran d'aide (CA14).

### Bulle de marée

- CA5 : Étant donné `MoodBubble` pour les humeurs 1 à 5, quand on compare leurs niveaux d'eau, alors ils sont strictement croissants, aux valeurs du tableau à 1 point près ; le visage dessiné dépend de l'humeur (cinq visages distincts).
- CA6 : Étant donné une `MoodBubble`, quand le lecteur d'écran parcourt l'écran, alors elle n'est pas annoncée ; ses couleurs viennent seulement des jetons `mood-n`, `mood-n-soft`, `on-mood`, `bubble-*`.
- CA7 : Étant donné une humeur hors de 1 à 5, quand une `MoodBubble` est construite, alors une erreur d'assertion est levée en mode debug.

### Mouvement

- CA8 : Étant donné un écran avec des éléments d'ambiance (bulles, vagues) dans un `AmbientMotion` activé, quand le téléphone ne demande pas de réduire les animations, alors des animations tournent.
- CA9 : Étant donné le même écran, quand le téléphone demande de réduire les animations (`MediaQuery.disableAnimations`), ou sans `AmbientMotion` activé au-dessus, alors aucune animation ne tourne et les éléments sont à leur position de repos.
- CA10 : Étant donné l'app lancée par `main`, quand elle démarre, alors `AmbientMotion` est activé ; `startApp` et `TidemarkApp` ne l'activent pas d'eux-mêmes, pour que les tests restent déterministes.

### Écrans existants

- CA11 : Étant donné l'écran de saisie (spec 001), quand il s'affiche, alors le sélecteur montre cinq bulles de taille `bubble-select`, celle choisie en `bubble-select-on` avec un anneau `ring-width` ; au-dessus, une grande bulle `bubble-xl` montre l'humeur choisie, ou un cercle pointillé `line` tant qu'aucune n'est choisie ; le fond de l'écran prend la couleur `mood-n-night` de l'humeur choisie, `surface` sans humeur. Les libellés, l'aide « Choisis une humeur pour enregistrer. » et les annonces « Humeur 4 sur 5 : Bien » (spec 001, CA7, CA8, CA26) sont inchangés. Remplace l'aspect décrit par la spec 001, CA8 (pastilles).
- CA12 : Étant donné une carte d'entrée de la liste, quand elle s'affiche, alors elle montre une bulle `bubble-md` à la place de la pastille chiffrée, sur un fond `mood-n-soft` avec le texte en `on-mood` ; ses étiquettes sont des autocollants. Le libellé, l'heure, le texte sur deux lignes et l'annonce de la carte (spec 001, CA4, CA5, CA36 ; RM59) sont inchangés. Remplace « la pastille de l'humeur avec son chiffre » de la spec 001, CA4 et CA5.
- CA13 : Étant donné le détail d'une entrée, quand il s'affiche, alors un en-tête `mood-n-soft` montre la bulle `bubble-lg`, le libellé de l'humeur en `display` et « Humeur 4 sur 5 » ; la date, l'heure, le texte, la section « Étiquettes » et la suppression (spec 001, CA16 à CA20 ; spec 004) sont inchangés. Remplace « la pastille » de la spec 001, CA16.
- CA14 : Étant donné l'écran d'aide (spec 002), quand il s'affiche, avec `AmbientMotion` activé, alors il ne contient aucune bulle, aucun autocollant pivoté, aucune animation d'ambiance ni aucun élément de célébration : il reste calme, comme le veut la spec 002. Seuls les jetons de fond et de texte v2 s'y appliquent.
- CA15 : Étant donné l'écran du modèle (spec 003), quand la proposition s'affiche, alors une illustration décorative (bulle « Neutre » et quatre autocollants d'étiquettes fictives) est au-dessus du titre ; tous les textes et boutons de la spec 003 sont inchangés.
- CA16 : Étant donné les Réglages et la confirmation de suppression totale, quand ils s'affichent, alors ils utilisent les jetons v2 (fond, cartes en `radius-lg`), sans bulle ni animation ; leurs textes sont inchangés.
- CA17 : Étant donné les boutons pleine largeur, quand ils s'affichent, alors ils mesurent `button-height`, en style `button`, avec `shadow-press`.

### Accessibilité

- CA18 : Étant donné la taille de texte du système à 200 %, quand la saisie, la liste, le détail, l'écran du modèle et l'écran d'aide s'affichent, alors aucun texte n'est tronqué ni ne déborde (les écrans défilent).
- CA19 : Étant donné le thème sombre du système, quand ces écrans s'affichent, alors ils prennent les valeurs sombres des jetons.

## Contrastes

Seuils : 4,5:1 pour un texte de moins de 24 points, 3:1 pour un texte de 24 points et plus, une bordure de contrôle ou un élément graphique utile. Paires vérifiées dans les deux thèmes, sauf mention :

| Texte ou élément | Fond | Seuil |
| --- | --- | --- |
| `ink`, `ink-muted` | `surface`, `surface-raised` | 4,5 |
| `on-mood` | `mood-1-soft` à `mood-5-soft` | 4,5 |
| `on-mood` | `mood-3`, `mood-4`, `mood-5` (visage sur l'eau) | 3 |
| `ink`, `ink-muted` | `mood-1-night` à `mood-5-night` | 4,5 |
| `on-hero`, `on-hero-muted` | `hero` | 4,5 |
| `on-sky` | `sky` | 4,5 |
| `on-sand` | `sand` | 4,5 |
| `on-tide` | `tide` | 4,5 |
| `danger` | `surface`, `surface-raised` | 4,5 |
| `line` | `surface`, `surface-raised` | 3 |

Le visage n'est pas posé sur `mood-1` ni `mood-2` : leur eau reste sous les yeux et la bouche.

## Cas limites et erreurs

- Taille de texte agrandie : les bulles gardent leur taille (elles ne contiennent plus de texte).
- Animations coupées en cours d'usage (réglage du téléphone changé) : les animations s'arrêtent à la reconstruction suivante, sans saut visible gênant.
- Écran très étroit : le sélecteur de cinq bulles tient sur 320 points de large (5 × 52 + marges).

## Hors périmètre

- Thèmes choisis par la personne (toujours hors périmètre, cahier des charges).
- Sons, vibrations.
- Animation de l'écran de lancement natif.
- Changement du logo (spec 007).

## Maquette

Artefact « Design » [Tidemark : tous les écrans](https://claude.ai/artifact/FWqBZBnQUYwoCNoCPQrFP5) (privé), page « Refonte · proposition » : bienvenue, journal, saisie, détail, semaine, modèle, aide, célébration (normale et douce), en clair et en sombre, et les composants bulle et barre de navigation. Copie versionnée, qui fait foi : [`docs/maquettes/008-refonte-ludique/`](../maquettes/008-refonte-ludique/). Elle couvre les specs 008, 009 et 010.

## Questions ouvertes

Aucune. Décisions prises par l'agent, par délégation de Yanis (2026-10-16, confirmée le 2026-11-05) : bulles identiques dans les deux thèmes ; écran d'aide exclu de la refonte ludique.
