# Maquette de la spec 004 : étiquetage automatique

Copie versionnée de l'artefact Claude de type « Design » ([lien privé](https://claude.ai/artifact/QVMphoCa1umzrZcGkJ3VJX)), construit sur la [charte](../000-charte/) (artefact « Design System » Tidemark, installé dans le canevas). **Cette copie fait foi.** Spec : [`docs/specs/004-etiquetage-automatique.md`](../../specs/004-etiquetage-automatique.md).

Statut : **validée par l'agent le 2026-10-14**, par délégation de Yanis.

| Écran | Fichiers (artboards) | Critères |
| --- | --- | --- |
| Liste | `Main` (une entrée étiquetée, une en cours d'analyse, une sans texte, une de la veille étiquetée), `ListeSombre` | CA19, CA20, CA26, CA27, CA29, CA30 |
| Détail, étiquetée | `Detail`, `DetailSombre` | CA21, CA26, CA28 à CA30 |
| Détail, analyse en cours | `DetailEnCours`, `DetailEnCoursSombre` | CA22, CA28 |
| Détail, en attente de son tour | `DetailEnAttente`, `DetailEnAttenteSombre` | CA22 |
| Détail, modèle absent | `DetailModeleAbsent`, `DetailModeleAbsentSombre` | CA23 |
| Détail, modèle impossible à charger | `DetailIndisponible`, `DetailIndisponibleSombre` | CA31 |
| Détail, aucune étiquette | `DetailSansEtiquette`, `DetailSansEtiquetteSombre` | CA24 |

Format : identique à la [maquette 001](../001-saisie-et-liste-des-entrees/README.md). `Detail` porte les six états de la section « Étiquettes » (propriété `state`). Les fichiers d'une variante importent `Main` ou `Detail`. Le script `support.js` est fourni par l'artefact et n'est pas versionné.

Données d'exemple fictives, datées du mercredi 14 octobre 2026 ; étiquettes prises dans la liste fermée de la spec.

## Limites

- Captures PNG : absentes, comme pour les maquettes 001 et 002 (export depuis l'artefact, Partager, Exporter). Dette à suivre dans une issue, à créer avec l'accord de Yanis (proposée dans la réponse à la revue IA de la PR #18) ; la spec n'affiche donc pas encore de capture.
- Lien et anneau de focus écrits en dur avec la valeur claire de `tide` dans la feuille de style de l'artefact, comme pour les maquettes 001 et 002 : sans effet sur l'app.
- États vide, chargement et erreur de la liste et du détail : ceux des maquettes 001 et 002, inchangés par l'étiquetage.
- État « non analysée » (sans texte ou détresse) : aucune section « Étiquettes », comme le détail de la maquette 001 (`DetailSansTexte`) ; il n'est pas redessiné.
- État « modèle en cours de téléchargement » du détail (spec 004, CA23) : pas dessiné ; même place et même style que « modèle absent », sans bouton.
- Le bouton « Télécharger le modèle (1,1 Go) » du détail mène à l'écran du modèle de la [maquette 003](../003-telechargement-du-modele/README.md), dans un autre artefact : le lien n'est pas actif dans le prototype.
- Jetons : aucun nouveau. `icon-button` (18) est déjà demandé par la spec 002.
