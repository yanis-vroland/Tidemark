# Journal : statuts après les merges des PR #16 à #19

Branche `docs/statuts-apres-merges`.

## 2026-10-14 21:39

### Fait

- Vérifié : le dernier commit de chacune des PR #16, #17, #18 et #19 est sur `main`. Les 438 tests sont verts sur `main`.
- Cahier des charges : les lignes des lots G et I, perdues à la résolution des conflits de merge, sont rétablies, et chaque spec a son statut. La ligne qui doublait RM30 (numéros « réservés ») est remplacée par une phrase sur les numéros non attribués.
- Specs 003 à 006 et leurs maquettes : « validée (Yanis, merge de la PR) ». ADR-003 : accepté. Index des ADR et section sécurité de l'architecture technique mis à jour.
- Issue des captures PNG des maquettes créée, avec l'accord de Yanis : https://github.com/yanis-vroland/Tidemark/issues/20.

### Décisions

- Le merge des PR de specs par Yanis vaut validation des specs, des maquettes et de l'ADR-003, comme annoncé avant le merge (Yanis, 2026-10-14).

### Corrections et limites

- Lot F marqué « livrée » dans le cahier des charges, mais le test humain sur l'iPhone par Yanis n'a pas encore eu lieu. L'agent a fait un essai sur l'émulateur Android et le simulateur iOS.

### Prochaine étape

Lot G : implémentation de la spec 003 (téléchargement du modèle), puis de la spec 004 (étiquetage).

## 2026-10-15 09:26

### Fait

- Suites de la revue IA de la PR #21 :
  - RM1 renvoie à l'ADR-003 sans « proposé » ;
  - la phrase sur les numéros RM non attribués n'est plus qu'à un seul endroit ;
  - nouveau statut « implémentée » (mergée, test humain en attente), distinct de « livrée » (test humain positif). Le lot F y passe.

### Décisions

- Statut « implémentée » ajouté au cahier des charges : le merge n'est pas le « done » tant que le test humain n'a pas eu lieu (agent).
- Spec 001 laissée telle quelle : la validation de CA31 à CA36 attend toujours Yanis.

### Corrections et limites

- L'historique de l'ADR-002 n'est pas modifié : c'est une entrée datée.

### Prochaine étape

Merge de la PR par Yanis.
