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
