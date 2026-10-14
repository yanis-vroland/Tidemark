# Maquette de la spec 006 : bilan de la semaine

Copie versionnée de l'artefact Claude de type « Design » ([lien privé](https://claude.ai/artifact/HpKb64hQ1aWeLVZzyXH9wj)), construit sur la [charte](../000-charte/) (artefact « Design System » Tidemark installé dans le canevas, `designSystems` de `canvas.json`). **Cette copie fait foi.** Spec : [`docs/specs/006-bilan-de-la-semaine.md`](../../specs/006-bilan-de-la-semaine.md).

Statut : **brouillon**, à valider par Yanis avec la spec, avant les tests.

| Écran | Fichiers (artboards) | Critères |
| --- | --- | --- |
| Bilan, écran entier | `Main` (nominal, interactif : semaine précédente et suivante), `BilanSombre` | CA4, CA5, CA8 à CA17, CA19, CA31 à CA33 |
| Bilan, mise en mots en cours | `BilanEcriture`, `BilanEcritureSombre` | CA18 |
| Bilan, sans texte généré | `BilanSansTexte`, `BilanSansTexteSombre` | CA20, CA22 à CA26 |
| Bilan, modèle absent | `BilanModeleAbsent`, `BilanModeleAbsentSombre` | CA27 |
| Bilan, moins de 3 entrées | `BilanInsuffisant`, `BilanInsuffisantSombre` | CA6 |
| Bilan, chargement | `BilanChargement`, `BilanChargementSombre` | CA29 |
| Bilan, erreur | `BilanErreur`, `BilanErreurSombre` | CA30 |
| Liste, accès au bilan | `ListeBilan`, `ListeBilanSombre` | CA1 à CA3, CA32, CA33 |

Format : identique aux maquettes [001](../001-saisie-et-liste-des-entrees/README.md) et [002](../002-garde-fou-detresse/README.md). Les fichiers d'une variante importent l'écran principal avec un état (`state`) et un thème (`dark`) ; le script `support.js` et la copie de `tokens.json` de la charte (`ds/tidemark/`) sont fournis par l'artefact et ne sont pas versionnés.

Données d'exemple fictives : la maquette se place le dimanche 18 octobre 2026, semaine du 12 au 18 octobre (7 entrées), semaine précédente du 5 au 11 octobre (5 entrées, dont une à « Très bas » : pas de texte généré, CA20), et du 28 septembre au 4 octobre (2 entrées : pas de bilan). Les étiquettes (« fatigue », « travail », « calme », « famille ») sont des exemples : la liste fermée est celle de la spec 004, étiquetage automatique. Le texte du bilan est rédigé à la main pour la maquette, selon les règles de la spec (aucun chiffre, aucun conseil).

## Limites

- Captures PNG : absentes, comme pour les maquettes 001 et 002 : l'agent ne peut pas exporter l'artefact. Reporté à une issue de suivi, proposée dans la PR #17 et à créer avec l'accord de Yanis.
- Écran qui défile : les artboards du bilan complet mesurent 393 × 1320 pour montrer l'écran entier ; sur l'iPhone (393 × 852), il défile. Les états courts (moins de 3 entrées, chargement, erreur) sont au format 393 × 852.
- Lien et anneau de focus écrits en dur avec la valeur claire de `tide` dans la feuille de style de l'artefact, comme pour les maquettes 001 et 002 : sans effet sur l'app.
- Indicateur de chargement dessiné immobile ; dans l'app, il tourne, sauf si le téléphone demande de réduire les animations (charte, `LoadingNote`).
- Texte à 200 % : non dessiné. La largeur fixe des libellés de la répartition (72 points) est celle de la maquette ; dans l'app, le libellé passe à la ligne au lieu d'être tronqué (CA32).
- Section « Étiquettes fréquentes » sans étiquette (« Aucune étiquette cette semaine. », CA13) : pas dessinée ; même carte, phrase en `body` et `ink-muted` à la place des puces.
- Carte de la liste dans les états vide, chargement et erreur : absente (CA2), donc pas dessinée.

## Jetons

La maquette n'utilise que les jetons de [`tokens.json`](../000-charte/tokens.json) : couleurs des deux thèmes, `display` pour le titre, `title` pour les chiffres clés, `headline`, `body`, `label`, `button` et `caption` ; `space-1` à `space-6` ; `radius-sm` (cases des jours, bandeau d'erreur), `radius-md` (cartes), `radius-pill` ; `tap-min` (flèches de semaine), `mood-dot-sm` (pastilles de la répartition et icône de la carte d'accès), `button-height`, `icon-sm` (cadenas).

Usage étendu d'un jeton existant : `line` colore aussi l'icône d'une flèche désactivée (« Semaine précédente » sur la semaine la plus ancienne, « Semaine suivante » sur la semaine en cours), en plus des bordures. Usage à ajouter à la description du jeton dans la charte, avec l'implémentation.

Jetons manquants, à ajouter à la charte, à `tokens.json` et au test de fidélité dans la PR d'implémentation :

| Jeton proposé | Valeur | Usage |
| --- | --- | --- |
| `icon-md` | 24 | Chevron de retour, flèches de semaine, icône de la carte d'accès. Déjà demandé par la spec 002. |
| `icon-button` | 18 | Indicateur de chargement (`LoadingNote`). Déjà demandé par la spec 002. |
| `bar-thickness` | 8 | Épaisseur d'une barre de la répartition des humeurs. |
| `day-cell` | 40 | Hauteur d'une case de jour dans « Jours notés ». |
