# Journal : correction de l'interruption de l'étiquetage (spec 004)

Branche `fix/etiquetage-interruption`, partie de `main` après le merge de la PR #23. Corrige les points des revues IA de la PR #23. La PR #24 (`test/mutations-etiquetage`, encore ouverte) touche `test/analysis/analysis_queue_test.dart`, `test/storage/analysis_storage_test.dart` et `test/support/analysis_harness.dart` : cette branche n'y touche pas, et sera rebasée après son merge.

## 2026-10-15 15:16

### Fait

- Spec 004 complétée avant toute correction, parce que le bug révèle des cas non prévus :
  - règle « Arrière-plan » : la file observe le cycle de vie de l'app, interrompt l'analyse sans écrire de résultat, libère le modèle, et reprend au retour au premier plan ;
  - règle « Entrée en cours » : l'entrée est « en cours d'analyse » dès le chargement du modèle et jusqu'à l'écriture du résultat ;
  - CA32 (arrière-plan pendant une analyse), CA33 (arrière-plan pendant le chargement), CA34 (libération qui échoue, arrêt pendant le chargement), CA35 (`LlamaMoodAnalyzer.cancel()` attend la génération, 5 s au plus, puis libère le moteur) ;
  - cas limite « App mise en arrière-plan » et « Données » mis à jour ; décision n° 10.
- Architecture technique : contrats `LocalEngine` et cycle de vie de l'app ajoutés au tableau des contrats.

### Décisions

- Yanis a donné son accord le 2026-10-15 pour enchaîner sans pause après les tests rouges (« fonce, continue le dev ») ; la spec complétée reste à valider par Yanis avec la PR.
- Le cycle de vie est injecté dans `AnalysisQueue` comme un `Stream<AppLifecycleState>` fourni par `startApp`, plutôt que `WidgetsBinding` en dur : testable avec un flux factice (agent, sur la demande de la revue).
- `inactive` n'interrompt rien : sur iOS, il couvre le centre de contrôle ou un appel entrant, où le GPU reste permis ; `hidden`, `paused` et `detached` interrompent (agent).
- Tout résultat d'une analyse pendant laquelle l'app est passée en arrière-plan est ignoré, même `Tagged` : on ne peut pas distinguer un `Untagged` dû au GPU refusé d'un vrai `Untagged` ; l'entrée sera analysée de nouveau au retour (agent).
- Délai borné de `cancel()` dans `LlamaMoodAnalyzer` : 5 s, puis libération du moteur (agent).

### Corrections et limites

- Les CA32 à CA35 sont numérotés à la suite du CA31, comme lui hors ordre dans la liste.

### Prochaine étape

Couture `LocalEngine` et paramètre du cycle de vie (squelette, sans comportement), puis tests de non-régression rouges.
