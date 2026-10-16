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

## 2026-10-16 09:30

### Fait

- Tests écrits par le subagent `test-writer`, avant toute implémentation ; 29 rouges pour la bonne raison, sur 449 dans les suites touchées :
  - CA34 (#33), second `stop()` : faux dépôt dont le second `cancel()` de l'abonnement ne se termine jamais (comme drift dans le temps simulé) ; rouges : `TimeoutException` sur le second appel et sur deux appels simultanés, `cancel()` de l'abonnement appelé 2 fois au lieu de 1 ;
  - CA36 : `saveAnalysis` qui lève pour la plus récente ; rouges : texte d'oct12 reçu deux fois dans la même série, les plus anciennes jamais atteintes ;
  - CA28 (#29) : fin d'analyse sur iOS (aucune annonce « Analyse terminée ») et Android (pas de région vive) rouges ; ouverture d'un détail déjà étiqueté sans annonce : verts ;
  - CA29 (#30) : test existant modifié (vérification relancée après le défilement), vert ;
  - garde-fou llamadart (#31) : `llamadartViolations` en bouchon qui rend une liste vide ; les 7 refus sont rouges, les admissions vertes ;
  - CA37 (spec 006) : « 1 » au lieu de « 1er » dans la carte, l'écran du bilan, les intertitres et le détail ; les autres jours, verts ;
  - #32 : `watchEntries()` appelé 2 fois au lieu de 1 après des reconstructions du détail.

### Décisions

- Implémentation enchaînée sans pause après les tests rouges, avec l'accord de Yanis du 2026-10-16.
- Coordination (agent principal) : la PR #35 ajoute RM57 (échec d'écriture), RM60 (#29) et RM61 (« 1er ») au cahier des charges ; les specs y renverront, le cahier n'est pas modifié ici.

### Corrections et limites

- Dans le test #32, l'assertion sur `watch()` du modèle n'a pas encore été exercée : elle suit celle de `watchEntries()`, rouge.

### Prochaine étape

- Implémenter : `stop()` idempotent, règle d'échec d'écriture, annonce de fin d'analyse, garde-fou llamadart (avec mutations), « 1er », flux créés une fois.

## 2026-10-16 09:35

### Fait

- `AnalysisQueue.stop()` idempotent : le premier appel garde son futur, les suivants le rendent sans refaire l'arrêt (#33, CA34).
- Échec d'écriture (CA36, RM57) : la file s'arrête ; les événements reçus pendant le passage en échec ne la relancent pas ; l'entrée en échec passe après les autres au passage suivant (rang en mémoire, effacé par une écriture réussie ou quand l'entrée n'est plus « en attente »).
- Fin d'analyse annoncée (#29, CA28, RM60) : `EntryTagsSection` devient un `StatefulWidget` qui repère le passage d'« en attente » à « étiquetée » ou « sans étiquette » ; `SemanticsService.sendAnnouncement` sur iOS, région vive (`Semantics(container, liveRegion)`) sur le nouveau statut ailleurs.
- Flux créés une fois (#32) : `EntryDetailScreen` devient un `StatefulWidget` qui garde `watchEntries()` ; l'état du modèle passe dans `_ModelStatus`, qui garde `watch()`.
- « 1er » du mois (CA37, RM61) : `dayOfMonth` dans `lib/entries/day_grouping.dart`, repris par `lib/review/local_week.dart`.
- Garde-fou llamadart (#31) : `llamadartViolations` implémentée (source autre que `ModelSource.path`, `loadModel*`, `LlamaModel` ou `projector` sans `ModelSource.path` direct) ; un échantillon « projecteur passé par une variable » ajouté après coup (vert dès son ajout, la règle étant écrite en même temps). Architecture technique complétée (section « Sécurité »).
- Specs 004 et 006 : renvois à RM57, RM60 et RM61 (PR #35) ; règle d'échec d'écriture reformulée comme implémentée.
- `flutter test` : 1 701 verts, 0 rouge, aussi avec `TZ=UTC` ; `dart analyze --fatal-infos` et `dart format` propres.
- Contrôle par mutation, chaque protection désactivée une fois : 18 mutations, 18 détectées (`stop()` non mémorisé, relance après échec d'écriture, entrée en échec non reléguée, échec non mémorisé, annonce iOS absente, région vive Android absente, région vive aussi sur iOS, annonce aussi sur Android, annonce à l'ouverture, journal et modèle réabonnés à chaque construction, pas de « 1er », et les six règles du garde-fou llamadart : source autre que `path`, `loadModel*`, `LlamaModel` sans `path`, `projector` sans `path`, import non exigé, commentaires non retirés).

### Décisions

- Après un échec d'écriture, la file ignore tous les événements reçus pendant ce passage, y compris un enregistrement : la nouvelle entrée attend le prochain événement. C'est la règle « s'arrête jusqu'au prochain événement » ; distinguer les événements de la file de ceux de la personne compliquerait la file pour un cas rare (agent, par délégation de Yanis du 2026-10-16).
- Règle « `ModelSource(` » retirée du garde-fou : le constructeur de `llamadart` est privé, et `ModelSource._` est déjà refusé par la règle des sources autres que `path` (agent, par délégation de Yanis du 2026-10-16).
- Région vive sans libellé propre sur Android : les lignes « Émotions : … » et « Thèmes : … » restent lues séparément (CA28) ; à confirmer au test humain avec TalkBack (agent, par délégation de Yanis du 2026-10-16).

### Corrections et limites

- Test humain : à faire par Yanis (VoiceOver et TalkBack pour CA28, dates du 1er du mois).

### Prochaine étape

- Revues `reviewer` et `security-reviewer`, puis PR en brouillon.

## 2026-10-16 09:50

### Fait

- Revue `security-reviewer` : aucun point bloquant ; un « à corriger » (garde-fou llamadart limité aux fichiers qui écrivent `import 'package:llamadart/`), quatre suggestions (contournements par alias, référence sans appel, `LlamaModel.new`, `setLoraSource`, `loadMultimodalProjectorSource` ; `//` ou `/*` dans une chaîne ; annonce iOS quand le détail est couvert ; `stop()` qui s'arrête à la première étape en échec).
- Tests rouges écrits par l'agent (pas de `test-writer` pour ces suites de revue, tests courts tirés du rapport) : 11 échantillons du garde-fou (réexport, `part`, import conditionnel, alias, référence sans appel, `LlamaModel.new`, `setLoraSource`, `loadMultimodalProjectorSource`, `//` et `/*` dans une chaîne), rouges ; `stop()` avec un désabonnement qui lève : rouge (modèle jamais libéré) ; annonce iOS avec un écran par-dessus le détail : rouge (annonce envoyée).

### Décisions

- Toutes les suggestions de la revue de sécurité sont suivies, sauf la liste fermée des fichiers qui importent llamadart : un autre agent réorganise le chargeur (`feat/integrite-moteur-modele`) ; le garde-fou analyse plutôt tout fichier qui mentionne `package:llamadart` et refuse son réexport (agent, par délégation de Yanis du 2026-10-16).

### Corrections et limites

- Aucune.

### Prochaine étape

- Corriger, relancer les mutations, puis traiter la revue `reviewer`.
