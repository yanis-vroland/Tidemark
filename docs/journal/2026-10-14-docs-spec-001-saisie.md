# Journal : spec 001, saisie et liste des entrées

Branche `docs/spec-001-saisie`.

## 2026-10-14 15:45

### Fait

- Spec 001 rédigée au statut « brouillon » : 29 critères d'acceptation (liste, saisie, détail et suppression, stockage, accessibilité et thème), données (`Entry`, `AnalysisStatus`), cas limites, hors périmètre, une question ouverte.
- Cahier des charges : RM27 (2 000 caractères), RM28 (suppression définitive avec confirmation), `AnalysisStatus` au glossaire, fonctionnalité au statut « spec brouillon ».
- Maquette d'exploration complétée et renommée : liste (entrées, vide, sombre) et détail (avec et sans texte, confirmation, sombre) ajoutés aux 5 écrans de saisie ; « Annuler » mène à la liste ; jours d'exemple corrigés (le 14 octobre 2026 est un mercredi). Sources versionnées dans `docs/maquettes/001-saisie-et-liste-des-entrees/`.

### Décisions

- Après « Enregistrer », retour à la liste ; suppression par un bouton du détail avec confirmation ; texte limité à 2 000 caractères ; liste regroupée par jour, la plus récente en haut (Yanis, 2026-10-14).
- Statut d'analyse propre à l'entrée (`AnalysisStatus` : `pending`, `tagged`, `untagged`, `skipped`) ; date en UTC avec le décalage local (agent, à valider avec la spec).
- Écran de lancement natif aux couleurs de la charte inclus dans la spec (CA29), comme noté au plan (agent).

### Corrections et limites

- Pas de captures PNG : à ajouter après validation de la maquette, avant les tests.
- Question ouverte : confirmation sur « Annuler » quand un texte est écrit.

### Prochaine étape

Yanis valide la spec et la maquette (et tranche la question ouverte). Ensuite : tests par le subagent `test-writer`, committés seuls, puis implémentation.
