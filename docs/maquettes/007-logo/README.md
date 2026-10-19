# Maquette de la spec 007 : logo

Copie versionnée de l'artefact Claude de type « Design » ([lien privé](https://claude.ai/artifact/5B1a26iJZs9jKyu7XcVEJ4)), construit sur la [charte](../000-charte/). **Cette copie fait foi.** Spec : [`docs/specs/007-logo.md`](../../specs/007-logo.md).

Statut : **logo C choisi par Yanis le 2026-10-19.**

| Artboard | Contenu | Critères |
| --- | --- | --- |
| `Main` | Les trois propositions (A « Laisses », B « Lune et marée », C « T de marée ») à 140, 60, 40 et 24 px, avec le nom, sur fond clair et sombre, en couleur et en monochrome | CA8 |
| `Logo` | Le logo seul, propriétés `variant`, `size`, `mono` ; importé par les autres artboards | CA6 |
| `Lancement`, `LancementSombre` | Écran de lancement, logo de 112 points au centre sur `surface` | CA3 |
| `ListeVide`, `ListeVideSombre` | État vide de la liste, logo de 64 points au-dessus du titre de l'état vide | CA4, CA5 |
| `Icones` | Les trois propositions sur un écran d'accueil de téléphone (icônes voisines neutres, fictives) | CA1 |

Format : celui des autres maquettes ([001](../001-saisie-et-liste-des-entrees/README.md)). La géométrie du logo C de `Logo.dc.html` est celle de la spec et de `tool/generate_brand.py`, qui fait foi pour les fichiers de l'app.

## Limites

- Captures PNG des écrans : absentes, comme pour les autres maquettes ([issue #20](https://github.com/yanis-vroland/Tidemark/issues/20)). Les rendus du logo lui-même sont les fichiers générés de `../000-charte/logo/`.
- Icône de réglages dessinée à la main dans `ListeVide` (l'app utilise `Icons.settings_outlined`).
