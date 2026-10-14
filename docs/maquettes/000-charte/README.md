# Charte Tidemark (lot C)

Copie versionnée de la charte, faite en artefact Claude de type « Design System » ([lien privé](https://claude.ai/artifact/LxwwPXPaLTB1ciS6m7NVeu), visible seulement par Yanis). **Cette copie fait foi** ([plan](../../plan.md#maquettes-en-artefacts-claude)) ; l'artefact sert à l'explorer et à la commenter.

Statut : **en attente de validation par Yanis.**

## Contenu

| Fichier | Rôle |
| --- | --- |
| [`charte.md`](charte.md) | Règles d'usage : ton, couleurs, typographie, espacements, états, mouvement |
| [`tokens.json`](tokens.json) | Jetons : 16 couleurs en thème clair et sombre, 7 styles de texte, espacements, rayons, tailles. Le lot D les transcrit en constantes Dart de même nom (`lib/ui/theme/`) |
| [`components/`](components/) | 7 composants, chacun avec son aperçu HTML (jetons seulement) et son README |

Composants : sélecteur d'humeur (`MoodSelector`), carte d'entrée (`EntryCard`), puce d'étiquette (`TagChip`), bouton (`Button`), champ de texte (`TextField`), bandeau d'erreur (`ErrorBanner`), mention de chargement (`LoadingNote`). `components/Cover/` est la couverture de l'artefact.

## Inventaire des écrans du MVP

| Écran | Lot | Composants |
| --- | --- | --- |
| Liste des entrées, avec état vide | E | `EntryCard`, `Button` |
| Saisie d'une entrée | E | `MoodSelector`, `TextField`, `Button`, `ErrorBanner` |
| Détail d'une entrée et ses étiquettes | E, G | `TagChip`, `LoadingNote`, `Button` |
| Écran d'aide (3114) | F | `Button` ; sans `danger` |
| Téléchargement du modèle | G | `Button`, `LoadingNote`, `ErrorBanner` |
| Réglages : export, suppression totale | H | `Button` (secondaire, destructif) |
| Bilan de la semaine | I | à définir avec sa spec |

Une maquette d'exploration de la saisie existe ([artefact privé](https://claude.ai/artifact/Nokoan8KiMNxU6n2UBwipG)) : elle sera reprise avec la spec du lot E, puis copiée dans `docs/maquettes/`.

## Contrastes

Calculés selon WCAG 2 à partir de `tokens.json`. Seuil de 4,5:1 pour le texte, de 3:1 pour les bordures de contrôle et pour les chiffres gras de 19 px au moins posés sur les pastilles d'humeur.

| Texte ou trait | Fond | Seuil | Clair | Sombre |
| --- | --- | --- | --- | --- |
| `ink` | `surface` | 4.5:1 | 14.3:1 | 15.1:1 |
| `ink` | `surface-raised` | 4.5:1 | 15.5:1 | 13.3:1 |
| `ink` | `tide-soft` | 4.5:1 | 12.5:1 | 10.5:1 |
| `ink-muted` | `surface` | 4.5:1 | 6.3:1 | 7.9:1 |
| `ink-muted` | `surface-raised` | 4.5:1 | 6.8:1 | 7.0:1 |
| `tide` | `surface` | 4.5:1 | 6.7:1 | 9.1:1 |
| `tide` | `surface-raised` | 4.5:1 | 7.2:1 | 8.0:1 |
| `on-tide` | `tide` | 4.5:1 | 7.2:1 | 8.4:1 |
| `danger` | `surface` | 4.5:1 | 6.1:1 | 8.0:1 |
| `danger` | `surface-raised` | 4.5:1 | 6.6:1 | 7.1:1 |
| `line` | `surface` | 3:1 | 3.4:1 | 3.6:1 |
| `line` | `surface-raised` | 3:1 | 3.7:1 | 3.2:1 |
| `on-mood-1` | `mood-1` | 3:1 | 8.1:1 | 7.1:1 |
| `on-mood` | `mood-2` | 3:1 | 4.1:1 | 6.4:1 |
| `on-mood` | `mood-3` | 3:1 | 6.6:1 | 8.2:1 |
| `on-mood` | `mood-4` | 3:1 | 8.1:1 | 10.2:1 |
| `on-mood` | `mood-5` | 3:1 | 6.3:1 | 8.2:1 |

Toutes les paires passent leur seuil.

## Polices et icônes

- **Bricolage Grotesque** (titres, chiffre d'humeur) et **Figtree** (texte) : SIL Open Font License 1.1, publiées sur Google Fonts. Les aperçus HTML les chargent depuis Google Fonts ; l'app les embarque (lot D) et ne charge aucune police depuis le réseau (RM1).
- Icônes : seul un cadenas, dessiné en SVG dans les aperçus. Le jeu d'icônes de l'app (embarquable, licence compatible) est à choisir au lot D.

## Limites

- Pas encore de captures PNG des composants : l'artefact est privé et les aperçus se rendent dans son interface. Elles seront ajoutées avec la première spec qui touche un écran (lot E).
- Les composants sont des aperçus HTML, pas une bibliothèque : le lot D les recrée en widgets Flutter à partir des jetons.
