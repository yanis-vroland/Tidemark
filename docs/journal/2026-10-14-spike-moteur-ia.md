# Journal : spike du moteur d'IA local

Branche `spike/moteur-ia` (lot B du plan). Le code du spike, dans `spike/app/`, n'est pas mergé : seuls l'ADR-001 et ses mesures le seront, par une autre PR.

## 2026-10-14 11:04

### Fait

- Flutter mis à jour de 3.35.3 à 3.47.7 (accord de Yanis) ; licences Android acceptées par Yanis ; `adb` en double retiré par Yanis.
- App de mesure créée dans `spike/app/` (iOS + Android) : interface `SpikeEngine`, banc de mesure (temps de chargement, temps par entrée, mémoire, taux de JSON valide, rappel des étiquettes attendues), validation de la sortie avec ses tests.
- 20 entrées fictives en français, avec un vocabulaire provisoire de 12 émotions et 12 thèmes et les étiquettes attendues pour chaque entrée.
- Deux recherches lancées en parallèle sur `flutter_gemma` et `llama_cpp_dart` : versions, formats, licences, téléchargement sans compte.

### Décisions

- Même prompt pour les deux moteurs : seul le moteur change d'une mesure à l'autre (agent).
- En plus du taux de JSON valide prévu par le plan, mesure du rappel des étiquettes attendues, pour juger la qualité en français (RM22) (agent).
- Vocabulaire provisoire, propre au spike : la liste définitive viendra de la spec du lot G (RM19) (agent).

### Corrections et limites

- Le rappel est calculé sur des étiquettes attendues choisies par l'agent : c'est un indicateur de comparaison entre moteurs, pas une mesure absolue de qualité.

### Prochaine étape

Brancher les deux moteurs selon les résultats des recherches, puis les faire tourner sur le simulateur iOS et l'émulateur Android.
