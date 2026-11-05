Tidemark est un journal d'humeur dont l'IA tourne sur le téléphone. **Charte v2** (spec 008, 2026-11-05) : chaleureuse et ludique, pour donner envie d'y revenir chaque jour, sans infantiliser ni juger. Une personne y note parfois une bonne soirée, parfois une mauvaise journée, parfois une vraie détresse.

Le principe : **la marée de ton humeur**. Chaque humeur est une bulle dont le niveau d'eau monte avec elle ; chaque entrée dépose un coquillage sur la plage de la semaine ; les vagues bougent doucement. La laisse de mer (*tidemark*) reste l'image : la ligne que la marée laisse sur le sable, jour après jour.

## Ton et rédaction

- Tutoie la personne, comme l'accroche : « Rien ne quitte ton téléphone. »
- Phrases courtes, verbes concrets. Un bouton dit ce qu'il fait : « Enregistrer », « Tout supprimer », « Télécharger le modèle (1,2 Go) ».
- Jamais de conseil médical, de diagnostic ni de jugement sur l'humeur. On décrit, on ne prescrit pas : « 3 jours à 2 cette semaine », pas « tu devrais te reposer ».
- Pas d'émoji, pas de point d'exclamation enthousiaste. Le jeu passe par le dessin (bulles, coquillages, vagues), pas par le ton.
- Les libellés d'humeur sont fixes : 1 « Très bas », 2 « Bas », 3 « Neutre », 4 « Bien », 5 « Très bien ».
- La confidentialité se dit en clair, au bon endroit : « Analysé sur ton téléphone » sous les étiquettes, jamais en slogan répété partout.

## Couleurs

- Fond de chaque écran : `surface`, un sable clair (sombre : nuit marine). Cartes, feuilles et champs en `surface-raised`.
- Texte principal en `ink`, secondaire en `ink-muted` : 4,5:1 au moins sur `surface`, `surface-raised` et les fonds `mood-n-night`, dans les deux thèmes.
- `tide` reste la seule couleur d'action : bouton principal, lien, focus, sélection. Un écran n'a qu'un bouton plein en `tide`, posé sur `shadow-press`.
- Scènes : `hero` (mer de l'accueil et de la célébration, texte `on-hero`), `sky` (ciel du bilan et de la bienvenue, texte `on-sky`), `sea`, `sand` (plage, texte `on-sand`), `sun`, `moon`. Toujours décoratives.
- `danger` est réservé aux erreurs et à la suppression totale, toujours avec un libellé.

### Échelle d'humeur

`mood-1` à `mood-5` vont de l'indigo (marée basse) à l'orangé (soleil) : c'est l'eau des bulles et la couleur des coquillages. `mood-n-soft` est le fond d'une bulle et d'une carte d'entrée (texte `on-mood`) ; `mood-n-night` le fond de l'écran de saisie quand l'humeur est choisie. Ces couleurs sont les mêmes dans les deux thèmes : une bulle est un personnage, elle ne change pas avec le thème.

## La bulle

Composant `MoodBubble` : un disque `mood-n-soft`, de l'eau `mood-n` jusqu'à 17, 32, 48, 64 ou 79 % du diamètre, un reflet `bubble-shine` et un visage en `on-mood` (sourcils tombants et larme `bubble-tear` à 1 ; bouche tombante à 2 ; droite à 3 ; sourire et joues `bubble-cheek` à 4 ; yeux plissés, grand sourire et étincelle à 5). L'humeur ne repose jamais sur la couleur seule : le niveau d'eau et le visage changent aussi. La bulle est muette pour le lecteur d'écran : son libellé est écrit à côté ou dans l'annonce du parent. Elle remplace la pastille chiffrée de la v1.

Tailles : `bubble-sm` (plage), `bubble-md` (carte), `bubble-check` (check-in), `bubble-select` et `bubble-select-on` (sélecteur, avec un anneau `tide`), `bubble-lg` (détail), `bubble-xl` (saisie).

## Autocollants

Étiquettes, sujets, chiffres du bilan : un fond plein, `radius-pill` ou `radius-lg`, l'ombre `shadow-sticker` et une légère rotation, entre −3° et +3°, toujours la même pour un même texte. Un autocollant n'a aucune action propre (RM58).

## Typographie

- Deux familles : `display` (Bricolage Grotesque) pour les titres et les chiffres, `body` (Figtree) pour le reste. Les deux sont sous licence OFL et **embarquées dans l'app** : aucune police chargée depuis le réseau.
- `display` (40, graisse 800) : un seul par écran, pour le titre principal ou la salutation. `title` pour les sections, `stat` pour un chiffre d'autocollant, `sticker` pour le texte d'un autocollant.
- `body` pour le texte des entrées ; `caption` pour les dates et les mentions de confidentialité ; `label` pour les onglets et les puces ; `button` pour les boutons pleine largeur.
- Toutes les tailles suivent la taille de texte choisie dans les réglages du téléphone : rien ne doit être tronqué à 200 %. Les bulles, sans texte, gardent leur taille.

## Espacements, rayons et cibles

- Marge latérale des écrans : `space-4`. Écart entre sections : `space-6`.
- Cartes en `radius-lg`, carte du check-in et barre de navigation en `radius-xl`, champs en `radius-sm`, boutons, puces et bulles en `radius-pill`.
- Ombres : `shadow-card` pour ce qui flotte au-dessus d'une scène (check-in, barre de navigation), `shadow-sticker` pour les autocollants, `shadow-press` sous les boutons pleins.
- Toute cible tactile mesure au moins `tap-min` (44 px).

## États

Chaque écran dessine ses états vide, chargement et erreur :

- **Vide** : une phrase qui dit quoi faire (« Ta première entrée apparaîtra ici »), et le bouton pour le faire.
- **Chargement** : le modèle travaille sur le téléphone, et ça se dit (« Analyse en cours sur ton téléphone… »). Pas de squelette qui clignote plus de quelques secondes.
- **Erreur** : ce qui s'est passé et quoi faire, en `danger` pour le titre seulement.

## Mouvement

Les animations **d'ambiance** tournent en boucle : houle de l'eau des bulles (3,2 s), flottement des bulles (3,4 s), vagues des en-têtes (9 et 15 s), tangage du voilier (4 s), bulles d'air de la saisie et de la célébration (8 s). L'apparition du coquillage de la célébration dure 0,7 s, une fois.

Elles ne tournent que si l'app les autorise (`AmbientMotion`, activé par `main`) **et** si le téléphone ne demande pas de réduire les animations : sinon, tout est dessiné immobile, dans sa position de repos (RM66).

## L'écran d'aide fait exception

L'écran d'aide (3114) reste calme : aucune bulle, aucun autocollant pivoté, aucune animation, aucune célébration. Il garde `ink` sur `surface`, le numéro en grand et un seul bouton `tide` pour appeler ; `danger` n'y sert pas. Le jeu de la charte v2 s'arrête là où commence une détresse.

## Iconographie

Jeu d'icônes : **Material Icons** de Flutter (`Icons.*`), police embarquée dans l'app par `uses-material-design: true` (`pubspec.yaml`), licence Apache-2.0, compatible avec un dépôt public ; aucune icône chargée depuis le réseau (choix confirmé par Yanis le 2026-10-16). Couleur et taille viennent des jetons (couleurs de texte, `icon-sm`, `icon-md`, `icon-button`). Le logo est la seule image de marque (voir « Logo »).

## Logo

Logo C « T de marée » (spec 007, choisi par Yanis le 2026-10-19) : un T dont la barre est une vague, et un point couleur sable au pied de la lettre, la laisse que dépose la marée. Composant [`Logo`](components/Logo/README.md), fichiers dans [`logo/`](logo/).

- Tuile `brand`, vague et jambage `on-brand`, point `brand-accent` : la marque ne change pas de couleur avec le thème. Monochrome : tout en `ink` clair.
- Où : icône de l'app, écran de lancement, état vide de la liste (`logo-md`), README et visuel de partage du dépôt. Nulle part ailleurs : un écran a déjà son titre en `display`.
- Toujours décoratif dans l'app : le lecteur d'écran ne l'annonce pas.
- Une seule géométrie, dans `tool/generate_brand.py`, qui écrit les SVG, les icônes et l'écran de lancement ; `TidemarkLogo` la redessine avec les mêmes coordonnées. Ne jamais redessiner le symbole à la main.
