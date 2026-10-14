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

## 2026-10-14 13:02

### Fait

- Qwen2.5-1.5B-Instruct en `.litertlm` q8 téléchargé (1,6 Go, Apache-2.0, révision épinglée) avec l'accord de Yanis, qui demande de supprimer à la fin du spike tout ce qui n'est pas utile à garder.
- Comparaison à modèle égal, iOS puis Android, mesurés l'un après l'autre : `spike/mesures/2026-10-14-modele-egal.md`.
- Résultats (simulateur iOS / émulateur Android) :
  - `llamadart` + schéma : 20/20 valides, rappel 0,52 / 0,49, médiane 0,8 s / 0,9 s, environ 2 Go de RSS.
  - `flutter_edge_ai` + appel de fonction : 19/20, rappel 0,49, médiane 2,0 s / 4,7 s, chargement de 10 à 11 s.
  - `flutter_edge_ai` sans contrainte : 18/20, meilleur rappel (0,64 / 0,66), médiane 1,8 s / 2,8 s.

### Décisions

- Recommandation provisoire de l'agent : `llamadart` avec sortie contrainte par schéma, pour sa sortie toujours valide (RM9 jamais déclenchée sur 40 essais) et sa rapidité. À confirmer sur l'iPhone 15 Pro avant l'ADR-001 ; décision finale à Yanis.

### Corrections et limites

- Le `.litertlm` n'existe qu'en q8, le GGUF est en Q4_K_M : la qualité de `flutter_edge_ai` est un peu avantagée.
- La RSS de `flutter_edge_ai` (0,5 à 1,2 Go) ne compte peut-être pas toute la mémoire de LiteRT-LM : comparaison de mémoire à confirmer sur l'iPhone (Instruments).
- Rappel autour de 0,5 quel que soit le moteur : limite du modèle de 1,5 milliard de paramètres, à écrire dans l'ADR et le README.

### Prochaine étape

Mesures sur l'iPhone 15 Pro (temps réels, mémoire, GPU), une configuration à la fois. Puis ADR-001, puis nettoyage : émulateur `Tidemark_Spike`, modèles, copie du projet pour iOS, app du spike sur le simulateur.

## 2026-10-14 14:35

### Fait

- iPhone 15 Pro appairé ; Apple ID ajouté dans Xcode par Yanis ; app signée avec son équipe personnelle gratuite (`AZ7L3PPYH9`, dans la copie locale seulement).
- Mesures sur iPhone, une configuration à la fois : `spike/mesures/2026-10-14-iphone-15-pro.md`. `llamadart` + schéma + Metal : 20/20 valides, rappel 0,50 à 0,51, médiane 0,83 à 0,91 s, 1,3 Go de RSS ; 12 s de chargement au premier lancement, 0,3 s au suivant. Processeur seul : médiane 1,78 s. `flutter_edge_ai` : sans contrainte 20/20, rappel 0,60, médiane 2,1 s ; avec appel de fonction 18/20, rappel 0,53, médiane 3,4 s, 20 s de chargement et 1,9 Go.
- Aucun arrêt pour mémoire sans l'entitlement `increased-memory-limit`, jusqu'à 1,9 Go de RSS : l'entitlement n'est pas nécessaire avec ce modèle, et la question du compte gratuit ne se pose pas.

### Décisions

- Résultats récupérés par un fichier `result.json` écrit par l'app et copié par `devicectl`, au lieu des logs de `flutter run` (agent).

### Corrections et limites

- `flutter run` ne remonte pas les logs de l'iPhone : son outil `iproxy` est compilé pour Intel et exige Rosetta, absent du Mac. Contourné sans installer Rosetta.
- `flutter create` avait inscrit dans le projet une autre équipe (`2ADQ59V3K4`, d'un certificat présent sur le Mac), poussée sur cette branche ; la signature a exigé l'équipe du compte Xcode.
- Le premier chargement de 12 s comprend sans doute la lecture du fichier depuis le stockage ; au second, le système l'a en cache.

### Prochaine étape

ADR-001 complété avec les mesures iPhone, PR au statut « proposé ». Puis nettoyage de fin de spike, avec l'accord déjà donné par Yanis.
