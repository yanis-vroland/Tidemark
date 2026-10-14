# ADR-001 : Moteur d'IA local

Statut : accepté (Yanis, 2026-10-14)
Date : 2026-10-14

Contexte : Tidemark étiquette chaque entrée (émotions, thèmes) avec un modèle de langage qui tourne sur le téléphone, sans aucun appel réseau autre que le téléchargement du modèle (RM1, RM11). L'app cible iOS et Android (décision de Yanis du 2026-10-13), en français seulement (RM22). Les étiquettes viennent d'une liste fermée (RM19) ; une sortie non conforme laisse l'entrée sans étiquette (RM9). Il faut choisir le paquet Flutter qui exécute le modèle, et le modèle.

Ce choix repose sur un spike (branche `spike/moteur-ia`, non mergée) : une app de mesure fait étiqueter 20 entrées fictives en français par chaque configuration, avec le même prompt, et mesure le chargement, le temps par entrée, la mémoire, le taux de JSON valide et le rappel des étiquettes attendues. Les mesures brutes, les entrées fictives et les étiquettes attendues sont versionnées dans [`001-mesures/`](001-mesures/). Paramètres communs : température 0,2, sortie limitée à 128 jetons, sans graine fixe ; `llamadart` 0.12.0, `flutter_edge_ai` 2.3.2 et `flutter_edge_ai_litertlm` 1.13.2 pour toutes les séries.

## 1. Paquet

Options envisagées :
- **`flutter_gemma`** : prévu par le plan, mais abandonné sur pub.dev depuis le 2026-10-05, renommé `flutter_edge_ai`. Écarté.
- **`llama_cpp_dart`** : prévu par le plan. Sa version publiée (0.2.2) est ancienne ; la réécriture (0.9.0-dev) fait planter l'app dès qu'une grammaire contraint la sortie, correction disponible seulement sur GitHub (issue #112). Écarté.
- **`fllama`** : licence GPL v2, incompatible avec un dépôt MIT. Écarté.
- **Foundation Models d'Apple** : iOS seulement. Écarté par la cible iOS + Android.
- **`flutter_edge_ai`** 2.3.2 + `flutter_edge_ai_litertlm` 1.13.2 (licence MIT ; moteur natif LiteRT-LM de Google, Apache-2.0 ; fichiers `.litertlm`) : sortie libre, ou contrainte par un appel de fonction. Mesuré.
- **`llamadart`** 0.12.0 (licence MIT ; moteur natif llama.cpp, MIT ; fichiers GGUF, lit aussi les `.litertlm`) : sortie contrainte par un schéma JSON. Mesuré. Dans son code Dart, seul le gestionnaire de téléchargement de modèles ouvre une connexion, et seulement quand le modèle est donné par une URL ; Tidemark lui donne un chemin local.

## 2. Modèle

Seuls des modèles sous licence Apache-2.0, téléchargeables sans compte ni jeton, ont été retenus : les licences Gemma et Llama ajoutent des politiques d'usage, sensibles sur un sujet de santé mentale, et un jeton dans l'app est exclu (RM1).

- **Qwen3-0.6B** (`.litertlm`, 329 Mo) : trop petit. Sans contrainte, il invente des étiquettes hors liste (1 à 2 réponses valides sur 20) ; contraint, il répond presque toujours « travail » ou « famille » (rappel 0,14 à 0,17).
- **Qwen2.5-1.5B-Instruct** : GGUF Q4_K_M (1 066 Mo) pour `llamadart`, `.litertlm` q8 (1 524 Mo, seule quantification publiée) pour `flutter_edge_ai`. Retenu pour la comparaison.

## 3. Mesures

### Émulateur Android et simulateur iOS (2026-10-14)

Même modèle (Qwen2.5-1.5B), configurations mesurées l'une après l'autre. Émulateur Android Pixel 7 API 35 arm64 (6 Go, release) et simulateur iPhone 17 Pro iOS 26.5 (debug), sur un Mac Apple Silicon. Processeur seul pour `llamadart` : son accélération GPU bloque le chargement sur l'émulateur, sans erreur.

| Configuration | JSON valides (iOS / Android) | Rappel | Médiane par entrée | Chargement | RSS après chargement |
| --- | --- | --- | --- | --- | --- |
| `llamadart` + schéma JSON | 20/20, 20/20 | 0,52 / 0,49 | 0,8 s / 0,9 s | 2 s / 10 s | 1,8 / 2,2 Go |
| `llamadart` sans contrainte | 17/20, 18/20 | 0,50 / 0,53 | 0,7 s / 0,8 s | 2 s / 3 s | 2,1 / 2,2 Go |
| `flutter_edge_ai` + appel de fonction | 19/20, 19/20 | 0,49 / 0,49 | 2,0 s / 4,7 s | 11 s / 10 s | 1,2 / 0,8 Go |
| `flutter_edge_ai` sans contrainte | 18/20, 18/20 | 0,64 / 0,66 | 1,8 s / 2,8 s | 2 s / 1 s | 0,5 / 0,6 Go |

Ces temps viennent du processeur du Mac : ils comparent les configurations entre elles, pas ce que vivra un utilisateur. La RSS ne compte peut-être pas toute la mémoire de LiteRT-LM. Le rappel est mesuré sur des étiquettes attendues choisies pour le spike : c'est un indicateur de comparaison, pas une qualité absolue.

### Taille de l'échantillon

20 entrées par série. Le rappel d'une même configuration varie d'une série à l'autre de 0,47 à 0,52 : un écart de cet ordre n'est pas significatif. L'écart entre 0,51 (`llamadart` + schéma) et 0,60 à 0,66 (`flutter_edge_ai` sans contrainte) est plus large que ce bruit, sans être démontré sur un échantillon aussi petit.

### iPhone 15 Pro (2026-10-14)

iPhone 15 Pro (8 Go, iOS 26.6.2), app en mode profile, signée avec un compte Apple gratuit, sans l'entitlement `increased-memory-limit`. Configurations lancées l'une après l'autre. Même modèle, Qwen2.5-1.5B.

| Configuration | JSON valides | Rappel | Médiane par entrée | P90 | Chargement | RSS après chargement |
| --- | --- | --- | --- | --- | --- | --- |
| `llamadart` + schéma, GPU (Metal) | 20/20 | 0,51 | 0,83 s | 0,97 s | 12,2 s (0,3 s relancé) | 1,3 Go |
| `llamadart` + schéma, processeur seul | 20/20 | 0,47 | 1,78 s | 1,89 s | 3,5 s | 1,3 Go |
| `llamadart` sans contrainte, GPU | 17/20 | 0,48 | 0,80 s | 0,92 s | 0,2 s | 1,4 Go |
| `flutter_edge_ai` + appel de fonction | 18/20 | 0,53 | 3,35 s | 3,66 s | 20,3 s | 1,9 Go |
| `flutter_edge_ai` sans contrainte | 20/20 | 0,60 | 2,12 s | 2,45 s | 2,2 s | 0,4 Go |

- **Mémoire** : aucun arrêt par le système jusqu'à 1,9 Go de RSS. L'entitlement `increased-memory-limit`, dont la disponibilité pour un compte gratuit est incertaine, n'est pas nécessaire avec ce modèle.
- **GPU** : Metal divise par deux le temps de `llamadart` sur iPhone. Sur l'émulateur Android, il bloque le chargement : Android reste en processeur seul tant qu'il n'est pas vérifié sur un appareil réel.
- **Chargement** : le premier chargement (12 s) lit 1 Go depuis le stockage ; relancé, le modèle est déjà dans le cache du système. L'app doit charger le modèle en arrière-plan, pas au moment de la saisie.
- La RSS de `flutter_edge_ai` sans contrainte (0,4 Go) est étonnamment basse : LiteRT-LM projette sans doute le modèle en mémoire hors de la RSS. Non vérifié avec Instruments.

### Mode avion (2026-10-14)

`llamadart` + schéma + GPU, relancé sur l'iPhone 15 Pro en mode avion (Wi-Fi coupé) : 20/20 réponses valides, rappel 0,49, médiane 0,84 s ([mesure](001-mesures/iphone-mode-avion/llamadart-schema.json)). L'analyse fonctionne donc sans réseau. Le mode avion ne prouve pas qu'aucune connexion n'est tentée en silence : c'est la lecture du code de `llamadart` (section 1) qui couvre ce point.

## Décision

Décision de Yanis (2026-10-14), sur proposition de l'agent : **`llamadart`, avec Qwen2.5-1.5B-Instruct Q4_K_M et une sortie contrainte par schéma JSON**, l'accélération GPU activée sur iOS.

- C'est la seule configuration sans aucune réponse invalide dans les tableaux ci-dessus (80 sur 80 : simulateur, émulateur, iPhone avec et sans GPU) : RM9 devient un filet de sécurité, pas un cas courant.
- C'est la plus rapide à modèle égal : 0,8 s par entrée sur iPhone, 2,5 fois moins que `flutter_edge_ai` sans contrainte.
- Le schéma JSON porte la liste fermée des étiquettes (RM19) : le modèle ne peut pas en inventer.
- Un seul paquet, qui lit aussi le format `.litertlm` si un meilleur modèle n'existe que sous ce format.

Conséquences :
- **Qualité limitée** : environ la moitié des étiquettes attendues retrouvées. Le README devra le dire (lot J du plan) ; l'étiquetage reste une aide, jamais un diagnostic (RM4).
- **Contre-argument** : `flutter_edge_ai` sans contrainte retrouve plus d'étiquettes (0,60 sur iPhone, 0,64 à 0,66 sur simulateur et émulateur) et occupe moins de mémoire visible. Mais rien ne garantit sa sortie : 2 réponses invalides sur 20 sur simulateur et émulateur, 0 sur iPhone. Son modèle est aussi moins compressé (q8 contre Q4_K_M) : un GGUF q8 avec `llamadart` permettrait de savoir si l'écart de rappel vient du moteur ou de la quantification.
- **Paquet jeune** : `llamadart` 0.12.0 est sorti le 2026-10-14 et compte plus de 130 issues ouvertes. Version épinglée exactement ; l'interface `MoodAnalyzer` permet d'en changer sans toucher au reste de l'app.
- **Plateformes minimales** : iOS 16.4, exigé par `llamadart`. Android API 30 a été exigé par `flutter_edge_ai_litertlm` pendant le spike ; le minimum Android de `llamadart` seul est à vérifier à la création du projet (lot D), puis à reporter dans l'architecture technique.
- **Chargement en arrière-plan** : jusqu'à 12 s au premier chargement sur iPhone.
- **Téléchargement** : environ 1,1 Go au premier usage (RM18), URL épinglée sur une révision Hugging Face, empreinte SHA-256 vérifiée (RM11).
- **Android** : performances mesurées seulement sur émulateur (aucun appareil Android physique, décision du 2026-10-14). Le README devra le dire (lot J).
- **Aucun appel réseau pendant l'analyse** : vérifié en mode avion sur iPhone ; à revérifier sur l'app réelle, avec son téléchargement de modèle, au lot G.
