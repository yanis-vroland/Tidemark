# Spec 007 : logo

Statut : brouillon ; logo C choisi par Yanis le 2026-10-19, critères à valider avec la PR
Date : 2026-10-19

## Besoin

En tant que personne qui tient son journal, je veux reconnaître Tidemark sur l'écran d'accueil de mon téléphone et au lancement, afin de retrouver l'app d'un coup d'œil.

En tant que Yanis, je veux que Tidemark ait une identité visuelle (logo, icône de l'app, visuel du dépôt), afin que le projet soit reconnaissable par un recruteur, comme FieldOps.

Constat (2026-10-19) : l'icône est celle de Flutter par défaut, l'écran de lancement un fond uni, et la charte dit « Pas de logo pour l'instant ».

Maquette : voir « Maquette ». Charte : [`docs/maquettes/000-charte/`](../maquettes/000-charte/).

## Le logo

Proposition C, « T de marée » (choisie par Yanis le 2026-10-19, contre la recommandation B de l'agent) : un T dont la barre est une vague, et un point couleur sable au pied de la lettre, la laisse que dépose la marée. Une seule géométrie, dans une boîte de 48 × 48 : tuile de rayon 11 ; vague de (10, 16) à (38, 16), quatre demi-ondes de 7 de large et 3,2 de creux ; jambage de (24, 22) à (24, 37) ; trait de 3,2, extrémités et joints arrondis ; point plein de rayon 2,6 en (31,5 ; 37).

Couleurs : trois jetons ajoutés à la charte, identiques dans les deux thèmes (une marque ne change pas de couleur avec le thème) :

| Jeton | Valeur | Usage |
| --- | --- | --- |
| `brand` | `#1d5f6b` (`tide` clair) | Tuile du logo |
| `on-brand` | `#ffffff` | Vague et jambage ; tout le symbole dans la version monochrome |
| `brand-accent` | `#e2b55a` (`mood-4` clair) | Point de la laisse |

Un script, `tool/generate_brand.py`, sans dépendance, produit depuis cette géométrie et `tokens.json` les SVG de la charte, les icônes de l'app et les images de l'écran de lancement. Dans l'app, le widget `TidemarkLogo` redessine le logo avec les mêmes coordonnées.

## Critères d'acceptation

### Icône et lancement

- CA1 : Étant donné l'app installée, quand la personne regarde l'écran d'accueil du téléphone, alors l'icône de Tidemark est le logo : iOS, toutes les tailles de `AppIcon.appiconset`, sans transparence ; Android, icône adaptative (fond `brand`, symbole en premier plan, version monochrome pour les icônes à thème) et images des anciennes versions d'Android.
- CA2 : Les fichiers de CA1 et de CA3 sont ceux que produit `tool/generate_brand.py`, qui est déterministe : la CI le relance et échoue si un fichier généré diffère de celui du dépôt.
- CA3 : Étant donné l'app lancée à froid, alors l'écran de lancement natif montre le logo au centre, sur le fond `surface` du thème du téléphone, clair ou sombre (iOS, Android ; Android 12 et plus : écran de lancement du système, même fond et même symbole). Complète le CA29 de la spec 001.

### Dans l'app

- CA4 : Étant donné aucune entrée, quand la liste affiche son état vide (spec 001, CA1), alors le logo (64 points) est affiché au-dessus de « Ta première entrée apparaîtra ici », en clair et en sombre ; le titre « Ton journal » et l'icône « Réglages » ne changent pas.
- CA5 : Le logo est décoratif : il n'est pas annoncé par le lecteur d'écran.
- CA6 : `TidemarkLogo` ne prend ses couleurs que dans les jetons `brand`, `on-brand` et `brand-accent` (garde-fou des couleurs en dur et test de fidélité à la charte).
- CA7 : Étant donné une liste avec au moins une entrée, alors le logo n'est pas affiché.

### Charte et dépôt

- CA8 : La charte contient le composant `Logo` (aperçu HTML, README, captures en clair et en sombre), les SVG du logo dans `docs/maquettes/000-charte/logo/` (couleur, monochrome) et les trois jetons de la section « Le logo » ; `charte.md` remplace « Pas de logo pour l'instant » par les règles d'usage.
- CA9 : Le README affiche le logo en tête, et le dépôt fournit le visuel de partage GitHub (`docs/maquettes/000-charte/logo/tidemark-social-preview.png`, 1280 × 640).

## Cas limites

- Texte agrandi à 200 % : le logo garde sa taille ; l'état vide défile comme avant.
- Thème sombre : la tuile reste `brand` ; sur `surface` sombre, elle se détache par sa couleur, sans contour.

## Hors périmètre

- Animation de l'écran de lancement.
- Logo sur d'autres écrans que l'état vide de la liste.
- Pose du visuel de partage dans les réglages GitHub du dépôt : à faire par Yanis (aucune API ne le permet).
- Changement du nom affiché sous l'icône (« Tidemark », inchangé).

## Maquette

Artefact « Design » [Tidemark : logo](https://claude.ai/artifact/5B1a26iJZs9jKyu7XcVEJ4) (privé) : les trois propositions (A « Laisses », B « Lune et marée », C « T de marée ») à 140, 60, 40 et 24 px, avec le nom, sur fond clair et sombre ; écran de lancement et liste vide en clair et en sombre ; icône sur un écran d'accueil. Copie versionnée dans `docs/maquettes/007-logo/` après validation.

## Questions ouvertes

Aucune. Choix du logo : C, par Yanis (2026-10-19).
