# Journal : export et suppression totale (spec 005)

Branche `feat/export-suppression`, partie de `main` à jour (lot H du plan). Spec : [`docs/specs/005-export-et-suppression-totale.md`](../specs/005-export-et-suppression-totale.md), ADR-003 accepté.

## 2026-10-15 15:21

### Fait

- Squelette de la spec 005, sans comportement (`UnimplementedError` ou écran vide) :
  - export : `JournalExporter` (format version 1), `formatWithOffset`, `exportFileName`, `JournalExport` et la purge des dossiers temporaires, `ShareSheet` et `SharePlusShareSheet` ;
  - suppression : `JournalWiper` (étapes, `WipeNotStartedError`, `WipeIncompleteError`), `WipeFiles` injectable, `checkInstallMarker` ;
  - `AppStorage` (dossier de la base, cache de l'app, trousseau) ;
  - `KeyStore.deleteAll` (implémenté sur `flutter_secure_storage`) et `EntryRepository.allEntriesWithTags` ;
  - écrans : `WipeConfirmationScreen`, section `MyDataSection` et `DataActions`, `AppHost` (racine qui rouvre l'app après une suppression) ; paramètres facultatifs dans `TidemarkApp`, la liste, les Réglages, `StartupErrorApp` et `startApp`.
- Dépendance `share_plus` 13.3.1, épinglée exactement (ADR-003). Dépendances transitives ajoutées : `share_plus_platform_interface` 7.2.0, `cross_file` 0.3.5+5, `uuid` 4.6.0.
- Tests existants : les trois trousseaux en mémoire (`open_journal_test`, `database_key_test`, `model_download_config_test`) gagnent `deleteAll`, exigé par le contrat `KeyStore` ; aucune assertion modifiée. `FakeEntryRepository` gagne `allEntriesWithTags`.

### Décisions

- Yanis a donné son accord le 2026-10-15 pour enchaîner sans pause après les tests rouges (« fonce, continue le dev ») : les tests rouges sont montrés ici et dans la PR, puis implémentés (Yanis).
- Dossier du modèle : `models/`, celui du lot G (spec 003, `HttpModelDownloader`), et non `model/` comme l'écrit la spec 005 ; l'architecture technique est corrigée dans cette PR (agent).
- Cache de l'app : `getTemporaryDirectory` (Library/Caches sur iOS, `cacheDir` sur Android, où `share_plus` fait sa copie `share_plus/`) (agent).
- Retour à la liste sans redémarrer le processus : une racine `AppHost` rejoue `startApp` après la suppression ; `startApp` fait déjà la reprise, le marqueur d'installation et l'ouverture d'une base neuve (agent).

### Corrections et limites

- Aucune pour l'instant.

### Prochaine étape

Tests de la spec 005 par le subagent `test-writer`, committés seuls et rouges ; puis implémentation.
