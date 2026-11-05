# Journal de la branche docs/publication-refonte

## 2026-11-06 01:15

### Fait

- Après le merge de la PR #49 par Yanis : specs 008 à 010 passées à « validée (merge de la PR #49) » ; cahier des charges (statuts « spec validée ; implémentée (PR #49 mergée), test humain en attente », règles RM62 à RM66 validées) ; plan, lot K coché.
- Nouvelle démo de l'app réelle, filmée par un agent sur le simulateur iOS (iPhone 17 Pro, branche `demo-refonte`) :
  - `docs/demo/tidemark.mp4` (31 s) et `docs/demo/tidemark.gif` (320 px) ;
  - 7 captures `docs/captures/ios-*.png` ;
  - parcours filmé : bienvenue, accueil du soir, check-in « Bien », sujets, phrase, coquillage ramassé, plage, détail, onglet « Semaine ».
- Méthode du tournage :
  - scénario d'intégration temporaire, jamais committé, avec `integration_test` retiré ;
  - 4 entrées fictives des jours précédents, enregistrées avec une horloge fixée ;
  - animations d'ambiance actives, bannière DEBUG masquée ;
  - métadonnées retirées des fichiers.
- README :
  - introduction : refonte du 5 novembre ;
  - section « Démo » : GIF, vidéo, captures iOS ;
  - « Méthode » : 10 specs, 290 critères, 2 514 tests, 40 PR, refonte faite en autonomie par des agents en parallèle, mutations ;
  - « Limites » : test humain de la refonte en attente.

### Décisions

- Yanis : la vidéo va dans le README et sur le dépôt GitHub (aucun site de l'app à ce jour).
- Agent : les captures Android de l'ancien design restent dans `docs/captures/`, citées pour l'étiquetage par le modèle local, que la nouvelle démo ne montre pas (modèle non téléchargé sur le simulateur).

### Corrections et limites

- La démo ne montre pas l'étiquetage. La proposition du modèle a été marquée comme déjà vue dans le scénario, pour ne pas couper le parcours.
- Une fine croix rouge du moteur de test apparaît quelques images à certains touchers (« Continuer », « Semaine »).
- Test humain de la refonte non confirmé : la case est cochée dans la PR #49, mais Yanis ne l'a pas confirmé ; la doc garde « en attente ».

### Prochaine étape

- PR en brouillon, merge par Yanis ; une fois le test humain confirmé, passer les specs 008 à 010 à « livrée ».
