# ADR-002 : Stockage local chiffré

Statut : proposé
Date : 2026-10-14

Contexte : Tidemark garde sur le téléphone les entrées (humeur de 1 à 5, texte facultatif, date et heure de saisie : RM3, RM13, RM16), leurs étiquettes (liste fermée, RM19) et le statut de leur analyse (étiquetée, sans étiquette, non analysée). Exigences :

- **Chiffrement au repos** (RM2), avec une clé protégée par le système : trousseau (Keychain) sur iOS, Keystore sur Android.
- **Aucune donnée hors du téléphone** (RM1) : ni la base ni la clé ne doivent partir par une sauvegarde ou une synchronisation.
- **Suppression d'une entrée** (RM15), avec ses étiquettes.
- **Export JSON** de toutes les entrées et de leurs étiquettes (RM20).
- **Bilan de la semaine** (RM21) : entrées du lundi au dimanche, seulement à partir de 3 entrées ; agrégats calculés par l'app (RM10).
- **Suppression totale** (RM12) : base, clé et modèle local.
- **Tests en CI sans appareil**, comme pour `MoodAnalyzer` (ADR-001).
- Dépôt public sous licence MIT, cible iOS 16.4+ et Android (ADR-001).

Il faut choisir la base, la façon de la chiffrer et la gestion de la clé. Versions et dates relevées sur pub.dev le 2026-10-14 (API `pub.dev/api/packages/<nom>`), sources en fin de document.

## 1. Base et chiffrement

Options envisagées :

- **`drift` + `sqlcipher_flutter_libs`** (prévu par la consigne) : `sqlcipher_flutter_libs` est en fin de vie (version `0.7.0+eol`, 2026-02-15). Depuis `drift` 2.32 et `sqlite3` 3.x, la documentation de `drift` déclare SQLCipher « plus pris en charge avec une configuration simple » et oriente vers SQLite3MultipleCiphers. Écarté sous cette forme ; voir l'option suivante.
- **`drift` 2.35.2 (2026-10-07) + `sqlite3` 3.7.1 (2026-10-13) avec SQLite3MultipleCiphers** : licences MIT (`drift`, `sqlite3`, SQLite3MultipleCiphers ; SQLite est dans le domaine public). Mainteneur unique très actif (Simon Binder), `drift` est « Flutter Favorite », 160/160 points pub.dev, environ 211 issues ouvertes. `sqlite3` 3.x embarque SQLite par un *build hook* ; une ligne de `pubspec.yaml` (`hooks: user_defines: sqlite3: source: sqlite3mc`) remplace SQLite par SQLite3MultipleCiphers (chiffrement de toute la base, ChaCha20-Poly1305 par défaut), sans changer le code. La clé est passée par `PRAGMA key` dans le `setup` de `NativeDatabase`. Requêtes SQL typées, flux réactifs, migrations versionnées avec outils de test (`drift_dev`). **Tests en CI** : `NativeDatabase.memory()` tourne sur la machine hôte ; le hook fournit aussi un binaire SQLite3MultipleCiphers pour Linux et macOS, donc le chiffrement lui-même est testable en CI (vérifier `PRAGMA cipher`, et qu'un fichier ne s'ouvre pas sans la clé). Poids : bibliothèque native d'environ 2,1 Mo (Android arm64) et 1,9 Mo (iOS arm64), non compressée, d'après les binaires de la release `sqlite3-3.7.1`. Retenue.
- **`drift` + `sqlite3` avec `source: sqlcipher`** : toujours disponible dans `sqlite3` 3.x, mais la version de SQLite peut être plus ancienne, le binaire Android lie OpenSSL (5,8 Mo sur arm64, près de 3 fois plus) et la licence de SQLCipher (BSD) s'ajoute. Aucun avantage pour une base neuve. Écarté.
- **`sqflite_sqlcipher` 3.4.1** (2026-08-04, MIT) : fork de `sqflite` avec SQLCipher natif sur iOS et Android, paramètre `password` à l'ouverture. Mainteneur unique, peu de mises à jour. SQL brut sans typage ; règle ProGuard obligatoire sur Android ; build iOS par CocoaPods (pas de Swift Package Manager). **Tests en CI** : impossibles avec le chiffrement, le plugin passe par un canal de plateforme ; il faudrait `sqflite_common_ffi` (SQLite non chiffré) en CI, donc un autre moteur que celui de l'app. Écarté.
- **`sqflite` 2.4.4+2 + chiffrement applicatif des champs** (BSD-2-Clause, avec `cryptography` 2.9.0, Apache-2.0, dernière version 2025-11-21) : seul le texte serait chiffré (AES-GCM) ; l'humeur et les dates resteraient en clair pour que les requêtes du bilan fonctionnent. Fuite de métadonnées sensibles (humeur, horaires), code de cryptographie maison à écrire et à tester, et `sqflite` exige Flutter 3.44. Écarté.
- **`hive_ce` 2.21.0** (2026-10-13, Apache-2.0) : reprise communautaire active de Hive (Hive d'origine sans commit depuis 2024-06). Pur Dart, facile à tester en CI. Mais le chiffrement intégré (`HiveAesCipher`) est un AES-256-CBC sans authentification qui ne chiffre que les valeurs, pas les clés des enregistrements ; aucun moteur de requête : le bilan et l'export parcourent toute la boîte en Dart ; pas de cascade pour supprimer une entrée et ses étiquettes. Écarté.
- **`isar`** : abandonné. Dernière version sur pub.dev 3.1.0+1 du 2023-04-25 (SDK Dart < 3), dépôt sans commit depuis 2025-06 ; la v4, qui devait apporter le chiffrement, n'a jamais été publiée en stable. Ses reprises communautaires (`isar_community` 3.4.1, 2026-10-13, centrée sur la v3 ; `isar_plus` 1.3.9) ne documentent pas de chiffrement au repos (non vérifié dans leur code). Écarté.
- **`objectbox` 5.3.2** (2026-05-20, Apache-2.0 pour le code Dart) : bon support iOS et Android, tests sur l'hôte possibles. Mais aucun chiffrement au repos documenté dans la version gratuite (seulement par une surcouche tierce), et le moteur natif est un binaire dont la licence est distincte du dépôt (« licenses for ObjectBox components ») : incertitude gênante pour un dépôt public. Écarté.

## 2. Gestion de la clé

- **`flutter_secure_storage` 11.2.0** (2026-09-16, BSD-3-Clause, 160/160 points) : trousseau sur iOS ; sur Android depuis la v10, clé AES-GCM enveloppée par une clé RSA du Keystore, minimum API 23. Seule option sérieuse et largement utilisée ; retenue.
- La clé de base est générée par l'app (32 octets de `Random.secure()`), jamais dérivée d'un mot de passe : il n'y a ni compte ni code à saisir (le verrouillage par code ou biométrie n'est pas dans le MVP).
- **iOS** : accessibilité `first_unlock_this_device`. « This device » exclut la clé des sauvegardes migrables et du trousseau iCloud (RM1) ; « first unlock » laisse l'analyse tourner en arrière-plan, écran verrouillé, après le premier déverrouillage.

### Point d'attention : suppression de la clé

- **Suppression totale** (RM12) : dans cet ordre, fermer la base, effacer le fichier de base (et ses fichiers `-wal` et `-shm`), effacer la clé (`delete`), effacer le modèle local. Chaque étape est idempotente : si l'app s'arrête au milieu, la suppression reprend au lancement suivant.
- **Désinstallation sur iOS** : les éléments du trousseau survivent à la désinstallation de l'app. Ce comportement n'est pas documenté par Apple, mais constaté (une bêta d'iOS 10.3 l'avait changé, puis Apple est revenu en arrière). Une personne qui désinstalle Tidemark sans faire de suppression totale laisse donc la clé sur le téléphone. La clé seule ne révèle rien (la base, elle, est effacée avec l'app), mais ce reste contredit l'esprit de RM12.
- **Parade proposée** : un marqueur d'installation (fichier vide dans le dossier de l'app, effacé à la désinstallation). Au lancement, s'il est absent, l'app efface toute clé restée dans le trousseau (`deleteAll`), puis crée le marqueur et une clé neuve. La clé orpheline ne survit donc que jusqu'à la réinstallation, ou indéfiniment si l'app n'est jamais réinstallée : limite à écrire dans le README (lot J). Sur Android, les clés du Keystore sont effacées à la désinstallation.

## 3. Sauvegardes du système (RM1)

À trancher par Yanis, car cela touche RM1 :

- **Android** : la sauvegarde automatique envoie par défaut les fichiers de l'app sur Google Drive. Proposition : `android:allowBackup="false"` (et règles d'extraction de données pour Android 12+). C'est aussi ce que recommande `flutter_secure_storage`, dont les données restaurées sur un autre appareil deviennent illisibles.
- **iOS** : le dossier de l'app part dans la sauvegarde iCloud. Proposition : base et modèle dans `Application Support`, marqués `NSURLIsExcludedFromBackupKey`. Sans cela, la base partirait chiffrée, mais sans sa clé (`this_device`) : illisible, et pourtant sortie du téléphone.
- Conséquence assumée : changer de téléphone fait perdre le journal, sauf export (RM20, RM23).

## Décision

Décision **proposée par l'agent**, à trancher par Yanis : **`drift` 2.35.2 sur `sqlite3` 3.7.1 avec SQLite3MultipleCiphers (`source: sqlite3mc`), clé aléatoire de 256 bits gardée par `flutter_secure_storage` 11.2.0**, base exclue des sauvegardes du système, et marqueur d'installation pour effacer une clé restée dans le trousseau iOS.

- **Chiffrement de toute la base** (RM2), métadonnées comprises, sans code de cryptographie maison.
- **Requêtes SQL** : bilan de la semaine (`WHERE` sur la période, `COUNT`, `AVG`), suppression d'une entrée et de ses étiquettes par clé étrangère `ON DELETE CASCADE` (RM15), export par une simple lecture (RM20).
- **Le même moteur en CI et sur le téléphone**, chiffrement compris : seule option qui le permet parmi celles comparées.
- **Licences MIT** de bout en bout pour la base ; BSD-3-Clause pour la gestion de la clé.
- Le stockage est isolé derrière une interface (nom à fixer dans le glossaire à la spec du lot E), comme `MoodAnalyzer`, et la clé derrière une autre, avec une implémentation factice pour les tests.

## Conséquences

- **Versions de Flutter** : `drift` et `sqlite3` exigent Dart 3.10 et `sqflite` Flutter 3.44 ; le poste de développement est en Flutter 3.47.7 et Dart 3.13.5 depuis le 2026-10-14 (mise à jour faite pour le spike), donc compatible.
- **Téléchargement au build** : le hook de `sqlite3` télécharge le binaire depuis les releases GitHub du paquet, vérifié par empreinte SHA-256. C'est un accès réseau du build et de la CI, pas de l'app : RM1 n'est pas touché. Une option `url_pattern` permet un miroir si besoin.
- **Contre-argument** : `hive_ce` est plus simple (pur Dart, aucun code natif, aucune génération SQL) et tout aussi testable ; mais son chiffrement non authentifié et l'absence de requêtes reportent sur l'app ce que SQLite fait déjà.
- **Mainteneur unique** pour `drift` et `sqlite3`, comme pour `sqflite_sqlcipher` ; atténué par l'adoption (plus de 1,5 million de téléchargements mensuels pour `drift`) et par l'interface de stockage.
- **Versions épinglées exactement** pour `drift`, `sqlite3` et `flutter_secure_storage`, comme `llamadart` : un changement du hook peut changer le moteur chiffré en silence. Un test vérifie au démarrage que `PRAGMA cipher` répond (méthode conseillée par la documentation de `drift`).
- **Modèle de données** (tables, colonnes, fuseau horaire des dates pour découper la semaine du lundi au dimanche) : fixé dans la spec du lot E, puis reporté dans l'architecture technique. Non tranché ici.

### Incertitudes à lever au lot D

- **Format de la clé** : `PRAGMA key` avec une phrase dérive la clé par PBKDF2 (64 007 itérations par défaut pour ChaCha20-Poly1305), ce qui ralentit chaque ouverture. Le passage d'une clé brute de 256 bits, sans dérivation, est à vérifier dans la documentation de SQLite3MultipleCiphers ; à défaut, mesurer le temps d'ouverture sur l'iPhone 15 Pro.
- **Coexistence des hooks natifs** de `sqlite3` et de `llamadart` dans la même app : non essayée.
- **Poids réel** dans l'app compressée : seules les tailles des binaires sont connues, à mesurer sur l'IPA et l'APK.
- **Effacement à la désinstallation sur iOS** : la parade du marqueur est à tester sur l'iPhone 15 Pro (désinstaller, réinstaller, vérifier que l'ancienne clé a disparu).
- **Chiffrement de `isar_community`, `isar_plus` et d'`objectbox`** : seulement cherché dans leur documentation, pas dans leur code.

## Sources

- pub.dev (versions, dates, licences, points), relevés le 2026-10-14 : [drift](https://pub.dev/packages/drift), [sqlite3](https://pub.dev/packages/sqlite3), [sqlcipher_flutter_libs](https://pub.dev/packages/sqlcipher_flutter_libs), [sqflite_sqlcipher](https://pub.dev/packages/sqflite_sqlcipher), [sqflite](https://pub.dev/packages/sqflite), [cryptography](https://pub.dev/packages/cryptography), [hive_ce](https://pub.dev/packages/hive_ce), [isar](https://pub.dev/packages/isar), [isar_community](https://pub.dev/packages/isar_community), [objectbox](https://pub.dev/packages/objectbox), [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage).
- Chiffrement avec `drift` : [drift.simonbinder.eu/platforms/encryption](https://drift.simonbinder.eu/platforms/encryption/) ; tests : [drift.simonbinder.eu/testing](https://drift.simonbinder.eu/testing/).
- Options du hook de `sqlite3` : [doc/hook.md](https://github.com/simolus3/sqlite3.dart/blob/main/sqlite3/doc/hook.md) ; tailles des binaires : [release sqlite3-3.7.1](https://github.com/simolus3/sqlite3.dart/releases/tag/sqlite3-3.7.1).
- SQLite3MultipleCiphers (licence MIT, v2.6.1 du 2026-10-12) : [dépôt](https://github.com/utelle/SQLite3MultipleCiphers), [ChaCha20-Poly1305](https://utelle.github.io/SQLite3MultipleCiphers/docs/ciphers/cipher_chacha20/).
- Chiffrement de `hive_ce` : [`hive_aes_cipher.dart`](https://github.com/IO-Design-Team/hive_ce/blob/main/hive/lib/src/crypto/hive_aes_cipher.dart).
- ObjectBox, licence des composants : [README de objectbox-dart](https://github.com/objectbox/objectbox-dart/blob/main/objectbox/README.md).
- `flutter_secure_storage` (ciphers Android, sauvegarde automatique, accessibilité iOS) : [README](https://github.com/juliansteenbakker/flutter_secure_storage/blob/develop/flutter_secure_storage/README.md).
- Trousseau iOS après désinstallation : [Apple Developer Forums, thread 36442](https://developer.apple.com/forums/thread/36442) et [thread 72271](https://developer.apple.com/forums/thread/72271).
