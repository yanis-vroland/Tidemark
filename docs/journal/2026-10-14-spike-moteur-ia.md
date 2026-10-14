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

## 2026-10-14 11:18

### Fait

- Recherches terminées et vérifiées sur pub.dev et Hugging Face : `flutter_gemma` est abandonné (renommé `flutter_edge_ai` 2.3.2) ; `llama_cpp_dart` publié plante dès qu'une grammaire contraint la sortie, remplacé par `llamadart` 0.12.0, qui accepte un schéma JSON.
- Deux moteurs branchés dans l'app de mesure : `llamadart` (GGUF, sortie libre ou contrainte par schéma) et `flutter_edge_ai` avec LiteRT-LM (`.litertlm`, sortie libre). L'app lance la mesure au démarrage et écrit le résultat dans les logs.
- Modèles téléchargés à une révision épinglée, sans compte : Qwen2.5-1.5B-Instruct Q4_K_M (1,1 Go, Apache-2.0) et Qwen3-0.6B LiteRT-LM `_dynamic` (345 Mo, Apache-2.0).
- Émulateur Android dédié `Tidemark_Spike` (Pixel 7, API 35, arm64, 6 Go de RAM) créé à côté de celui de Yanis, qui n'est pas modifié.
- iOS 16.4 et Android API 30 au minimum, exigés par les paquets.

### Décisions

- Moteurs comparés : `llamadart` et `flutter_edge_ai`, à la place de `llama_cpp_dart` et `flutter_gemma` prévus par le plan (agent, sur la foi des recherches) : à valider par Yanis dans l'ADR-001.
- Modèles Apache-2.0 seulement : les licences Gemma et Llama ajoutent des politiques d'usage, sensibles sur un sujet de santé mentale (agent).
- `llamadart` 0.12.0 est sorti le jour même ; version épinglée exactement (agent).

### Corrections et limites

- **Première mesure Android interrompue : disque du Mac plein** (`No space left on device` pendant la compilation Gradle, 231 Mo libres sur 460 Go). Le spike a ajouté environ 7 Go (émulateur 3,6 Go dont les modèles copiés, modèles 1,4 Go, mise à jour de Flutter et paquets). Émulateur et simulateur arrêtés par l'agent ; aucune mesure obtenue.
- Les deux moteurs ne tournent pas le même modèle (1,5 milliard de paramètres contre 0,6) : la comparaison mêle moteur et modèle. Qwen2.5-1.5B existe aussi en `.litertlm` (1,6 Go) si l'espace disque le permet.

### Prochaine étape

Yanis libère de l'espace disque (au moins 15 Go conseillés). Ensuite : relancer la mesure `llamadart` sur l'émulateur, puis `flutter_edge_ai`, puis le simulateur iOS.

## 2026-10-14 12:14

### Fait

- Espace disque libéré par Yanis (159 Go libres) : mesures relancées.
- Quatre configurations mesurées sur 20 entrées, sur l'émulateur Android et le simulateur iOS : `llamadart` + Qwen2.5-1.5B (sortie libre ou contrainte par schéma), `flutter_edge_ai` + Qwen3-0.6B (sortie libre ou contrainte par appel de fonction). Tableau et extraits de logs dans `spike/mesures/`.
- Résultats exploitables : avec contrainte, 20/20 JSON valides pour `llamadart` (rappel 0,46 à 0,47) ; `flutter_edge_ai` + Qwen3-0.6B, 19 à 20/20 valides mais rappel 0,14 à 0,17 (il répond presque toujours « travail » ou « famille ») ; sans contrainte, Qwen3-0.6B invente des étiquettes hors liste (1 à 2/20 valides).

### Décisions

- Mode « appel de fonction » ajouté à `flutter_edge_ai`, pour comparer les deux moteurs avec une sortie contrainte des deux côtés (agent).
- Schéma JSON des étiquettes commun aux deux moteurs (agent).

### Corrections et limites

- Premier passage invalide : les séries Android et iOS écrivaient dans les mêmes fichiers de log, leurs résultats se sont mélangés. Erreur de l'agent, corrigée par un dossier de sortie par appareil, puis tout a été relancé.
- Les temps de cette série ne sont pas comparables : Android et iOS ont tourné en même temps sur le même Mac (`llamadart` avec schéma : 2,5 s de médiane seul, 9,2 s en parallèle).
- L'accélération GPU de `llamadart` bloque le chargement sur l'émulateur Android, sans erreur : mesures en processeur seul. À vérifier sur l'iPhone.
- Les deux moteurs ne tournent pas le même modèle : le faible rappel de `flutter_edge_ai` juge Qwen3-0.6B, pas le moteur. Comparaison à modèle égal : Qwen2.5-1.5B en `.litertlm` (1,6 Go), téléchargement soumis à l'accord de Yanis.
- `llamadart` et `flutter_edge_ai_litertlm` embarquent la même bibliothèque LiteRT-LM : `llamadart` laisse la sienne de côté quand les deux paquets sont présents (avertissement du build).

### Prochaine étape

Accord de Yanis sur le téléchargement de Qwen2.5-1.5B en `.litertlm`, puis comparaison à modèle égal, une plateforme à la fois. Ensuite : mesures sur l'iPhone 15 Pro (temps, mémoire, GPU), puis ADR-001.
