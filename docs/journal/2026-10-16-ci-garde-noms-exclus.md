# Journal : ci/garde-noms-exclus

Garde-fou de CI qui refuse les noms de clients et d'employeurs réels dans les fichiers suivis et dans les commits de la PR, sans jamais écrire ces noms dans le dépôt.

## 2026-10-16 11:22

### Fait

- Lecture des scripts de garde-fous existants (`.github/scripts/verifier-journal.sh` et son test `tests/verifier-journal.sh`) et des workflows de CI.
- Tests rouges écrits par le subagent `test-writer` : `tests/verifier-noms-exclus.sh`, 54 vérifications (CA1 à CA14 ci-dessous), noms fictifs seulement (« Acmecorp », « Globex », « Initech »).
- Exécution rouge : 54 vérifications sur 54 en échec, code 1. Raison : `scripts/verifier-noms-exclus.sh` absent (code 127 à chaque lancement), et `.excluded-names` absent du `.gitignore` (CA14).

Critères retenus (sans spec : changement de CI, sans effet sur l'app) :

- CA1 liste lue dans `EXCLUDED_NAMES`, séparée par des virgules, espaces et entrées vides ignorés ;
- CA2 à défaut, fichier local `.excluded-names` ; la variable prime ;
- CA3 contenu des fichiers suivis (pas des fichiers non suivis), chemin cité ;
- CA4 insensible à la casse ; CA5 sous-chaîne ;
- CA6 messages des commits de la plage (défaut `origin/main..HEAD`), SHA cité, commits hors plage ignorés ;
- CA7 nom et e-mail d'auteur et de committer ;
- CA8 chemin des fichiers suivis ;
- CA9 aucune sortie ne contient un nom de la liste ;
- CA10 liste vide en CI : échec qui nomme `EXCLUDED_NAMES` ; CA11 hors CI : avertissement, code 0 ;
- CA12 dépôt propre : 0 ; CA13 usage invalide : 2 ; CA14 `.excluded-names` ignoré par Git.

### Décisions

- Conception imposée par l'agent principal, par délégation de Yanis du 2026-10-16 : liste dans `EXCLUDED_NAMES` ou `.excluded-names`, `git grep -i -F`, plage `origin/main..HEAD`, sortie limitée au fichier ou au SHA, échec en CI sans liste, job dans le workflow existant.
- Yanis a donné son accord le 2026-10-16 pour enchaîner sans pause après les tests rouges (« fonce, continue le dev ») et a délégué les décisions à l'agent (« fonce, sois autonome sur les décisions et finis l'app »).
- Ajouts de l'agent, par délégation de Yanis du 2026-10-16 : vérifier aussi le chemin des fichiers (un nom de fichier peut contenir un nom) et l'auteur et le committer des commits (un e-mail professionnel révèle l'employeur) ; un chemin qui contient un nom est désigné par son objet Git, jamais affiché.
- Job placé dans `garde-fous.yml`, à côté du contrôle du journal et de gitleaks (agent, par délégation de Yanis du 2026-10-16).

### Corrections et limites

- Pas de spec : changement de CI sans effet sur le comportement de l'app (CLAUDE.md, méthode, point 1). Les critères sont listés ici et dans la PR.

### Prochaine étape

- Implémenter `scripts/verifier-noms-exclus.sh`, le job de CI, la documentation, puis le contrôle par mutation.

## 2026-10-16 11:26

### Fait

- `scripts/verifier-noms-exclus.sh` : liste lue dans `EXCLUDED_NAMES`, à défaut dans `.excluded-names` ; recherche dans le contenu (`git grep -l -i -F`, binaires compris) et le chemin des fichiers suivis, dans le message, l'auteur et le committer des commits de la plage. Motifs passés par un fichier temporaire, jamais sur la ligne de commande. Sortie : chemin du fichier, objet Git si le chemin contient un nom, SHA du commit.
- `.excluded-names` ajouté au `.gitignore`.
- Job « Noms exclus » dans `garde-fous.yml` (`fetch-depth: 0`, secret `EXCLUDED_NAMES`, plage `origin/<base>..HEAD`) ; test et shellcheck du script ajoutés au job des garde-fous.
- CLAUDE.md (« Stack et commandes ») et architecture technique (« Sécurité », « Infrastructure ») documentés, sans aucun nom.
- Tests au vert : 53 vérifications sur 53, shellcheck propre. Sur le dépôt réel : sans liste, avertissement et code 0 en local, échec en CI ; avec `EXCLUDED_NAMES=Acmecorp`, seuls ce journal et le test sont cités, sans le nom.

Contrôle par mutation (chaque protection désactivée une fois, script restauré ensuite, 0 échec après restauration) :

| Mutation | Vérifications en échec |
| --- | --- |
| M1 contenu des fichiers non cherché | 21 |
| M2 messages des commits non cherchés | 6 |
| M3a casse respectée dans les fichiers (`-i` retiré) | 4 |
| M3b casse respectée dans les messages, l'identité et les chemins | 6 |
| M4 liste vide acceptée en CI (code 0) | 2 (CA10) |
| M5a ligne trouvée affichée (`git grep` sans `-l`) | 13 |
| M5b liste des noms affichée avec le message d'échec | 17, toutes CA9 |
| M6 chemins des fichiers non cherchés | 2 (CA8) |
| M7 auteur et committer non cherchés | 8 |
| M8 chemin contenant un nom affiché tel quel | 2 (CA9 sur CA8) |
| M9 fichier `.excluded-names` ignoré | 4 (CA2) |
| M10 entrées vides gardées comme motifs | 4 (CA1) |
| M11 plage ignorée (tout l'historique) | 3 (CA6) |

### Décisions

- Fichiers binaires compris dans la recherche : plus strict, au risque d'un faux positif sur un nom très court (agent, par délégation de Yanis du 2026-10-16).
- Liste vide détectée en CI dès que `CI` est définie et ne vaut ni `false` ni `0` (agent, par délégation de Yanis du 2026-10-16).
- `.excluded-names` qui ne contient que des lignes vides : traité comme une liste absente (échec en CI, avertissement en local). Non couvert par un test dédié ; même chemin de code que la variable vide (CA10).

### Corrections et limites

- Non vérifiés : titre et description de la PR, noms de branche, historique déjà mergé sur `main`, qui contient déjà des noms exclus (le réécrire est une décision de Yanis). Un secret n'est pas transmis à une PR ouverte depuis un fork : le dépôt n'en reçoit pas.
- Je ne connais pas la liste réelle : je n'ai pas pu vérifier que `main` passe déjà le contrôle. À vérifier par Yanis en local avec son `.excluded-names` avant le merge.
- Test humain : sans objet (aucun changement de comportement de l'app).

### Prochaine étape

- Revues `reviewer` et `security-reviewer`, puis PR.

## 2026-10-16 11:31

### Fait

- Revues `reviewer` et `security-reviewer` : aucun point bloquant ; points « à corriger » repris ci-dessous.
- Tests ajoutés avant correction (écrits par l'agent principal de la branche, pas par `test-writer`, pour aller vite sur des suites de revue) : CA15 à CA21, et CA8 renforcé (l'objet Git cité n'est pas vide ; le test d'origine n'est pas modifié, un cas s'ajoute).
  - CA15 en CI, seul le secret compte (`.excluded-names` ignoré) ; un `.excluded-names` suivi par Git est refusé ; fichier fait de lignes vides traité comme absent.
  - CA16 titre, description et branche de la PR (`PR_TITLE`, `PR_BODY`, `PR_HEAD_REF`).
  - CA17 chemins accentués ou avec espaces : cités en clair, nom accentué détecté et jamais affiché, même échappé en octal.
  - CA18 lignes ajoutées par chaque commit de la plage (un nom ajouté puis retiré dans la PR reste dans l'historique publié) ; une PR qui retire un nom est acceptée.
  - CA19 option `--all` : tout l'historique, à lancer avant le passage en public.
  - CA20 nom de moins de 3 caractères refusé (code 2), sans l'afficher.
  - CA21 une erreur de `git grep`, `log`, `show`, `ls-files` ou `rev-list` donne le code 2, jamais « rien trouvé ».
- Exécution rouge : 20 vérifications en échec sur 85, chacune pour l'absence du comportement. CA17 montre la fuite signalée par les revues : `"docs/Acm\303\251 notes.md"` affiché.

### Décisions

- Suites de revue retenues (agent, par délégation de Yanis du 2026-10-16) : toutes les corrections « à corriger » des deux revues, plus le motif trop court, `LC_ALL=C.UTF-8`, le masquage de chaque nom dans les journaux de CI (`::add-mask::`), l'exécution de la version du script de la branche de base, `actions/checkout` épinglé par SHA avec `persist-credentials: false`.
- SHA du commit fautif retiré de ce journal : il désignerait où lire les noms une fois le dépôt public.

### Corrections et limites

- Le journal déjà mergé de `docs/readme-final` cite ce SHA ; il ne peut pas être modifié ici (`verifier-journal.sh`). À traiter lors de la réécriture de l'historique.

### Prochaine étape

- Corriger le script et le workflow jusqu'au vert, puis refaire le contrôle par mutation.

## 2026-10-16 11:52

### Fait

- Script corrigé : chemins lus séparés par NUL (`-z`, `core.quotePath=false`, pathspec `:(literal)`), `LC_ALL=C.UTF-8`, `pipefail`, code 2 sur toute erreur de Git, fichier `.excluded-names` ignoré en CI et refusé s'il est suivi, lignes ajoutées par chaque commit de la plage, `PR_TITLE`, `PR_BODY`, `PR_HEAD_REF`, `--all`, nom de moins de 3 caractères refusé.
- Workflow : `actions/checkout` épinglé par SHA avec `persist-credentials: false` ; étape `::add-mask::` pour chaque nom ; sur une PR, version du script de la branche de base (repli sur celle de la PR tant qu'elle n'existe pas sur `main`, cas de cette PR) ; titre, description et branche passés par `env` ; sur un push, plage du push (`before..HEAD`).
- Documentation : CLAUDE.md réduit à la commande et à un renvoi ; architecture technique détaillée (liste, non-divulgation, CI, limites et prérequis avant le passage en public) ; « deux workflows » corrigé en « trois ».
- CA3 renforcé après mutation (une seule ligne de rapport par fichier ; cas ajouté, aucun test existant modifié).
- Tests au vert : 86 vérifications sur 86, shellcheck propre. `dart format` et `dart analyze --fatal-infos` au vert. `flutter test` : 1 774 tests passent, 1 échoue, `analysis_queue_lifecycle_test.dart`, « CA34 : un désabonnement qui lève… » (`Bad state: désabonnement impossible`), déjà sur `main` : cette branche ne touche aucun fichier Dart.

Contrôle par mutation, version finale (script restauré ensuite : 0 échec) :

| Mutation | Vérifications en échec |
| --- | --- |
| M1 contenu des fichiers non cherché | 23 |
| M2 messages des commits non cherchés | 6 |
| M3a casse respectée dans `git grep` | 4 |
| M3b casse respectée dans les autres recherches | 12 |
| M4 liste vide acceptée en CI | 4 |
| M5a ligne trouvée affichée (`git grep` sans `-l`) | 1 (CA3 renforcé ; avant renforcement, 0 : le masquage du chemin cachait la ligne) |
| M5b liste affichée à l'échec | 26 (CA9) |
| M6 chemins non cherchés | 5 |
| M7 auteur et committer non cherchés | 8 |
| M8 chemin jamais masqué | 6 (CA9) |
| M9 `.excluded-names` ignoré hors CI | 4 |
| M10 entrées vides gardées | 8 |
| M11 plage ignorée (tout l'historique) | 5 |
| M12 `.excluded-names` lu en CI | 1 (CA15) |
| M13 `.excluded-names` suivi accepté | 1 (CA15) |
| M14 titre, description, branche non vérifiés | 6 |
| M15 `core.quotePath` par défaut | 0 : mutation équivalente, `-z` n'échappe jamais les chemins ; gardé pour les en-têtes de diff |
| M16 diff des commits non lu | 4 |
| M17 lignes retirées lues aussi | 1 (CA18) |
| M18 `--all` sans effet | 2 (CA19) |
| M19 nom trop court accepté | 1 (CA20) |
| M20 à M23 erreur de `git grep`, `log` (les deux appels), `show`, `ls-files` ignorée | 1 chacune (CA21) |
| M24 objet Git non cité | 1 (CA8) |

### Décisions

- Branche spéciale `--all` retirée : `git rev-list --all` la comprend déjà (mutation M18 d'abord équivalente) (agent, par délégation de Yanis du 2026-10-16).
- Un titre modifié après l'ouverture de la PR ne relance pas le job : `types` n'est pas changé, pour ne pas relancer les autres jobs du workflow ; le commit de merge revoit le titre au push sur `main`. Limite documentée (agent, par délégation de Yanis du 2026-10-16).

### Corrections et limites

- Test humain : sans objet (aucun changement de comportement de l'app).
- Le test CA34 de `analysis_queue_lifecycle_test.dart` échoue sur `main` : signalé dans la PR, non corrigé ici (hors sujet).
- Je ne connais pas la liste réelle : rien ne garantit que `main` passe le contrôle des fichiers. Yanis doit le vérifier avec sa liste avant le merge.

### Prochaine étape

- Yanis : créer le secret `EXCLUDED_NAMES`, lancer le script en local avec sa liste, puis relire et merger la PR.
