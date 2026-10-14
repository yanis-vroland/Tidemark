# Maquette de la spec 001 : saisie et liste des entrées

Copie versionnée de l'artefact Claude de type « Design » ([lien privé](https://claude.ai/artifact/Nokoan8KiMNxU6n2UBwipG)), construit sur la [charte](../000-charte/). **Cette copie fait foi.** Spec : [`docs/specs/001-saisie-et-liste-des-entrees.md`](../../specs/001-saisie-et-liste-des-entrees.md).

Statut : **validée par Yanis le 2026-10-14.**

| Écran | Fichiers (artboards) | Critères |
| --- | --- | --- |
| Saisie | `Main` (nominal), `Vide`, `Chargement`, `Erreur`, `Sombre` | CA7 à CA15, CA26, CA28 |
| Liste | `Liste` (entrées), `ListeVide`, `ListeSombre` | CA1 à CA6, CA28 |
| Détail | `Detail` (avec texte), `DetailSansTexte`, `DetailConfirmation`, `DetailSombre` | CA16 à CA20, CA28 |

Format : un fichier `.dc.html` par écran (format « Design Component » de l'artefact) et `canvas.json`, l'index du canevas. Les fichiers sans contenu propre (`Vide`, `ListeVide`…) importent l'écran principal avec une variante. Ils se lisent comme du HTML, mais ne s'affichent tels quels que dans l'artefact, qui fournit le script `support.js` qu'ils chargent (non versionné).

Données d'exemple fictives, datées du mercredi 14 octobre 2026.

## Limites

- Captures PNG : absentes. L'extension Chrome n'était pas connectée ; à exporter depuis l'artefact (Partager, Exporter).
- Compteur de caractères (CA12) et écran de lancement natif (CA29) : pas dessinés, décrits par la spec. Le compteur est placé dans la zone fixe du bas, au-dessus du bouton, pour rester visible sous un long texte.
- États chargement et erreur de la liste (CA31, CA32) : pas dessinés ; titre seul, puis message d'erreur en `danger` sur le modèle du bandeau d'erreur.
- Anneau de focus et couleur des liens écrits en dur avec la valeur claire de `tide` : faux en thème sombre. Sans effet sur l'app, qui prend ces couleurs dans le thème ; à corriger dans l'artefact.
- États sombres de l'erreur, de la confirmation, de l'état vide et du bouton désactivé : pas dessinés ; l'app les rend avec les jetons sombres, vérifiés par les tests de CA28.
