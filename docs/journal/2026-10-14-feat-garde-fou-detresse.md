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

## 2026-10-14 21:03

### Fait

- Implémentation de la spec 002 :
  - détecteur (normalisation, expressions en mots entiers, série) et liste de 83 termes reprise de la spec ;
  - `saveEntryWithGuard` : statut `skipped` et écran d'aide en cas de détresse, degré « Normale » si la lecture échoue ;
  - vérification au démarrage dans `startApp` ;
  - table `settings` et migration vers la version 2 du schéma ;
  - `HelpScreen`, `SettingsScreen` et l'icône « Réglages » dans tous les états de la liste ;
  - `UrlLauncherDialer`, et le schéma `tel` déclaré sur Android (`<queries>`) et iOS (`LSApplicationQueriesSchemes`).
- Composant commun `ErrorBanner` extrait de la saisie, réutilisé par les Réglages.
- Jetons `icon-md` (24) et `icon-button` (18) ajoutés à la charte (`tokens.json`, artefact de la charte, `TidemarkSize`). La maquette 002 suit `ring-width` pour la bordure du degré choisi.
- Architecture technique : table `settings`, schéma v2, contrats `EntryRepository`, `SettingsRepository`, `DistressDetector`, `PhoneDialer`, sécurité.
- 434 tests verts. Contrôle par mutation sur 18 protections, toutes détectées après l'ajout d'un test (voir ci-dessous).

### Décisions

- Les deux tests de configuration native (`test/platform/dialer_config_test.dart`) sont ajoutés après l'implémentation : la spec impose cette configuration, aucun test ne la couvrait (agent).
- Chaque degré des Réglages porte un nœud de sémantique explicite (radio, coché, nom et description), et l'icône « Réglages » un libellé explicite : l'infobulle seule n'en donne pas (agent).

### Corrections et limites

- Tests modifiés ou ajoutés après le commit des tests, à signaler :
  - `test/ui/help_screen_test.dart` (CA25, appel impossible à 200 %) : défilement jusqu'au bouton avant de le toucher. À 200 %, le bouton est sous l'écran, et la spec dit que l'écran défile. Sans ce défilement, le toucher tombait hors de l'écran. Aucune vérification retirée.
  - `test/distress/distress_detector_test.dart` : nouveau test de l'accent combinant (forme décomposée). Retirer sa prise en charge n'était détecté par aucun test.
- Écran Réglages : passé de `ListView` à `SingleChildScrollView`, parce qu'à 200 % le bandeau d'erreur sortait de l'arbre après le défilement. C'est le même piège qu'au lot E.
- Non testé : l'ouverture réelle du composeur, à vérifier au test humain sur l'iPhone.

### Prochaine étape

Revues `reviewer` et `security-reviewer`, essai sur simulateur, puis PR.

## 2026-10-14 21:08

### Fait

- Suites des revues `reviewer` et `security-reviewer` (aucun point bloquant) :
  - `saveEntryWithGuard` : si la série ne peut pas être lue, l'entrée est enregistrée quand même, et un texte en détresse ouvre toujours l'écran d'aide. Deux tests ajoutés.
  - Instant de la série tronqué à la seconde, comme l'entrée enregistrée.
  - Réglages obligatoires dans `TidemarkApp`, `EntryListScreen` et `EntryFormScreen` : `DefaultSettingsRepository` supprimé, plus aucun repli silencieux en production.
  - Écran Réglages quand la lecture du degré échoue : « Normale » coché, un choix reste possible. Test ajouté.
  - Déclarations natives du composeur retirées (`<queries>` DIAL, `LSApplicationQueriesSchemes`) : `launchUrl` n'en a pas besoin, et elles rendaient d'autres apps visibles à Tidemark. Le test de configuration native vérifie maintenant leur absence et l'absence de `canLaunchUrl`.
  - Spec 002 : CA28 reformulé, deux cas limites ajoutés, « Données » corrigé ; architecture technique corrigée.
  - Expression régulière des accents combinants écrite en échappements `\u`. Commentaire orphelin retiré. Saut de ligne final de `tokens.json` rétabli.
- Essai sur le simulateur iPhone 17 Pro : l'app, installée par-dessus la version du lot E (base en version 1), démarre sur la liste. La migration passe, et l'icône « Réglages » est en place.
- 438 tests verts.

### Décisions

- Bordure du degré choisi : jeton `ring-width` (3) au lieu de 2 dans la maquette 002. L'artefact et la copie du dépôt sont alignés, ce qui évite un jeton de plus (agent, par délégation de Yanis, 2026-10-14).
- Série illisible et lecture du degré impossible dans les Réglages : décisions consignées dans les cas limites de la spec (agent, par délégation de Yanis).
- `addEntry` garde `pending` par défaut, contrairement à la suggestion de la revue de sécurité. Le contrat de la spec 001 et ses tests en dépendent, et la défense en profondeur du lot G (`detectInText` avant chaque analyse) couvre un appel qui oublierait le garde-fou (agent).
- Masquage dans l'aperçu des apps récentes : déjà en attente d'une décision de Yanis depuis le lot E (agent).

### Corrections et limites

- Tests modifiés, à signaler : les tests de la spec 001 qui construisent `TidemarkApp`, `EntryListScreen` ou `EntryFormScreen` reçoivent `settings: FakeSettingsRepository()`, et le harnais `DbEnv` reçoit les réglages de la base. Ce sont 31 appels, dans `app_test`, `accessibility_and_theme_test`, `entry_form_screen_test`, `entry_list_screen_test` et `robustness_test`. Changement mécanique : aucune vérification retirée.
- Précision sur l'entrée précédente : l'artefact « Design System » de la charte a été mis à jour en ligne (jetons `icon-md` et `icon-button`), hors dépôt ; le dépôt porte `tokens.json`. Le total était de 435 tests, et non 434.
- Test humain non fait : agent en autonomie, sans accès à l'iPhone. À faire par Yanis : parcours de détresse par le texte et par la série, ouverture réelle de `tel:3114` et `tel:112`, Réglages, thème sombre, texte à 200 %.
- Non suivi : vérification de la migration par `drift_dev schema dump` (suggestion de la revue). Le test recrée le schéma 1 à la main, à partir du code de la spec 001.

### Prochaine étape

Ouvrir la PR, traiter la revue IA, puis le test humain par Yanis.
