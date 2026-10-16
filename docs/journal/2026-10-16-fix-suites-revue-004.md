# Journal : fix/suites-revue-004

Suites des revues IA de la spec 004 (issues #29 à #33), défaut de la file d'analyse après un échec d'écriture, et « 1er » du mois (spec 006).

## 2026-10-16 09:10

### Fait

- Lecture des issues #29 à #33 et du code concerné (`AnalysisQueue`, `EntryTagsSection`, `EntryDetailScreen`, garde-fou réseau, test CA29).
- Reproduction de #33 : sur la base drift, un second `stop()` lancé dans le temps simulé d'un test de widget ne rend jamais la main, alors que le premier, en temps réel, s'est terminé (il refait le désabonnement des flux de la base).
- Spec 004 complétée : règle « Écriture du résultat impossible » et CA36 (défaut constaté : après un échec de `saveAnalysis`, la file reprenait sans fin la plus récente et n'atteignait plus les plus anciennes) ; CA28 précisé (fin de l'analyse annoncée) ; CA34 complété (second `stop()`).
- Spec 006 complétée : CA37, « 1er » du mois partout où une date s'affiche ; renvoi depuis la spec 001 (CA3).

### Décisions

- Yanis a donné son accord le 2026-10-16 pour enchaîner sans pause après les tests rouges (« fonce, continue le dev ») et a délégué les décisions à l'agent (« fonce, sois autonome sur les décisions et finis l'app »).
- Règle d'échec d'écriture, décidée par délégation (agent principal, par délégation de Yanis du 2026-10-16) : l'entrée reste « en attente », la file s'arrête jusqu'au prochain événement et ne relance jamais la même entrée en boucle. Précisions de l'agent, par délégation de Yanis du 2026-10-16 : une « série d'événements » est une suite de relances dues aux événements reçus pendant qu'elle tourne ; aux séries suivantes, l'entrée en échec passe après les autres, pour que les plus anciennes soient atteintes ; ce rang vit en mémoire, jamais dans la base.
- Annonce de fin d'analyse (CA28) : annonce explicite sur iOS, région vive sur Android, jamais les deux, pour qu'elle ne soit pas lue deux fois ; rien à l'ouverture d'un détail déjà étiqueté (agent, par délégation de Yanis du 2026-10-16).
- « 1er » du mois : usage français, appliqué au bilan, à la liste et au détail (agent principal, par délégation de Yanis du 2026-10-16). La question ouverte du cahier des charges n'est pas modifiée ici : un autre agent met à jour le cahier en parallèle (branche `docs/decisions-2026-10-16`) ; le point est signalé dans la PR.

### Corrections et limites

- `llama_mood_analyzer.dart`, `model_downloader.dart`, `main.dart` et `pubspec.yaml` ne sont pas touchés : un autre agent y travaille (branche `feat/integrite-moteur-modele`). Le garde-fou de #31 lit `llama_mood_analyzer.dart` sans le modifier.

### Prochaine étape

- Tests rouges (subagent `test-writer`), puis implémentation.
