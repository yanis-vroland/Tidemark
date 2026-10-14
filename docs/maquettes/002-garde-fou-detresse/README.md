# Maquette de la spec 002 : garde-fou de détresse

Copie versionnée de l'artefact Claude de type « Design » ([lien privé](https://claude.ai/artifact/Pc9xuXHEV16GeFgqNwqSFB)), construit sur la [charte](../000-charte/). **Cette copie fait foi.** Spec : [`docs/specs/002-garde-fou-detresse.md`](../../specs/002-garde-fou-detresse.md).

Statut : **validée par Yanis le 2026-10-14**, avec les corrections de la revue IA de la PR #14.

| Écran | Fichiers (artboards) | Critères |
| --- | --- | --- |
| Écran d'aide | `Main` (nominal), `AideSombre`, `AideAppelImpossible`, `AideAppelImpossibleSombre` | CA10 à CA13, CA23, CA25, CA26 |
| Réglages | `Reglages` (nominal), `ReglagesSombre`, `ReglagesChargement`, `ReglagesChargementSombre`, `ReglagesErreur`, `ReglagesErreurSombre` | CA17 à CA22, CA24 à CA26 |
| Liste | `ListeAcces`, `ListeAccesSombre` | CA17 |

Format : identique à la [maquette 001](../001-saisie-et-liste-des-entrees/README.md). Les fichiers d'une variante importent l'écran principal ; le script `support.js` est fourni par l'artefact et n'est pas versionné.

Données d'exemple fictives.

## Limites

- Captures PNG : absentes, comme pour la maquette 001 (export depuis l'artefact).
- Lien et anneau de focus écrits en dur avec la valeur claire de `tide` dans la feuille de style de l'artefact, comme pour la maquette 001 : sans effet sur l'app.
- Pas d'état vide ni de chargement pour l'écran d'aide : son contenu est fixe.
- États vide, chargement et erreur de la liste : ceux de la maquette 001, avec l'icône « Réglages » à côté du titre, présent dans tous les états.
- Jetons à ajouter à la charte dans la PR d'implémentation : `icon-md` (24) et `icon-button` (18). Tout le reste suit les jetons existants.
