# Journal : saisie et liste des entrées, implémentation (spec 001)

Branche `feat/saisie-entree`. Reprend l'implémentation et les suites de revue de la spec 001, poussées sur `docs/spec-001-saisie` après le merge de la PR #12 (mergée au commit des tests, 61d9644) ; les deux entrées ci-dessous viennent de cette branche, dont le journal est désormais figé.

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

## 2026-10-14 16:22

### Fait

- Constat : la PR #12 a été mergée à 14:08 UTC sur le commit des tests (61d9644), avant les commits d'implémentation (897861c) et de suites de revue (43a5ba4), poussés ensuite sur la branche. `main` portait donc 118 tests en échec et le squelette (`main()` lève `UnimplementedError`).
- Nouvelle branche `feat/saisie-entree` depuis `main`, avec ces deux commits reportés (cherry-pick) ; leurs entrées de journal déplacées ici, le journal de la branche mergée ne pouvant plus être modifié (`verifier-journal.sh`).

### Décisions

- Rattrapage par une nouvelle PR plutôt que par une réécriture de `main` (agent).

### Corrections et limites

- Erreur de l'agent : pas de vérification de l'état de la PR avant de pousser (leçon déjà notée dans le plan du template : `gh pr view --json state` avant tout push sur une branche de PR).

### Prochaine étape

Yanis merge cette PR pour remettre `main` au vert, valide CA31 à CA35 et tranche les questions de confidentialité ; puis test humain sur l'iPhone 15 Pro.
