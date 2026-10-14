# Journal : suites de la revue IA de la spec 002

Branche `docs/spec-002-suites`.

## 2026-10-14 20:15

### Fait

- PR #14 (spec 002 et maquette) mergée par Yanis le 2026-10-14 ; son dernier commit (aa69b5c) est sur `main`.
- Revue IA de la PR #14 lue : 1 point bloquant, 5 à corriger, 7 suggestions. Rien n'est encore corrigé : la session a été close à la demande de Yanis.

### Décisions

- Spec 002 et maquette validées par Yanis (2026-10-14), sous réserve des corrections de la revue IA ci-dessous. Le statut de la spec passera à « validée » dans la PR de cette branche.

### Corrections et limites

- La PR #14 a été mergée avec un point bloquant : CA5 contredit la règle 2 et la liste des termes. Aucune expression ne couvre « je ne veux pas mourir », puisque « veux mourir » n'y est pas contigu. Ne pas écrire les tests avant la correction.

### Prochaine étape

Corriger la spec 002 dans cette branche, puis ouvrir la PR et publier la « Réponse à la revue IA » sur la PR #14. Questions à poser à Yanis :

- **CA5 (bloquant)** : comment couvrir la négation ? Trois options :
  - ajouter des expressions avec négation (« veux pas mourir », « veux plus vivre ») ;
  - autoriser un mot de négation intercalé ;
  - changer l'exemple de CA5.
- **CA6 et RM8** : une entrée avec texte qui complète une série passe-t-elle en `skipped` ? Ou bien RM8 se limite-t-elle à la détresse détectée dans le texte ?
- **Liste des termes** :
  - « en finir » est gardé alors que « me tue » est exclu pour le même motif : à trancher ;
  - ajouts proposés : « envie de disparaitre », « veux disparaitre », « plus envie de rien », « me laisser mourir » ;
  - retirer « plus aucune issue », redondant avec « aucune issue ».

Corrections sans décision :

- Hors périmètre et CA16 : le lot G repasse chaque entrée par `detectInText` juste avant de l'analyser, comme le demande la spec 001.
- Ajouter des CA pour trois règles de la série : la série prolongée qui redéclenche l'écran, l'entrée supprimée qui ne compte plus, le changement de degré qui s'applique à toute la série.
- Reformuler CA6 dans les termes de la règle : au plus D × 24 h entre la plus ancienne et la plus récente des N.
- Données :
  - configuration native pour `url_launcher` : `<queries>` DIAL sur Android, `LSApplicationQueriesSchemes` sur iOS si `canLaunchUrl` est utilisé ;
  - nom d'écran `SettingsScreen`.
- Maquette :
  - ajouter `ReglagesChargementSombre` ;
  - motiver ou dessiner les états vide, chargement et erreur de la liste avec l'icône ;
  - ramener sur des jetons de la charte : 3114 en 44 px, `padding` de 20, `gap` de 2, `padding-top` de 56, bouton radio de 22, icônes de 20 et 24. Sinon, ajouter des jetons, au plus tard dans la PR d'implémentation ;
  - mention « L'écran d'aide ne peut pas être désactivé. » ;
  - captures PNG ou issue, à demander à Yanis.
- Cahier des charges : parcours utilisateur, étape 4, à compléter avec la série et le réglage.
- Architecture technique (table `settings`, schéma v2, `addEntry(status)`) : dans la PR d'implémentation.

Toujours en attente de Yanis pour le lot E :

- validation de CA31 à CA36 ;
- test humain sur l'iPhone 15 Pro ;
- trois arbitrages de confidentialité :
  - clavier ;
  - écran des apps récentes ;
  - exclusion de sauvegarde iOS bloquante ;
- accord pour les issues de la maquette et des frictions de la chaîne ;
- suppression des branches distantes déjà mergées.
