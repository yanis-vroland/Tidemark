# Journal : charte graphique (lot C)

Branche `docs/charte`.

## 2026-10-14 15:02

### Fait

- Artefact « Design System » Tidemark complété : 7 composants (sélecteur d'humeur, carte d'entrée, puce d'étiquette, bouton, champ de texte, bandeau d'erreur, mention de chargement), chacun avec un aperçu HTML qui n'utilise que les jetons et un README d'usage.
- Charte versionnée dans `docs/maquettes/000-charte/` : règles d'usage, jetons, composants, inventaire des écrans du MVP, tableau des contrastes recalculé (17 paires, deux thèmes, toutes au-dessus de leur seuil).
- Plan : tâches du lot C cochées ou complétées.

### Décisions

- Composants en aperçus HTML, sans bibliothèque JavaScript : le lot D les recrée en widgets Flutter à partir des jetons (agent).
- Pas de couleur par émotion sur les puces d'étiquette : une couleur suggérerait un jugement (agent, à valider par Yanis).

### Corrections et limites

- Pas de captures PNG : l'artefact est privé et ses aperçus se rendent dans son interface. Reportées au lot E.
- Jeu d'icônes non choisi : reporté au lot D.
- Le `lastChange` de l'index de l'artefact a d'abord été publié avec une heure inventée (13:15 UTC), corrigée en 13:01 UTC dans la minute.

- Le premier commit (e7ad27f) incluait par erreur le dossier de travail d'un subagent (`.claude/worktrees/`, dépôt Git imbriqué), ajouté par un `git add -A` de l'agent. Retiré de l'index, et dossier ajouté au `.gitignore`. Friction à remonter à la chaîne P1 : le `.gitignore` du template ne l'exclut pas.

### Prochaine étape

Yanis valide la charte (dans l'artefact ou dans cette PR). Ensuite : lot D, transcription des jetons en Dart.
