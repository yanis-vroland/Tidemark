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

## 2026-10-14 15:48

### Fait

- Spec 001 passée en « validée » ; CA13 précisé et CA30 ajouté (confirmation « Abandonner cette entrée ? » seulement si un texte est écrit) ; cahier des charges : « spec validée ».

### Décisions

- Spec et maquette validées par Yanis (« je valide », 2026-10-14), avec la recommandation de l'agent sur la question ouverte et ses choix techniques (`AnalysisStatus`, `skipped`, date en UTC avec décalage).
- Tests et implémentation regroupés dans cette PR, plutôt qu'attendre le merge de la spec (CLAUDE.md, méthode de travail, point 6) (agent).

### Corrections et limites

- Captures PNG de la maquette toujours absentes : l'extension Chrome n'est pas connectée. À faire par export depuis l'artefact, ou plus tard.

### Prochaine étape

Tests des 30 critères par le subagent `test-writer`, vérifiés en échec pour la bonne raison, committés seuls.

## 2026-10-14 15:59

### Fait

- Dépendances ajoutées, versions épinglées selon l'ADR-002 : `drift` 2.35.2, `sqlite3` 3.7.1 (hook `sqlite3mc`), `flutter_secure_storage` 11.2.0, `path_provider`, `path` ; en développement `drift_dev` et `build_runner` (génération du code de `drift`).
- Squelette de l'interface publique de la spec 001 (`lib/entries/`, `lib/storage/`, `lib/ui/screens/`, `TidemarkApp(repository:, clock:)`) : chaque méthode lève `UnimplementedError`, pour que les tests compilent et échouent pour la bonne raison.
- Tests écrits par le subagent `test-writer` (`test/entries`, `test/storage`, `test/ui`, `test/platform`, `test/support`) : 30 critères couverts ; `flutter test` : 19 réussis (tests existants), 118 en échec sur `UnimplementedError` ou comportement absent, aucune erreur de compilation ; vérifié par l'agent principal.
- `test/app_test.dart` réécrit : `TidemarkApp` exige un dépôt, l'accueil est la liste « Ton journal ».

### Décisions

- Décisions d'implémentation signalées par `test-writer`, tranchées par l'agent principal : écran de lancement par couleurs nommées (`values`/`values-night` sur Android, couleur du catalogue avec variante sombre sur iOS) ; date du détail avec l'année (`fullDateLabel`) ; compteur avec une espace simple ; texte fait seulement d'espaces traité comme absent, y compris pour la confirmation d'abandon ; exclusion de sauvegarde iOS vérifiée à la main.

### Corrections et limites

- CA25 (iOS) et CA27 (« aucun texte tronqué ») ne sont couverts qu'en partie par les tests automatiques : test humain.
- Le harnais de test de `drift` n'a pas encore tourné sur une vraie base : réglages possibles pendant l'implémentation, sans changer les critères.

### Prochaine étape

Implémentation jusqu'au vert : base `drift` chiffrée, clé, regroupement par jour, trois écrans, écran de lancement, exclusion des sauvegardes.
