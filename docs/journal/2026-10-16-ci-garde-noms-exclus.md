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
