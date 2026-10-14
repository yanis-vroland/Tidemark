# Journal : spec 005, export et suppression totale

Branche `docs/spec-005-export-suppression`.

## 2026-10-14 20:35

### Fait

- Spec 005 rédigée : règles de l'export (format JSON version 1 documenté, partage par la feuille du système, fichier temporaire effacé), de la suppression totale (confirmation « SUPPRIMER », ordre des étapes, reprise au démarrage), suite de l'écran « clé introuvable » (CA35 de la spec 001), marqueur d'installation (ADR-002) ; 35 critères d'acceptation.
- ADR-003 « Export par la feuille de partage » rédigé au statut « proposé » : options, décision, dépendance `share_plus` 13.3.1 (BSD-3-Clause), lue dans son code natif (aucun accès réseau, copie dans `cache/share_plus` sur Android).
- Maquette en artefact « Design » (24 artboards, clair et sombre) : Réglages (nominal, export en cours, en erreur, journal vide), confirmation (vide, saisie, en cours, interrompue, depuis la clé introuvable), liste après suppression, démarrage (clé introuvable, reprise en échec). Copie dans `docs/maquettes/005-export-et-suppression-totale/`.
- Cahier des charges : glossaire (`JournalExporter`, `ShareSheet`, `JournalWiper`, `wipe-pending`, `installed`), transitions des données de l'app, RM1, RM12, RM20, RM23 précisées, RM40 à RM45, lot H en « spec validée ». Architecture technique : ADR-003 ajouté à l'index, « proposé ».

### Décisions

Toutes prises par l'agent, à la demande de Yanis (2026-10-14, décisions métier déléguées) ; détail dans la spec, « Questions ouvertes » :

- Export du réglage de sensibilité, pas de l'identifiant interne des entrées ; export désactivé si le journal est vide.
- Fichier en clair, dit par une mention permanente, sans dialogue en plus.
- Confirmation par « SUPPRIMER » écrit (casse et espaces ignorés), sur un écran plein.
- Ordre : marqueur `wipe-pending`, base, clé, modèle, fichiers temporaires ; reprise au démarrage.
- Clé introuvable : suppression proposée, jamais automatique.
- Marqueur d'installation : clé restante effacée seulement si aucune base n'existe (protège les installations des lots E et F).
- `danger` en texte et bordure seulement, faute de jeton `on-danger`.
- Ordre de la PR (une seule PR pour la spec, la maquette et l'ADR) : consigne de Yanis.

### Corrections et limites

- Pas de captures PNG de la maquette, comme pour les maquettes 001 et 002.
- Bandeau « La suppression n'a pas commencé » (CA20) et feuille de partage non dessinés.
- Partage sur Android : l'app de destination peut lire le fichier après le retour de `share_plus` ; comportement à vérifier au test humain.
- Contraintes posées au lot G : modèle dans `Application Support/tidemark/model/`, forme `{kind, label}` des étiquettes dans l'export, annulation du téléchargement et de l'analyse à la suppression totale.
- Numérotation des règles à partir de RM40, pour éviter les collisions avec deux autres PR de specs ouvertes en parallèle.

### Prochaine étape

Yanis valide la spec et la maquette, et accepte (ou non) l'ADR-003. Ensuite : tests par le subagent `test-writer`, committés seuls, puis implémentation (branche `feat/export-suppression`).
