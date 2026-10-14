# Journal : téléchargement du modèle local (spec 003)

Branche `feat/modele-local`.

## 2026-10-14 21:43

### Fait

- Valeurs de `ModelSource` relevées sur Hugging Face, révision `91cad51170dc346986eccefdc2dd33a9da36ead9` du dépôt `Qwen/Qwen2.5-1.5B-Instruct-GGUF` :
  - taille : 1 117 320 736 octets, soit « 1,1 Go » ;
  - SHA-256 : `6a1a2eb6d15622bf3c96857206351ba97e1af16c30d7a74ee38970e434e9407e`.
  - Vérifiées par un téléchargement complet (`curl -L`, puis `shasum -a 256`), fichier effacé ensuite.
  - Première redirection : `302` vers `https://us.aws.cdn.hf.co/xet-bridge-us/…`, hôte admis par le suffixe `.hf.co`.
- Squelette de la spec 003, sans comportement :
  - `ModelSource`, `ModelState`, `ModelTransport`, `IoModelTransport`, `ModelDownloader`, `HttpModelDownloader` ;
  - écran `ModelDownloadScreen` vide ;
  - réglage « proposition affichée » dans `SettingsRepository` ;
  - téléchargeur passé à `TidemarkApp`, à la liste, à la saisie et aux Réglages ;
  - `checkAtStartup` appelé au démarrage.
- Faux : `FakeModelDownloader`, `FakeModelTransport` ; `FakeSettingsRepository` complété.
- Dépendance directe `crypto` 3.0.7 (déjà présente comme dépendance transitive) : calcul du SHA-256 au fil de l'eau.

### Décisions

- Téléchargeur obligatoire dans les écrans, comme les réglages au lot F : aucun repli silencieux en production (agent).

### Corrections et limites

- Tests modifiés, à signaler : 35 constructeurs des tests des specs 001 et 002 reçoivent `downloader: FakeModelDownloader()`, et les imports relatifs des tests touchés sont triés. Changement mécanique, aucune vérification retirée.

### Prochaine étape

Tests de la spec 003 par le subagent `test-writer`, committés seuls et rouges ; puis implémentation.
