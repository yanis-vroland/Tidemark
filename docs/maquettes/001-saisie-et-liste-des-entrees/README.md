# Maquette de la spec 001 : saisie et liste des entrées

Copie versionnée de l'artefact Claude de type « Design » ([lien privé](https://claude.ai/artifact/Nokoan8KiMNxU6n2UBwipG)), construit sur la [charte](../000-charte/). **Cette copie fait foi.** Spec : [`docs/specs/001-saisie-et-liste-des-entrees.md`](../../specs/001-saisie-et-liste-des-entrees.md).

Statut : **en attente de validation par Yanis.**

| Écran | Fichiers (artboards) | Critères |
| --- | --- | --- |
| Saisie | `Main` (nominal), `Vide`, `Chargement`, `Erreur`, `Sombre` | CA7 à CA15, CA26, CA28 |
| Liste | `Liste` (entrées), `ListeVide`, `ListeSombre` | CA1 à CA6, CA28 |
| Détail | `Detail` (avec texte), `DetailSansTexte`, `DetailConfirmation`, `DetailSombre` | CA16 à CA20, CA28 |

Format : un fichier `.dc.html` par écran (format « Design Component » de l'artefact) et `canvas.json`, l'index du canevas. Les fichiers sans contenu propre (`Vide`, `ListeVide`…) importent l'écran principal avec une variante. Ils se lisent comme du HTML, mais ne s'affichent tels quels que dans l'artefact.

Données d'exemple fictives, datées du mercredi 14 octobre 2026.

## Limites

- Captures PNG : ajoutées après validation, avant les tests.
- Compteur de caractères (CA12) et écran de lancement natif (CA29) : pas dessinés, décrits par la spec.
