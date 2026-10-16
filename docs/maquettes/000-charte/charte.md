Tidemark est un journal d'humeur dont l'IA tourne sur le téléphone. La charte doit inspirer le calme et la confiance, sans infantiliser : une personne y note parfois une mauvaise journée, parfois une vraie détresse. La laisse de mer (*tidemark*) donne l'image : la ligne que la marée laisse sur le sable, jour après jour.

## Ton et rédaction

- Tutoie la personne, comme l'accroche : « Rien ne quitte ton téléphone. »
- Phrases courtes, verbes concrets. Un bouton dit ce qu'il fait : « Enregistrer », « Tout supprimer », « Télécharger le modèle (1,2 Go) ».
- Jamais de conseil médical, de diagnostic ni de jugement sur l'humeur. On décrit, on ne prescrit pas : « 3 jours à 2 cette semaine », pas « tu devrais te reposer ».
- Pas d'émoji, pas de point d'exclamation enthousiaste.
- Les libellés d'humeur sont fixes : 1 « Très bas », 2 « Bas », 3 « Neutre », 4 « Bien », 5 « Très bien ».
- La confidentialité se dit en clair, au bon endroit : « Analysé sur ton téléphone » sous les étiquettes, jamais en slogan répété partout.

## Couleurs

- Chaque écran a pour fond `surface`. Les cartes, feuilles et champs sont en `surface-raised`.
- Texte principal en `ink`, texte secondaire en `ink-muted`. Les deux tiennent 4,5:1 sur `surface` et `surface-raised`, dans les deux thèmes.
- `tide` est la seule couleur d'action : bouton principal, lien, focus, sélection. Un écran n'a qu'un bouton plein en `tide`. Le texte posé dessus est en `on-tide`.
- `tide-soft` sert de fond aux puces d'étiquette et aux options sélectionnées.
- `line` borde les champs et les contrôles (3:1 au moins), et colore l'icône d'une flèche désactivée. Pas d'ombre pour séparer des blocs : un fond `surface-raised` sur `surface` suffit.
- `danger` est réservé aux erreurs et à la suppression totale, toujours avec un libellé. L'écran d'aide (3114) n'utilise **pas** `danger` : il reste calme, en `ink` sur `surface`, avec le numéro en `title` et un bouton `tide` pour appeler.

### Échelle d'humeur

`mood-1` à `mood-5` vont du bleu ardoise (marée basse) au sable chaud. Une pastille d'humeur n'est jamais seule : elle porte son chiffre (`mood-numeral`, en `on-mood-1` sur `mood-1`, en `on-mood` sur les autres) et son libellé est lisible à côté ou par le lecteur d'écran. La couleur ne porte donc jamais l'information à elle seule.

## Typographie

- Deux familles : `display` (Bricolage Grotesque) pour les titres et le chiffre d'humeur, `body` (Figtree) pour tout le reste. Les deux sont sous licence OFL et sont **embarquées dans l'app** : aucune police chargée depuis le réseau.
- `display` : un seul par écran, pour le titre principal.
- `body` pour le texte des entrées ; `caption` pour les dates et les mentions de confidentialité ; `label` pour les boutons et les puces.
- Toutes les tailles suivent la taille de texte choisie dans les réglages du téléphone : rien ne doit être tronqué à 200 %.

## Espacements, rayons et cibles

- Marge latérale des écrans : `space-4`. Écart entre sections : `space-6`.
- Cartes en `radius-md`, champs en `radius-sm`, boutons, puces et pastilles en `radius-pill`.
- Toute cible tactile mesure au moins `tap-min` (44 px). Les pastilles du sélecteur d'humeur font `mood-dot`.

## États

Chaque écran dessine ses états vide, chargement et erreur :

- **Vide** : une phrase qui dit quoi faire (« Ta première entrée apparaîtra ici »), et le bouton pour le faire.
- **Chargement** : le modèle travaille sur le téléphone, et ça se dit (« Analyse en cours sur ton téléphone… »). Pas de squelette qui clignote plus de quelques secondes.
- **Erreur** : ce qui s'est passé et quoi faire, en `danger` pour le titre seulement.

## Mouvement

Peu d'animations, toutes utiles : la pastille choisie grossit légèrement, les écrans glissent. Tout mouvement est coupé quand le téléphone demande de réduire les animations.

## Iconographie

Jeu d'icônes : **Material Icons** de Flutter (`Icons.*`), police embarquée dans l'app par `uses-material-design: true` (`pubspec.yaml`), licence Apache-2.0, compatible avec un dépôt public ; aucune icône chargée depuis le réseau (choix confirmé par Yanis le 2026-10-16). Couleur et taille viennent des jetons (couleurs de texte, `icon-sm`, `icon-md`, `icon-button`). Pas de logo pour l'instant : le nom s'écrit en `display`.
