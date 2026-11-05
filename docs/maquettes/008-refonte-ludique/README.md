# Maquette des specs 008 à 010 : refonte ludique

Copie versionnée de la page « Refonte · proposition » de l'artefact Claude de type « Design » *Tidemark : tous les écrans* ([lien privé](https://claude.ai/artifact/FWqBZBnQUYwoCNoCPQrFP5)), construit sur la [charte](../000-charte/). **Cette copie fait foi.** Specs : [008](../../specs/008-charte-ludique.md), [009](../../specs/009-accueil-et-navigation.md), [010](../../specs/010-ce-qui-a-compte-et-coquillage.md).

Statut : **direction validée par Yanis le 2026-11-05** (« on garde tout ») ; specs proposées, à valider au merge ([issue #48](https://github.com/yanis-vroland/Tidemark/issues/48)).

| Écran | Fichiers (artboards) | Critères |
| --- | --- | --- |
| Bienvenue | `Bienvenue`, `BienvenueSombre` | 009 : CA1, CA2 |
| Accueil : en-tête, check-in, plage, liste | `Journal`, `JournalSombre` | 008 : CA12 ; 009 : CA7 à CA19 |
| Saisie, avec « Ce qui a compté » (interactive) | `Saisie`, `SaisieSombre` | 008 : CA11 ; 010 : CA1 à CA3 |
| Coquillage ramassé | `Enregistre`, `EnregistreSombre` | 010 : CA12, CA16, CA18 |
| Coquillage ramassé, version douce | `EnregistreDoux` | 010 : CA13 |
| Détail d'une entrée | `Detail`, `DetailSombre` | 008 : CA13 ; 010 : CA7 |
| Onglet « Semaine » | `Semaine`, `SemaineSombre` | 009 : CA23 à CA25 |
| Proposition du modèle | `Modele`, `ModeleSombre` | 008 : CA15 |
| Écran d'aide (inchangé dans l'esprit : sobre) | `Aide`, `AideSombre` | 008 : CA14 |
| Accueil vide (sous le check-in), en lecture, en erreur | `JournalVide`, `JournalChargement`, `JournalErreur` et leurs variantes `Sombre` | 009 : CA11, CA17, CA18 ; 001 : CA1, CA31, CA32 |
| Onglet « Semaine » en calcul, en erreur | `SemaineChargement`, `SemaineErreur` et leurs variantes `Sombre` | 006 : CA29, CA30 ; 009 : CA23 |
| Coquillage ramassé sans rang (lecture de la semaine en erreur) | `EnregistreSansRang`, `EnregistreSansRangSombre` | 010 : CA17 |
| Coquillage ramassé, version douce, sombre | `EnregistreDouxSombre` | 010 : CA13 |
| Composants | `MoodGlyph` (bulle de marée), `TabBar` | 008 : CA5 ; 009 : CA19 |

Les variantes importent l'écran principal avec un état (`state` : `vide`, `chargement`, `erreur` ; `norank`, `soft`) et un thème (`dark`), comme les maquettes 005 et 006. Le script `support.js` et la copie de `tokens.json` de la charte (`ds/tidemark/`) sont fournis par l'artefact et ne sont pas versionnés.

Données d'exemple fictives : soirée du mercredi 14 octobre 2026, semaine du 12 au 18 octobre (humeurs 4, 3, 2, 4, 5, 4, dimanche sans entrée), entrées et étiquettes rédigées pour la maquette.

## Écarts assumés entre la maquette et les specs

- Le check-in de la maquette dit « ce soir » : la spec 009 (CA11) dit « aujourd'hui » le jour.
- Les animations sont en CSS dans la maquette ; dans l'app, elles suivent la spec 008 (mouvement) et s'arrêtent si le téléphone demande de réduire les animations.
- L'en-tête du bilan de la maquette est dessiné pour une semaine ; l'app dessine chaque semaine depuis ses entrées (spec 009, CA24), et garde sous les autocollants les sections de la spec 006.
- Le titre de la plage est posé sur `hero-wave-1` dans l'app, et non sur `sea` comme dans la maquette : `on-hero` sur `sea` clair n'atteint que 3,96:1 (revue de la PR).
- Les réglages et la confirmation de suppression ne sont pas redessinés : ils prennent seulement les jetons v2 (spec 008, CA16).

## Limites

- Captures PNG absentes, comme pour les maquettes précédentes ([issue #20](https://github.com/yanis-vroland/Tidemark/issues/20)).
- Texte à 200 % non dessiné.
