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

## 2026-10-15 16:30

### Fait

- Tests de la spec 005 écrits par le subagent `test-writer` à partir de la spec et des maquettes, avant toute implémentation : 295 tests nouveaux, dont 270 en échec et 25 qui passent sans implémentation (gardes « rien ne se passe » et forme du squelette, chacun avec un pendant rouge). Les 968 tests existants restent verts (`flutter test` : 993 verts, 270 rouges, tous dans les nouveaux fichiers).
- Rouges par fichier (raison : `UnimplementedError`, section ou écran vides, reprise et marqueur absents au démarrage) : `journal_exporter_test` 28, `journal_export_test` 22, `journal_wiper_test` 55, `install_marker_test` 12, `all_entries_with_tags_test` 7, `startup_wipe_test` 24, `my_data_section_test` 27, `wipe_confirmation_screen_test` 64, `startup_error_wipe_test` 16, `wipe_flow_test` 6, `list_after_wipe_test` 5, `app_host_test` 2, `share_sheet_only_on_tap_test` 2.
- Harnais : `test/support/fake_share_sheet.dart`, `test/support/wipe_harness.dart`.

### Décisions

- Apostrophe droite dans « Préparation de l'export… » et « Réessayer l'export », comme la spec (la maquette a l'apostrophe typographique) (agent).
- JSON octet pour octet : la règle normative de la spec (`JsonEncoder.withIndent('  ')`) prime sur l'exemple, qui écrit chaque étiquette sur une ligne ; le test l'écrit en dur au format de l'encodeur (agent).
- CA20 : « Réessayer » actif sans réécrire « SUPPRIMER », il rejoue `wipe()` (maquette) (agent).

### Corrections et limites

- CA10 au démarrage force l'échec de la purge par `chmod 555` : sans effet si les tests tournent en root.
- CA32 : si l'effacement de la clé échoue à une nouvelle installation, la base neuve prend la clé restante ; au démarrage suivant, la base existe et la clé n'est plus effacée. Conforme à la table de la spec, mais à signaler.

### Prochaine étape

Implémentation jusqu'au vert, puis contrôle par mutation des garde-fous et revues.

## 2026-10-16 08:19

### Fait

- Implémentation de la spec 005 : `JournalExporter` (JSON version 1), `JournalExport` (purge, lecture, fichier dans `<cache>/tidemark-export/`, feuille de partage, effacement dans tous les cas), `SharePlusShareSheet`, `JournalWiper` (marqueur, fermeture du journal, base, clé, `models/`, dossiers temporaires, marqueur effacé), `checkInstallMarker`, `DriftEntryRepository.allEntriesWithTags`, `AppHost`.
- Écrans : section « Mes données » des Réglages, `WipeConfirmationScreen`, message de fin sur la liste vide, `StartupErrorApp` (bouton « Tout supprimer et repartir de zéro », cas « La suppression n'est pas terminée », écran qui défile). Boutons `DangerButton` et `QuietButton` (texte et bordure, fond `surface-raised`), jetons de la charte seulement.
- `startApp` : purge des fichiers temporaires d'export, reprise de `wipe-pending`, marqueur d'installation, puis ouverture ; export et suppression branchés dans les Réglages.
- `AppDatabase.close` rendu idempotent : un second appel attend la même fermeture au lieu de rester bloqué.
- `flutter test` : 1 263 verts, 0 rouge (aussi avec `TZ=UTC`) ; `dart analyze --fatal-infos` et `dart format` propres.

### Décisions

- La file d'analyse n'est arrêtée qu'une fois par suppression, même si celle-ci est reprise après un échec de fermeture de la base : un second `AnalysisQueue.stop()` peut ne jamais rendre la main. `lib/analysis/` n'est pas modifié (un autre agent y travaille) ; le point est signalé dans la PR (agent).
- Libellé du champ de confirmation : texte visible fusionné dans le nœud du champ (`MergeSemantics`), plutôt qu'un `labelText` qui aurait doublé le texte (agent).

### Corrections et limites

- Deux retouches de harnais, sans assertion modifiée, signalées dans la PR :
  - `test/ui/wipe_flow_test.dart` : la fermeture des bases en fin de test se fait dans le temps simulé, en alternant temps réel et temps simulé, et seule la file de l'app affichée est arrêtée (celle de l'app effacée l'est déjà) ; sinon le test restait bloqué indéfiniment ;
  - `test/support/wipe_harness.dart` : `scrollTo` fait un `pump` après `scrollUntilVisible`, dont le `ensureVisible` final ne met pas la page en forme quand la cible est déjà construite (écrans non paresseux).

### Prochaine étape

Contrôle par mutation des garde-fous, revues `reviewer` et `security-reviewer`, documents de référence, PR.
