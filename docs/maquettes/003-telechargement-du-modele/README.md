# Maquette de la spec 003 : téléchargement du modèle local

Copie versionnée de l'artefact Claude de type « Design » ([lien privé](https://claude.ai/artifact/UWcB9nLPntAx9rUt8XrKwL)), construit sur la [charte](../000-charte/) (artefact « Design System » Tidemark, installé dans le canevas). **Cette copie fait foi.** Spec : [`docs/specs/003-telechargement-du-modele.md`](../../specs/003-telechargement-du-modele.md).

Statut : **validée par l'agent le 2026-10-14**, par délégation de Yanis.

| Écran | Fichiers (artboards) | Critères |
| --- | --- | --- |
| Écran du modèle, proposition | `Main` (nominal), `PropositionSombre` | CA1 à CA6, CA29, CA30 |
| Écran du modèle, progression | `Progression`, `ProgressionSombre` | CA7, CA9 à CA11, CA28 à CA30 |
| Écran du modèle, confirmation d'annulation | `Annulation`, `AnnulationSombre` | CA12, CA13 |
| Écran du modèle, vérification | `Verification`, `VerificationSombre` | CA14, CA28 |
| Écran du modèle, échecs | `Echec` (réseau), `EchecSombre`, `EchecEmpreinte`, `EchecEmpreinteSombre`, `EchecPlace`, `EchecPlaceSombre` | CA15 à CA20, CA28 |
| Écran du modèle, prêt | `Pret`, `PretSombre` | CA14, CA28 |
| Réglages, « Analyse sur le téléphone » | `Reglages` (modèle absent), `ReglagesSombre`, `ReglagesTelechargement`, `ReglagesTelechargementSombre`, `ReglagesPret`, `ReglagesPretSombre` | CA23, CA24, CA29, CA30 |

Format : identique à la [maquette 001](../001-saisie-et-liste-des-entrees/README.md). `Main` porte les huit états de l'écran du modèle (propriété `state`) ; `Reglages` porte les trois états du modèle. Les fichiers d'une variante importent l'un des deux. Le script `support.js` est fourni par l'artefact et n'est pas versionné.

Données d'exemple fictives : progression à 28 % (312 Mo), taille de 1,1 Go tirée des mesures de l'ADR-001.

## Limites

- Captures PNG : absentes, comme pour les maquettes 001 et 002 (export depuis l'artefact, Partager, Exporter). Dette à suivre dans une issue, à créer avec l'accord de Yanis (proposée dans la réponse à la revue IA de la PR #18) ; la spec n'affiche donc pas encore de capture.
- Lien et anneau de focus écrits en dur avec la valeur claire de `tide` dans la feuille de style de l'artefact, comme pour les maquettes 001 et 002 : sans effet sur l'app.
- Réglages : artboards de 1 240 points de haut, pour montrer tout l'écran qui défile ; la section « Écran d'aide » est celle de la maquette 002, reprise à l'identique (degré « Normale »). L'état « chargement » des Réglages est celui de la maquette 002.
- Pas d'état vide : le contenu de la proposition est fixe. La progression et la vérification sont les états de chargement, les trois échecs les états d'erreur.
- L'attente de la première réponse du serveur (0 %, avant le premier octet) n'est pas dessinée : la progression s'affiche à 0 %.
- La taille « 1,1 Go » vient de la mesure du spike ; la constante `ModelSource` fixée à l'implémentation fait foi (spec 003, CA4).
- Jetons à ajouter à la charte dans la PR d'implémentation : `progress-height` (8, barre de progression), en plus de `icon-md` (24) et `icon-button` (18) demandés par la spec 002. Tout le reste suit les jetons existants.
