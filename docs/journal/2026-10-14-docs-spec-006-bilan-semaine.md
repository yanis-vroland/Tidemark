# Journal : spec 006, bilan de la semaine

Branche `docs/spec-006-bilan-semaine`.

## 2026-10-14 20:36

### Fait

- Spec 006 rédigée (`docs/specs/006-bilan-de-la-semaine.md`) : règles de calcul en Dart, mise en mots par le modèle à partir de faits sans chiffre, semaine sensible, validation déterministe de la sortie avec deux listes (mots de nombre, expressions interdites), 33 critères d'acceptation, données (`WeeklyReviewCalculator`, `ReviewFacts`, `ReviewWriter`, `ReviewTextValidator`), cas limites.
- Maquette en artefact « Design » ([lien privé](https://claude.ai/artifact/HpKb64hQ1aWeLVZzyXH9wj)), sur la charte Tidemark installée dans le canevas : 16 artboards (bilan nominal, mise en mots en cours, sans texte, modèle absent, moins de 3 entrées, chargement, erreur ; carte d'accès dans la liste ; chacun en clair et en sombre). Copie dans `docs/maquettes/006-bilan-de-la-semaine/` avec son README.
- Cahier des charges : glossaire (`WeeklyReview` précisé, `ReviewFacts`, `ReviewWriter`, `ReviewTextValidator`, semaine sensible), RM50 à RM55, parcours (étape 7), ligne du lot I à « spec validée ».

### Décisions

Toutes prises par l'agent, à la demande de Yanis (« prends les décisions métier », 2026-10-14), et consignées dans la spec (« Questions ouvertes ») :

- Accès par une carte en tête de la liste ; semaine en cours, puis navigation vers les semaines passées jusqu'à la première entrée.
- Toutes les entrées comptent dans les chiffres, quel que soit leur statut ; moyenne par entrée, au dixième, calculée en entiers.
- Le modèle reçoit des faits sans chiffre, jamais une entrée ; sortie validée par des règles déterministes, rejet → chiffres seuls.
- Semaine sensible (une entrée à « Très bas » ou en détresse) : pas de texte généré, aucun rappel de l'écran d'aide (cohérence avec la spec 002).
- Texte jamais enregistré, gardé en mémoire tant que l'app est ouverte.
- RM numérotées à partir de RM50, pour éviter les collisions avec les PR de specs ouvertes en parallèle (consigne de l'agent principal).

### Corrections et limites

- Pas de captures PNG, comme pour les maquettes 001 et 002.
- Artboards du bilan complet en 393 × 1320 (écran qui défile), états courts en 393 × 852.
- Quatre jetons manquent à la charte : `icon-md` et `icon-button` (déjà demandés par la spec 002), `bar-thickness`, `day-cell`.
- Dépendances au lot G : interface de lecture des étiquettes (spec 004, étiquetage automatique) et état du modèle (spec du téléchargement), pas encore écrites ; les étiquettes de la maquette sont des exemples.
- Le statut « spec validée » repose sur la délégation des décisions métier ; la maquette reste à valider par Yanis avant les tests.

### Prochaine étape

Yanis relit la spec et valide la maquette (commentaires sur l'artefact). Ensuite, après le lot G : tests par le subagent `test-writer`, committés seuls, puis implémentation sur `feat/bilan-semaine`.
