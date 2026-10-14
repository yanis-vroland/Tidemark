# Journal : socle Flutter (lot D)

Branche `chore/socle-flutter`.

## 2026-10-14 15:15

### Fait

- Projet Flutter créé à la racine (`tidemark`, `dev.tidemark`, iOS 16.4+ et Android), README existant conservé.
- Thème transcrit depuis la charte : `TidemarkColors` (clair et sombre, en `ThemeExtension`), `TidemarkSpacing`, `TidemarkRadius`, `TidemarkSize`, `TidemarkTypography`, `buildTidemarkTheme`. Polices variables Bricolage Grotesque et Figtree embarquées (OFL), téléchargées depuis `google/fonts` à un commit précis.
- `MoodAnalyzer`, `Tag`, `TagKind`, `AnalysisResult` (`Tagged`, `Untagged`) et `FakeMoodAnalyzer`.
- Écran d'accueil provisoire, à remplacer par la liste des entrées (lot E).
- 13 tests : fidélité du thème à `tokens.json` (couleurs des deux thèmes, espacements, rayons, tailles, styles de texte), garde-fou contre les couleurs en dur hors de `lib/ui/theme/`, analyseur factice, accueil en clair et en sombre.
- Contrôle par mutation : couleur en dur dans `lib/main.dart`, jeton `tide` modifié, `space-4` modifié ; chaque mutation fait échouer au moins un test.
- CI `flutter.yml` (format, analyse `--fatal-infos`, tests), action épinglée par SHA ; `.claude/quality.json` renseigné (`scripts/lint-dart.sh`, `flutter test`).
- ADR-002 passé en « accepté » ; `CLAUDE.md` (stack, architecture), architecture technique (vue d'ensemble, sécurité, infrastructure, index) et plan mis à jour.
- App lancée sur le simulateur iPhone 17 Pro (iOS 26.5), en clair et en sombre : fond, polices et couleurs conformes à la charte.

### Décisions

- ADR-002 accepté par Yanis (« c'est validé », 2026-10-14), exclusion des sauvegardes comprise, comme recommandé par l'agent.
- Polices variables avec `FontVariation.weight` plutôt que des fichiers statiques : Google Fonts ne publie que les variables pour ces deux familles (agent).
- Fidélité vérifiée par un test qui lit `tokens.json`, plutôt que par un générateur de code : moins d'outillage pour le même contrôle (agent).
- Équipe de signature personnelle de Yanis (`AZ7L3PPYH9`), inscrite par `flutter create`, conservée dans le projet Xcode : ce n'est pas un secret (agent).

### Corrections et limites

- Première mutation sur le jeton `tide` non appliquée (syntaxe GNU de `sed`, absente de macOS) : refaite autrement, elle est détectée.
- Test humain sur l'iPhone 15 Pro non fait : le socle n'a qu'un écran provisoire ; le premier test humain sur appareil viendra avec la saisie (lot E).
- `minSdk` Android laissé à la valeur de Flutter : le minimum exigé par `llamadart` sera fixé quand il sera ajouté (lot G).

### Prochaine étape

Yanis relit et merge cette PR. Ensuite : spec du lot E (saisie d'une entrée et liste), avec la maquette reprise de l'exploration.
