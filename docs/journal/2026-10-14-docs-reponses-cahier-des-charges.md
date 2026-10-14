# Journal : réponses aux questions du cahier des charges

Branche `docs/reponses-cahier-des-charges`.

## 2026-10-14 10:30

### Fait

- Réponses de Yanis aux 10 questions ouvertes reportées en règles RM13 à RM22 ; parcours, droits et glossaire alignés.
- Corrections après la revue IA de la PR #6, mergée avant la réponse : export et RM1 alignés, source de RM3, `note` renommé `text`, « Personne » remplacé par « La personne » dans les statuts, hors périmètre sans ajout implicite, lien privé retiré, nouvelles questions ouvertes (destination de l'export, entrée sans texte, analyse différée, détresse sans texte, reprise du téléchargement).
- Plan, lot C : la charte existe déjà en artefact (Design System : https://claude.ai/artifact/LxwwPXPaLTB1ciS6m7NVeu ; maquette d'exploration : https://claude.ai/artifact/Nokoan8KiMNxU6n2UBwipG).

### Décisions

- Yanis accepte les recommandations de l'agent sur les 10 questions (2026-10-14).
- Les cas que la revue a relevés ne sont pas tranchés par l'agent : ils deviennent les questions ouvertes 1 à 5 (agent).

### Corrections et limites

- La PR #6 a été mergée avant le traitement de sa revue IA : la réponse est publiée en commentaire sur la PR #6, et les corrections arrivent par cette PR.

### Prochaine étape

Yanis merge cette PR. Ensuite : spike du moteur d'IA (lot B), en français (RM22).

## 2026-10-14 10:36

### Fait

- Réponses de Yanis à 4 des 5 nouvelles questions, reportées en RM23 à RM26 : export vers toute destination, entrée sans texte non analysée, série d'humeurs très basses qui déclenche l'écran d'aide, téléchargement interrompu qui repart de zéro. Glossaire, statuts et RM1 alignés.
- Mise à jour de Flutter lancée sur le poste de Yanis, avec son accord.

### Décisions

- Export par la feuille de partage, vers la destination choisie par la personne (Yanis) : exception à RM1, ADR à rédiger au lot H.
- Série d'humeurs très basses : écran d'aide même sans texte (Yanis) ; seuil à fixer dans la spec du lot F.

### Corrections et limites

- Réponse de Yanis sur l'entrée sans texte (« si pas de texte et que rien n'est intéressant à prendre, on save pas ») interprétée par l'agent : l'entrée est enregistrée, mais ni analysée ni étiquetée. Interprétation à confirmer dans la PR.
- La question sur l'analyse différée (entrée saisie sans modèle) reste ouverte.

### Prochaine étape

Yanis confirme l'interprétation de RM24 et merge cette PR. Ensuite : spike du moteur d'IA (lot B).
