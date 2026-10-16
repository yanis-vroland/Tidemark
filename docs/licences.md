# Licences

Relevé du 2026-10-16 (lot J du [plan](plan.md)), avant le passage du dépôt en public. Le code de Tidemark est sous licence [MIT](../LICENSE). Toutes les licences ci-dessous sont compatibles avec un dépôt public sous MIT ; aucune n'est copyleft (GPL, LGPL, MPL).

## Modèle, moteur, polices et icônes

| Composant | Version | Licence | Où c'est vérifié |
| --- | --- | --- | --- |
| Modèle Qwen2.5-1.5B-Instruct, GGUF Q4_K_M | révision `91cad511…` de `Qwen/Qwen2.5-1.5B-Instruct-GGUF` | Apache-2.0 | Hugging Face, à la révision épinglée par `lib/model/model_source.dart` : fichier `LICENSE` (Apache License 2.0), en-tête de `README.md` (`license: apache-2.0`) et API (`cardData.license`). Le modèle n'est pas dans le dépôt : l'app le télécharge sur l'appui de la personne. |
| llama.cpp, moteur natif de `llamadart` | `llamadart-native` v0.6.0-2 | MIT | `gh api repos/ggml-org/llama.cpp` et `repos/leehack/llamadart-native` (`license.spdx_id`) |
| SQLite3MultipleCiphers, moteur natif de `sqlite3` | celle du hook de `sqlite3` 3.7.1 | MIT | `gh api repos/utelle/SQLite3MultipleCiphers` |
| Police Bricolage Grotesque | variable | SIL OFL 1.1 | `assets/fonts/OFL-BricolageGrotesque.txt`, embarqué avec la police |
| Police Figtree | variable | SIL OFL 1.1 | `assets/fonts/OFL-Figtree.txt`, embarqué avec la police |
| Material Icons (`MaterialIcons-Regular.otf`, livré par Flutter) | celle du SDK Flutter 3.47.7 | Apache-2.0 | `gh api repos/google/material-design-icons` ; 13 icônes utilisées dans `lib/`, la police est réduite à ces icônes au build |

L'OFL autorise l'embarquement des polices dans une app et leur redistribution avec leur fichier de licence : les deux fichiers OFL restent dans `assets/fonts/`.

## Dépendances Dart

Relevé : `flutter pub deps --json`, puis le fichier `LICENSE` de chaque paquet dans `~/.pub-cache/hosted/pub.dev/<paquet>-<version>/` (pubspec n'a pas de champ licence). 116 paquets, directs, de développement et transitifs ; aucun sans fichier de licence.

### Directes

| Paquet | Version | Licence |
| --- | --- | --- |
| `characters` | 1.4.1 | BSD-3-Clause |
| `crypto` | 3.0.7 | BSD-3-Clause |
| `drift` | 2.35.2 | MIT |
| `flutter` (SDK) | 3.47.7 | BSD-3-Clause |
| `flutter_secure_storage` | 11.2.0 | BSD-3-Clause |
| `llamadart` | 0.12.0 | MIT |
| `path` | 1.9.1 | BSD-3-Clause |
| `path_provider` | 2.1.6 | BSD-3-Clause |
| `share_plus` | 13.3.1 | BSD-3-Clause |
| `sqlite3` | 3.7.1 | MIT |
| `url_launcher` | 6.3.3 | BSD-3-Clause |

### Développement

| Paquet | Version | Licence |
| --- | --- | --- |
| `build_runner` | 2.16.2 | BSD-3-Clause |
| `drift_dev` | 2.35.1 | MIT |
| `flutter_lints` | 6.0.0 | BSD-3-Clause |
| `flutter_test` (SDK) | 3.47.7 | BSD-3-Clause |

### Transitives (101 paquets)

| Licence | Paquets |
| --- | --- |
| BSD-3-Clause | 91, dont les SDK `flutter_web_plugins` et `sky_engine` |
| MIT | `archive`, `dinja`, `posix`, `sqlparser`, `uuid`, `yaml` |
| Apache-2.0 | `clock`, `fake_async`, `material_color_utilities` |
| BSD-2-Clause | `recase` |

Total : 11 + 4 + 101 = 116 paquets. Le classement vient du texte de chaque fichier `LICENSE` (script de relevé non versionné) ; à refaire à chaque ajout de dépendance, que la PR justifie déjà (`CLAUDE.md`, « Interdits »).
