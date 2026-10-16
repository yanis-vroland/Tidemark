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

- Non vérifiés : titre et description de la PR, noms de branche, historique déjà mergé sur `main` (dont le commit 462ceb1, qui reste dans l'historique ; le réécrire est une décision de Yanis). Un secret n'est pas transmis à une PR ouverte depuis un fork : le dépôt n'en reçoit pas.
- Je ne connais pas la liste réelle : je n'ai pas pu vérifier que `main` passe déjà le contrôle. À vérifier par Yanis en local avec son `.excluded-names` avant le merge.
- Test humain : sans objet (aucun changement de comportement de l'app).

### Prochaine étape

- Revues `reviewer` et `security-reviewer`, puis PR.
