# Mesures du 2026-10-14 : émulateur Android et simulateur iOS

Émulateur Android `Tidemark_Spike` (Pixel 7, API 35, arm64, 6 Go, release) et simulateur iPhone 17 Pro (iOS 26.5, debug), sur le Mac de Yanis. Processeur seul pour `llamadart` (GPU_LAYERS=0). 20 entrées fictives, `assets/entries.json`.

**Les temps ne sont pas comparables** : les deux séries ont tourné en même temps sur le même Mac. Seuls la validité du JSON et le rappel sont exploitables. Les temps de référence viendront de l'iPhone 15 Pro.

| Appareil | Config | Modèle | Chargement | Mémoire après chargement | Médiane | P90 | JSON valides | Rappel |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| android | edge-libre | Qwen3-0.6B_dynamic_wi4 (329 Mo) | 5.9 s | 635 Mo | 4.98 s | 6.89 s | 1/20 | 0.67 |
| android | edge-tools | Qwen3-0.6B_dynamic_wi4 (329 Mo) | 14.0 s | 705 Mo | 10.12 s | 11.05 s | 19/20 | 0.17 |
| android | llamadart-libre | qwen2.5-1.5b-instruct- (1066 Mo) | 4.4 s | 2168 Mo | 3.35 s | 6.68 s | 17/20 | 0.5 |
| android | llamadart-schema | qwen2.5-1.5b-instruct- (1066 Mo) | 24.7 s | 2172 Mo | 9.24 s | 12.65 s | 20/20 | 0.46 |
| ios | edge-libre | Qwen3-0.6B_dynamic_wi4 (329 Mo) | 2.3 s | 642 Mo | 0.98 s | 1.12 s | 2/20 | 0.58 |
| ios | edge-tools | Qwen3-0.6B_dynamic_wi4 (329 Mo) | 2.0 s | 628 Mo | 1.38 s | 1.59 s | 20/20 | 0.14 |
| ios | llamadart-libre | qwen2.5-1.5b-instruct- (1066 Mo) | 3.4 s | 1531 Mo | 1.41 s | 2.05 s | 19/20 | 0.51 |
| ios | llamadart-schema | qwen2.5-1.5b-instruct- (1066 Mo) | 2.0 s | 1697 Mo | 0.95 s | 1.20 s | 20/20 | 0.47 |
