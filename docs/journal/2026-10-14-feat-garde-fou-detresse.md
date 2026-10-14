# Journal : garde-fou de détresse (spec 002)

Branche `feat/garde-fou-detresse`.

## 2026-10-14 20:28

### Fait

- Squelette de la spec 002, sans comportement :
  - `DistressDetector` et `LowMoodSensitivity` ;
  - liste des termes vide ;
  - `saveEntryWithGuard` et `screenPendingEntries` ;
  - `SettingsRepository` et `DriftSettingsRepository` ;
  - `PhoneDialer` et `UrlLauncherDialer` ;
  - écrans `HelpScreen` et `SettingsScreen` vides ;
  - nouvelles opérations de `EntryRepository` ;
  - `Journal` rendu par `openJournal`.
- Dépendance `url_launcher` 6.3.3 ajoutée, pour ouvrir le composeur.
- Faux pour les tests :
  - `FakeEntryRepository` complété (horloge, `seed`, nouvelles opérations) ;
  - `FakeSettingsRepository` et `FakePhoneDialer` créés.

### Décisions

- Réglages et composeur facultatifs dans les écrans. Par défaut : `DefaultSettingsRepository` (degré « Normale », lecture seule) et `UrlLauncherDialer`. Les tests de la spec 001 restent ainsi inchangés ; l'app démarrée reçoit toujours les réglages de la base (agent).

### Corrections et limites

- Test modifié, à signaler : `test/storage/open_journal_test.dart`. `openJournal` rend désormais un `Journal` (entrées et réglages) : les appels passent par `.entries`, sans aucune vérification retirée.

### Prochaine étape

Tests de la spec 002 par le subagent `test-writer`, committés seuls et rouges ; puis implémentation.

## 2026-10-14 20:42

### Fait

- Tests de la spec 002 écrits à partir de la spec et de la maquette, 268 tests, tous rouges sauf 10 tests « négatifs » ou témoins qui décrivent un comportement déjà vrai (voir plus bas) :
  - `test/distress/` : détecteur (normalisation, mots entiers, formes niées, séries par degré avec bornes exactes), liste des termes (CA14, relue dans le bloc de la spec), `saveEntryWithGuard`, vérification au démarrage ;
  - `test/storage/distress_storage_test.dart` : nouvelles opérations du dépôt drift, `DriftSettingsRepository`, valeur inconnue en base, persistance après redémarrage, migration 1 vers 2 ;
  - `test/ui/` : écran d'aide, Réglages (dont l'accès depuis les quatre états de la liste) et parcours complets avec `TidemarkApp` ;
  - `test/support/distress_harness.dart` : textes de la maquette, collecteur de couleurs peintes (CA26), ordre de lecture, environnement de parcours.
- Aucun test existant ni fichier de `lib/` modifié.

### Décisions

- CA28 lu comme : deux entrées à 1, dont une supprimée, puis une nouvelle entrée à 1 (deux entrées restent, pas de série). La formulation de la spec est ambiguë (agent, à confirmer).
- CA9 : le test ne compte pas les appels au détecteur (le statut doit être décidé avant l'ajout) ; il vérifie l'erreur remontée, l'absence de résultat d'écran d'aide et le dépôt inchangé (agent).
- CA15 et CA16 testés par `startApp` : la vérification au démarrage est donc attendue dans `startApp`, pas dans `openJournal` (agent, à valider à l'implémentation).
- Valeur inconnue en base (CA21) : le test retrouve la colonne du degré par sa valeur, il ne suppose pas son nom (agent).

### Corrections et limites

- Tests qui passent déjà avant l'implémentation : comportements négatifs ou hérités de la spec 001 (CA3, CA4, CA7 et CA9 dans les parcours, CA21 avec une entrée banale, témoin de CA29, `addEntry` par défaut et RM24, constantes de `LowMoodSensitivity`, lecture de la spec), plus les deux tests de CA16 par `startApp` qui passent car l'app s'ouvre sans la vérification (ils vérifient aussi qu'elle est tentée : à renforcer si l'implémentation ne passe pas par `startApp`).
- Non testé : l'ouverture réelle du composeur (`UrlLauncherDialer`, `tel:`) et la configuration native Android et iOS, hors de portée d'un test unitaire sans plateforme.
- Décisions d'implémentation que les tests supposent : `normalize` rend une chaîne vide pour un texte d'émoji seul (sans espaces en tête ni en queue) ; l'accessibilité des degrés suit le modèle « groupe exclusif + état coché ».
- Non spécifié, non testé : disparition du bandeau d'erreur des Réglages après un nouveau choix réussi ; affichage des Réglages quand la lecture du degré échoue.

### Prochaine étape

Relire les tests, puis implémenter jusqu'au vert, dans un commit séparé.
