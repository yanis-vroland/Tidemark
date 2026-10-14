# Maquette de la spec 005 : export et suppression totale

Copie versionnée de l'artefact Claude de type « Design » ([lien privé](https://claude.ai/artifact/Fe2pd6Z9VV6Utfpg59JA9x)), construit sur la [charte](../000-charte/). **Cette copie fait foi.** Spec : [`docs/specs/005-export-et-suppression-totale.md`](../../specs/005-export-et-suppression-totale.md).

Statut : **à valider par Yanis.**

| Écran | Fichiers (artboards) | Critères |
| --- | --- | --- |
| Réglages, section « Mes données » (page entière, 393 × 1 240 : l'écran défile) | `Main` (nominal), `ReglagesSombre`, `ReglagesExportEnCours`, `ReglagesExportEnCoursSombre`, `ReglagesExportErreur`, `ReglagesExportErreurSombre`, `ReglagesVide`, `ReglagesVideSombre` | CA1, CA3, CA11, CA12, CA33 à CA35 |
| Confirmation de la suppression totale | `Confirmation` (champ vide), `ConfirmationSombre`, `ConfirmationSaisie`, `ConfirmationSaisieSombre`, `ConfirmationEnCours`, `ConfirmationEnCoursSombre`, `ConfirmationNonCommencee`, `ConfirmationNonCommenceeSombre` (CA20), `ConfirmationErreur`, `ConfirmationErreurSombre` (CA21) | CA14 à CA17, CA20, CA21, CA33 à CA35 |
| Confirmation depuis la clé introuvable | `ConfirmationCle`, `ConfirmationCleSombre` | CA27 |
| Liste après la suppression | `ListeApresSuppression`, `ListeApresSuppressionSombre` | CA18 |
| Démarrage : clé introuvable | `DemarrageCle`, `DemarrageCleSombre` | CA26 |
| Démarrage : suppression à reprendre, en échec | `DemarrageReprise`, `DemarrageRepriseSombre` | CA23 |

Format : identique à la [maquette 001](../001-saisie-et-liste-des-entrees/README.md). Les fichiers d'une variante importent l'écran principal (`Main`, `Confirmation`, `ListeApresSuppression`, `DemarrageCle`) ; le script `support.js` est fourni par l'artefact et n'est pas versionné. `Main` et `Confirmation` sont interactifs dans l'artefact : « Tout supprimer » ouvre la confirmation, et le bouton de confirmation s'active quand « SUPPRIMER » est écrit.

La section « Écran d'aide » des Réglages reprend la [maquette 002](../002-garde-fou-detresse/) sans changement.

Données d'exemple fictives.

## Jetons

Couleurs, typographie, espacements, rayons et tailles : uniquement ceux de `tokens.json`. Les boutons destructeurs sont en `danger` pour le texte et la bordure, sur `surface-raised`, parce que la charte n'a pas de jeton `on-danger` pour un fond `danger` plein. Le bouton désactivé reprend celui de la maquette 001 (`line`, `surface-raised`, `ink-muted`).

Jetons manquants, déjà relevés par la maquette 002 et à ajouter à la charte, à `tokens.json` et au test de fidélité dans la PR d'implémentation qui les utilise la première :

- `icon-md` (24) : chevron de retour, icône « Réglages » ;
- `icon-button` (18) : icône posée dans un bouton (partage, corbeille).

Aucun autre jeton manquant.

## Limites

- Captures PNG : absentes, comme pour les maquettes 001 et 002. L'agent ne peut pas les exporter depuis l'artefact (pas de navigateur connecté) ni ouvrir d'issue sans l'accord de Yanis : une issue commune aux maquettes 001, 002 et 005 est demandée à Yanis dans la PR #16, et sera citée ici.
- Lien et anneau de focus écrits en dur avec la valeur claire de `tide` dans la feuille de style de l'artefact, comme pour les maquettes 001 et 002 : sans effet sur l'app.
- Feuille de partage : écran du système, non dessiné.
- Marges hautes : 64 points pour les écrans avec retour (comme la maquette 002), 72 pour la liste (maquette 001), 92 pour l'écran de démarrage, qui reprend l'espacement du code actuel (zone sûre puis `space-8`).
