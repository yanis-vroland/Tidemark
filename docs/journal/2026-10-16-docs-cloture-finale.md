# Journal : docs/cloture-finale

Mise à jour finale après le merge des PR #40 à #45.

## 2026-10-16 16:07

### Fait

- Chiffres du README recalculés sur `main` (7622ea0) : 1 840 tests (80 fichiers), tous au vert ; 214 critères d'acceptation dans les 6 specs ; 37 PR mergées ; 5 ADR.
- README, limite « Intégrité du moteur et du modèle » : empreinte par la bibliothèque du système (PR #44), environ 1 s sur Mac M3 contre 9,4 à 23,9 s en Dart, non mesuré sur l'iPhone ni Android.
- README, « Tests humains en attente » : les PR #43 et #44 ont été mergées avant leur test humain, c'est écrit. « Revues IA » : la perte de code au merge de la PR #37, réparée par la #41, est écrite.
- ADR-004 : la section de l'option F passe de « à confirmer par Yanis avec la PR » à « confirmé par Yanis au merge de la PR #44 », mesure sur l'iPhone à faire.
- `docs/plan.md` : mise à jour de `docs/projets/tidemark.md` cochée (fichier de l'espace de travail, hors dépôt, mis à jour le même jour).

### Décisions

- Le merge de la PR #44 par Yanis vaut confirmation de l'option F, comme un merge vaut validation d'une spec dans ce dépôt (agent, par délégation de Yanis du 2026-10-16).

### Corrections et limites

- Test humain des six fonctionnalités et des PR #43 et #44 toujours à faire par Yanis, ainsi que le GIF.
- Le commit 462ceb1 de l'historique de `main` contient un nom exclu (seul commit touché, contrôle `scripts/verifier-noms-exclus.sh --all` du 2026-10-16) : réécriture de l'historique à décider par Yanis avant le passage en public.

### Prochaine étape

- Yanis merge cette PR ; puis réécriture de l'historique (force-push par Yanis), test humain, GIF, passage en public.
