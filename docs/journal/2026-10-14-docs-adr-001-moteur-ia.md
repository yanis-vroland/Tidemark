# Journal : ADR-001, moteur d'IA local

Branche `docs/adr-001-moteur-ia`. Les mesures viennent de la branche `spike/moteur-ia` (non mergée) et de son journal.

## 2026-10-14 13:50

### Fait

- Brouillon de l'ADR-001 : options écartées et pourquoi, modèles, mesures sur émulateur et simulateur à modèle égal, décision proposée (`llamadart` + Qwen2.5-1.5B Q4_K_M + schéma JSON), conséquences.

### Décisions

- Décision proposée par l'agent ; Yanis tranche après les mesures sur iPhone 15 Pro.

### Corrections et limites

- Section « iPhone 15 Pro » vide : l'iPhone n'était pas branché.

### Prochaine étape

Mesures sur iPhone 15 Pro, puis ADR complété, PR au statut « proposé ».

## 2026-10-14 14:35

### Fait

- Mesures sur iPhone 15 Pro ajoutées à l'ADR-001 (branche `spike/moteur-ia`, `spike/mesures/2026-10-14-iphone-15-pro.md`) ; statut « proposé ».
- Décision proposée inchangée ; arguments mis à jour avec les chiffres de l'iPhone ; nouvelle conséquence : chargement en arrière-plan.

### Décisions

- Décision proposée par l'agent ; Yanis tranche, notamment sur l'intérêt d'un essai `llamadart` avec un GGUF q8.

### Corrections et limites

- Mémoire de `flutter_edge_ai` non vérifiée avec Instruments : la RSS ne compte sans doute pas le modèle projeté en mémoire.

### Prochaine étape

Yanis tranche l'ADR-001. Une fois accepté : architecture technique (index des ADR, composant d'IA) dans la même PR, puis lot D (socle Flutter).

## 2026-10-14 14:51

### Fait

- Suites de la revue IA de la PR #8 : mesures versionnées dans `docs/adr/001-mesures/`, licences des paquets et moteurs natifs, taille de l'échantillon et paramètres, plateformes minimales sourcées, formulations sur le README corrigées, ADR dans l'index.
- Test en mode avion sur l'iPhone 15 Pro (Yanis a coupé le réseau) : 20/20 valides, médiane 0,84 s.
- ADR-001 passé en « accepté » ; plan (lot B coché), architecture technique (vue d'ensemble du composant d'IA, index) et `CLAUDE.md` (section Architecture) mis à jour.

### Décisions

- ADR-001 accepté par Yanis (« ok ça marche », 2026-10-14) : `llamadart` + Qwen2.5-1.5B Q4_K_M + schéma JSON, sans essai q8 préalable. Acceptation conditionnée par l'agent au test en mode avion, réussi.

### Corrections et limites

- Le test en mode avion n'avait pas été fait avant la première version de l'ADR, alors que le plan l'exigeait : relevé par la revue IA.
- Le mode avion prouve que l'analyse fonctionne sans réseau, pas qu'aucune connexion n'est tentée ; ce point repose sur la lecture du code de `llamadart`.

### Prochaine étape

Yanis merge la PR #8. Ensuite : nettoyage de fin de spike, puis lot C (charte, à partir de l'artefact existant) et lot D (socle Flutter).
