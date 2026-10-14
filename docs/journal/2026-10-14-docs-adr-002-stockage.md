# Journal : ADR-002, stockage local chiffré

Branche `docs/adr-002-stockage`.

## 2026-10-14 15:04

### Fait

- Recherche sur pub.dev (API), GitHub et les documentations : `drift` + `sqlite3`, `sqlcipher_flutter_libs`, `sqflite_sqlcipher`, `sqflite` + chiffrement des champs, `hive_ce`, `isar` et ses reprises, `objectbox`, `flutter_secure_storage`.
- Brouillon de l'ADR-002 au statut « proposé » : options et pourquoi, gestion de la clé, suppression totale, désinstallation sur iOS, sauvegardes du système, décision proposée, conséquences, incertitudes, sources.
- ADR-002 ajouté à l'index de l'architecture technique, au statut « proposé ».

### Décisions

- Décision proposée par l'agent : `drift` 2.35.2 sur `sqlite3` 3.7.1 avec SQLite3MultipleCiphers, clé gardée par `flutter_secure_storage` 11.2.0. Yanis tranche.
- Exclusion de la base des sauvegardes Android et iCloud : proposée par l'agent, à trancher par Yanis (touche RM1).

### Corrections et limites

- La consigne prévoyait `drift` + `sqlcipher_flutter_libs` : ce paquet est en fin de vie (`0.7.0+eol`) ; le chiffrement passe désormais par une option du hook de `sqlite3`.
- Rien n'a été exécuté : poids réel dans l'app, format de clé brute, coexistence avec `llamadart` et parade du trousseau iOS restent à vérifier au lot D.
- Chiffrement d'`isar_community`, `isar_plus` et `objectbox` cherché seulement dans leur documentation.

### Prochaine étape

Yanis relit l'ADR-002 et tranche ; puis PR au statut « proposé » (non ouverte par l'agent à sa demande).

## 2026-10-14 15:04

### Fait

- Relecture par l'agent principal : versions de `sqlcipher_flutter_libs` (fin de vie), `drift`, `sqlite3` et `flutter_secure_storage` vérifiées sur pub.dev.
- Correction : le Flutter du poste est en 3.47.7 depuis la mise à jour du spike, pas en 3.35.3.

### Décisions

- Aucune : la décision reste à Yanis.

### Corrections et limites

- Le subagent s'était fié à `CLAUDE.md` et au plan, qui citaient encore Flutter 3.35.3.

### Prochaine étape

Yanis tranche l'ADR-002 et la question de l'exclusion des sauvegardes (Android, iCloud). Ensuite : lot D.
