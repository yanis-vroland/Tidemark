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

## 2026-10-14 16:09

### Fait

- Implémentation de la spec 001 jusqu'au vert : regroupement par jour et libellés en français, base `drift` chiffrée (`PRAGMA hexkey`, refus d'ouvrir sans SQLite3MultipleCiphers), dépôt, clé de 256 bits dans le trousseau ou le Keystore (`SecureKeyStore`), écrans de liste, de saisie et de détail, écran d'erreur au démarrage, écran de lancement aux couleurs de la charte (couleurs nommées Android et iOS), exclusion des sauvegardes (Android : `allowBackup`, `fullBackupContent`, règles d'extraction ; iOS : `isExcludedFromBackup` sur le dossier de la base dans `AppDelegate`).
- `flutter test` : 137 réussis, 0 en échec ; `dart analyze --fatal-infos` propre.
- Architecture technique : modèle de données ; plan : lot D clos.

### Décisions

- Compteur de caractères dans la zone fixe du bas : sous un long texte, il sortait de l'écran (agent).
- Libellé du champ au-dessus du champ, bornes « Très bas » / « Très bien » souples, formulaire et détail en `SingleChildScrollView`, feuille de confirmation défilable : nécessaires à 200 % de taille de texte (CA27) (agent).

### Corrections et limites

- **Tests modifiés, à signaler dans la PR** : dans trois tests de `test/ui/entry_form_screen_test.dart` (CA14 deux fois, CA15), la sémantique était libérée par `addTearDown`, exécuté après la vérification de fin de test de Flutter : échec même avec un code correct. Libérée désormais à la fin du corps du test ; aucune vérification retirée ni affaiblie.
- Diagnostic du débordement à 200 % : la police de test (Ahem, un carré par caractère) est plus large que Figtree ; la correction vaut aussi pour les petits écrans.
- Exclusion de sauvegarde iOS et chiffrement sur iPhone : à vérifier au test humain.

### Prochaine étape

Revues `reviewer` et `security-reviewer`, essai sur le simulateur, puis test humain de Yanis sur l'iPhone 15 Pro.

## 2026-10-14 16:20

### Fait

- Revues `reviewer` (3 bloquants, 10 à corriger, 8 suggestions), `security-reviewer` (0 bloquant, 2 à corriger, 4 suggestions) et revue IA en CI de la PR #12 (7 à corriger, 6 suggestions), traitées :
  - comptage en caractères visibles (`characters`) dans le dépôt et le compteur, tests avec drapeau, émoji composé et accent combinant ;
  - clé jamais recréée si la base existe (`DatabaseKeyMissingError`), `resetOnError: false` sur Android, message d'erreur au démarrage selon la cause (CA35) ;
  - tests CA28 recentrés sur l'écran affiché et sur des couleurs peintes ;
  - retour système bloqué pendant l'enregistrement (CA34), échec de suppression annoncé (CA33), liste : chargement (CA31) et erreur de lecture (CA32), flux créé une fois, intertitres recalculés au retour au premier plan, annonce complète des cartes ;
  - règles d'extraction Android complètes (`path`, domaines `device_*`), test renforcé ; écran de démarrage Android 12+ et fond des thèmes Android en `surface` ; garde-fou du chiffrement extrait et testé ; `secure_delete` ; clavier sans apprentissage des mots ;
  - date du détail alignée sur la maquette (année seulement si différente) ; bornes du sélecteur tirées de `moodLabels` ; style des boutons centralisé dans le thème ; dépôt factice aligné sur le contrat réel ;
  - spec : CA14 avec le texte exact, CA31 à CA35 (à valider par Yanis), interfaces nommées, jour local et tri précisés, trou du garde-fou de détresse entre les lots E et F consigné pour le lot G ; glossaire : `EntryRepository`, `KeyStore` ; RM5 précisé ; maquette : statut validé, limites ; architecture : vue d'ensemble, schéma, sécurité.
- Contrôle par mutation des garde-fous Android (attribut du manifeste, règle d'extraction, écran de démarrage v31) : chaque retrait est détecté.
- `flutter test` : 155 réussis ; `dart analyze --fatal-infos` propre. Essai sur le simulateur iPhone 17 Pro : démarrage, base chiffrée (pas d'en-tête SQLite en clair), dossier exclu des sauvegardes (attribut iOS présent).

### Décisions

- Corrections ci-dessus : agent. À trancher par Yanis : CA31 à CA35 ; suggestions et correction automatique du clavier, claviers tiers sur iOS ; masquage dans l'écran des apps récentes ; exclusion iOS « fermée » en cas d'échec.

### Corrections et limites

- **Tests modifiés, à signaler dans la PR** : les trois tests CA14, CA14, CA15 n'activent plus eux-mêmes la sémantique (déjà active par défaut) ; les tests CA28 visent l'écran affiché et vérifient des couleurs peintes (ils vérifiaient la liste) ; `FakeEntryRepository` garde le texte tel quel comme le vrai dépôt, et gagne `beforeDelete`, `watchError`, `neverEmit`. Aucune vérification retirée.
- Non traité : maquette (tailles des pastilles, anneau de focus en dur, états sombres non dessinés, captures PNG), exclusion iOS qui échoue en silence (`try?`).

### Prochaine étape

Yanis valide CA31 à CA35 et tranche les questions de confidentialité ; test humain sur l'iPhone 15 Pro.
