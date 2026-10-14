# Mesures du 2026-10-14, à modèle égal : émulateur Android et simulateur iOS

Même modèle des deux côtés : Qwen2.5-1.5B-Instruct, en GGUF Q4_K_M pour `llamadart` et en `.litertlm` q8 pour `flutter_edge_ai` (seule quantification publiée ; elle avantage un peu `flutter_edge_ai` en qualité). Émulateur Android `Tidemark_Spike` (release) puis simulateur iPhone 17 Pro iOS 26.5 (debug), **mesurés l'un après l'autre**. Processeur seul pour `llamadart`. 20 entrées fictives.

Les temps viennent du processeur du Mac, pas d'un téléphone. La mémoire est la RSS du processus : elle ne compte peut-être pas la mémoire projetée ou allouée hors du tas par LiteRT-LM.

| Appareil | Config | Modèle | Chargement | Mémoire après chargement | Médiane | P90 | JSON valides | Rappel |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| android | edge-q25-libre | Qwen2.5-1.5B-Instruct_ (1524 Mo) | 1.4 s | 581 Mo | 2.76 s | 3.42 s | 18/20 | 0.66 |
| android | edge-q25-tools | Qwen2.5-1.5B-Instruct_ (1524 Mo) | 10.0 s | 803 Mo | 4.66 s | 6.23 s | 19/20 | 0.49 |
| android | llamadart-libre | qwen2.5-1.5b-instruct- (1066 Mo) | 3.1 s | 2160 Mo | 0.75 s | 1.09 s | 18/20 | 0.53 |
| android | llamadart-schema | qwen2.5-1.5b-instruct- (1066 Mo) | 10.4 s | 2163 Mo | 0.85 s | 0.99 s | 20/20 | 0.49 |
| ios | edge-q25-libre | Qwen2.5-1.5B-Instruct_ (1524 Mo) | 1.8 s | 519 Mo | 1.84 s | 2.05 s | 18/20 | 0.64 |
| ios | edge-q25-tools | Qwen2.5-1.5B-Instruct_ (1524 Mo) | 11.0 s | 1161 Mo | 2.00 s | 2.20 s | 19/20 | 0.49 |
| ios | llamadart-libre | qwen2.5-1.5b-instruct- (1066 Mo) | 1.9 s | 2140 Mo | 0.65 s | 0.73 s | 17/20 | 0.5 |
| ios | llamadart-schema | qwen2.5-1.5b-instruct- (1066 Mo) | 2.0 s | 1800 Mo | 0.77 s | 0.89 s | 20/20 | 0.52 |
