# Spec 001 : saisie et liste des entrées

Statut : validée (Yanis, 2026-10-14)
Date : 2026-10-14

## Besoin

En tant que personne qui tient son journal, je veux noter mon humeur du moment avec, si je le souhaite, quelques mots, puis retrouver mes entrées passées, afin de garder une trace de mes journées sans qu'aucune donnée ne quitte mon téléphone.

Lot E du [plan](../plan.md). Règles du [cahier des charges](../cahier-des-charges-fonctionnel.md) appliquées : RM1, RM2, RM3, RM13, RM14, RM15, RM16, RM24. Stockage : [ADR-002](../adr/002-stockage-local-chiffre.md). Maquette : voir « Maquette ».

## Écrans

- **Liste des entrées** : écran d'accueil. Entrées regroupées par jour, la plus récente en haut ; bouton « Nouvelle entrée ».
- **Saisie d'une entrée** : sélecteur d'humeur, champ de texte facultatif, « Enregistrer », « Annuler ».
- **Détail d'une entrée** : l'entrée entière, et « Supprimer cette entrée ».

## Critères d'acceptation

### Liste des entrées

- CA1 : Étant donné aucune entrée enregistrée, quand la personne ouvre l'app, alors la liste affiche l'état vide « Ta première entrée apparaîtra ici » et le bouton « Nouvelle entrée ».
- CA2 : Étant donné des entrées sur plusieurs jours, quand la liste s'affiche, alors les entrées sont regroupées par jour local, les jours du plus récent au plus ancien, et dans un jour les entrées de la plus récente à la plus ancienne.
- CA3 : Étant donné un groupe de jours, quand la liste s'affiche, alors l'intertitre vaut « Aujourd'hui » pour le jour même, « Hier » pour la veille, et sinon le jour de la semaine et la date (« Lundi 12 octobre »), avec l'année si elle diffère de l'année en cours (« Lundi 13 octobre 2025 »).
- CA4 : Étant donné une entrée avec texte, quand sa carte s'affiche, alors elle montre la pastille de l'humeur avec son chiffre, l'heure (« 21:40 »), le libellé de l'humeur et le début du texte sur deux lignes au plus.
- CA5 : Étant donné une entrée sans texte, quand sa carte s'affiche, alors elle montre la pastille, l'heure et le libellé, sans ligne de texte vide.
- CA6 : Étant donné plusieurs entrées le même jour (RM14), quand la liste s'affiche, alors chacune a sa carte sous l'intertitre de ce jour.

### Saisie d'une entrée

- CA7 : Étant donné l'écran de saisie ouvert, quand aucune humeur n'est choisie, alors « Enregistrer » est désactivé et l'aide « Choisis une humeur pour enregistrer. » s'affiche.
- CA8 : Étant donné l'écran de saisie, quand la personne touche une pastille, alors cette humeur est choisie (une seule à la fois), son libellé s'affiche sous les pastilles et « Enregistrer » devient actif.
- CA9 : Étant donné une humeur choisie et aucun texte, quand la personne touche « Enregistrer », alors l'entrée est enregistrée sans texte (RM13), avec la date et l'heure de la saisie (RM16), la liste réapparaît et l'entrée est en tête, sous « Aujourd'hui ».
- CA10 : Étant donné une humeur choisie et un texte, quand la personne touche « Enregistrer », alors l'entrée est enregistrée avec ce texte, la liste réapparaît et la carte montre le début du texte.
- CA11 : Étant donné un texte fait seulement d'espaces ou de retours à la ligne, quand la personne enregistre, alors l'entrée est enregistrée sans texte.
- CA12 : Étant donné un texte de 2 000 caractères, quand la personne tape un caractère de plus ou colle un texte plus long, alors le champ garde les 2 000 premiers caractères (RM27). À partir de 1 800 caractères, un compteur « 1 850 / 2 000 » s'affiche sous le champ.
- CA13 : Étant donné l'écran de saisie sans texte écrit (humeur choisie ou non), quand la personne touche « Annuler », alors la liste réapparaît et rien n'est enregistré.
- CA30 : Étant donné un texte écrit dans l'écran de saisie, quand la personne touche « Annuler », alors une confirmation demande « Abandonner cette entrée ? » avec « Abandonner » et « Continuer » ; « Abandonner » ramène à la liste sans rien enregistrer, « Continuer » laisse la saisie intacte.
- CA14 : Étant donné une erreur à l'enregistrement (base indisponible, stockage plein), quand la personne touche « Enregistrer », alors le bandeau « L'entrée n'a pas été enregistrée » s'affiche avec le texte « Le stockage du téléphone est peut-être plein ou indisponible. Libère de la place, puis réessaie : ton texte est conservé. » (même texte quelle que soit la cause), l'humeur et le texte saisis sont conservés, et le bouton devient « Réessayer ».
- CA15 : Étant donné l'enregistrement en cours, quand il dure, alors le bouton affiche « Enregistrement… », désactivé, et un second appui n'enregistre pas l'entrée deux fois.

### Détail et suppression

- CA16 : Étant donné la liste, quand la personne touche une carte, alors le détail affiche la date complète, l'heure, la pastille et le libellé de l'humeur, et le texte entier (ou rien s'il n'y a pas de texte).
- CA17 : Étant donné le détail d'une entrée, quand il s'affiche, alors il n'offre aucun moyen de modifier l'entrée (RM15).
- CA18 : Étant donné le détail, quand la personne touche « Supprimer cette entrée », alors une confirmation demande « Supprimer cette entrée ? » et précise que la suppression est définitive, avec « Supprimer » et « Annuler ».
- CA19 : Étant donné la confirmation, quand la personne touche « Supprimer », alors l'entrée est effacée de la base, la liste réapparaît sans elle, et un intertitre de jour sans entrée disparaît (RM15, RM28).
- CA20 : Étant donné la confirmation, quand la personne touche « Annuler », alors rien n'est supprimé et le détail reste affiché.

### Stockage

- CA21 : Étant donné des entrées enregistrées, quand l'app est fermée puis relancée, alors la liste montre les mêmes entrées.
- CA22 : Étant donné la base de l'app, quand on l'ouvre sans la bonne clé, alors l'ouverture échoue : les entrées sont chiffrées au repos (RM2, ADR-002).
- CA23 : Étant donné un premier lancement, quand l'app ouvre la base, alors une clé aléatoire de 256 bits est créée et gardée dans le trousseau iOS ou le Keystore Android ; aux lancements suivants, la même clé est réutilisée.
- CA24 : Étant donné une entrée enregistrée, quand elle a un texte, alors son statut d'analyse est « en attente » ; sans texte, il est « non analysée » (RM24). Aucune analyse n'est lancée dans ce lot.
- CA25 : Étant donné l'app installée, quand le système sauvegarde le téléphone, alors la base n'est pas incluse dans la sauvegarde (ADR-002) : exclusion de sauvegarde sur iOS, sauvegarde automatique désactivée pour la base sur Android.

### Accessibilité et thème

- CA26 : Étant donné le sélecteur d'humeur, quand un lecteur d'écran le parcourt, alors chaque pastille s'annonce « Humeur 4 sur 5 : Bien » et indique si elle est choisie.
- CA27 : Étant donné la taille de texte du système à 200 %, quand la liste, la saisie et le détail s'affichent, alors aucun texte n'est tronqué ni ne déborde.
- CA28 : Étant donné le thème sombre du système, quand les trois écrans s'affichent, alors ils utilisent les couleurs du thème sombre de la charte.
- CA29 : Étant donné l'app qui démarre, quand l'écran de lancement natif s'affiche, alors son fond est la couleur `surface` de la charte, en clair et en sombre (plan, lot E).

### Ajoutés après les revues de code (CA31 à CA36, à valider par Yanis)

- CA31 : Étant donné la liste en cours de lecture, quand l'écran s'affiche, alors le titre « Ton journal » est visible, sans l'état vide.
- CA32 : Étant donné une erreur de lecture de la base, quand la liste s'affiche, alors elle annonce « Ton journal n'a pas pu être lu » et précise que les entrées sont toujours sur le téléphone, sans afficher l'état vide.
- CA33 : Étant donné une suppression confirmée qui échoue, quand l'erreur survient, alors le détail reste affiché et un message dit « L'entrée n'a pas été supprimée. Réessaie. ».
- CA34 : Étant donné un enregistrement en cours, quand la personne fait un geste de retour, alors rien ne se passe ; l'écran se ferme une fois l'entrée enregistrée.
- CA36 : Étant donné une carte de la liste, quand un lecteur d'écran la parcourt, alors elle s'annonce comme un bouton avec le libellé de l'humeur, son chiffre, l'heure et le début du texte (« Bien, humeur 4 sur 5, 21:40, Longue journée… »), sans lire plus de 120 caractères du texte.
- CA35 : Étant donné une base qui ne peut pas être ouverte au démarrage, quand l'app démarre, alors elle affiche « Ton journal n'a pas pu être ouvert », puis « Tes entrées sont toujours sur le téléphone, mais la clé qui les protège est introuvable. Rien n'a été effacé. » si la clé manque, ou « Rien n'a été effacé. Ferme l'app, puis rouvre-la. » pour toute autre cause ; aucune nouvelle clé n'est créée et la base n'est ni recréée ni effacée.

## Données

Fixées par cette spec, puis reportées dans l'architecture technique avec l'implémentation.

- **Interfaces** : les écrans passent par `EntryRepository` (implémentation `DriftEntryRepository` ; `FakeEntryRepository` dans `test/support/` pour les tests) ; la clé passe par `KeyStore` (implémentation `SecureKeyStore` sur le trousseau ou le Keystore ; une implémentation en mémoire dans les tests).
- **Entrée** (`Entry`) : identifiant, humeur (`mood`, 1 à 5), texte (`text`, facultatif, 2 000 caractères au plus), date et heure de saisie (`createdAt`, en UTC, avec le décalage horaire local du moment pour retrouver le jour local), statut d'analyse (`analysisStatus`).
- **Statut d'analyse** (`AnalysisStatus`) : `pending` (en attente), `tagged` (étiquetée), `untagged` (sans étiquette, RM9), `skipped` (non analysée : sans texte, RM24, ou détresse, RM17). Dans ce lot, seuls `pending` et `skipped` sont produits.
- **Étiquette** : table prévue pour le lot G, liée à l'entrée par clé étrangère avec suppression en cascade (RM15).

## Maquette

Artefact Claude de type « Design » ([lien privé](https://claude.ai/artifact/Nokoan8KiMNxU6n2UBwipG)), construit sur la charte. La copie versionnée, qui fait foi, est dans [`docs/maquettes/001-saisie-et-liste-des-entrees/`](../maquettes/001-saisie-et-liste-des-entrees/) ; les captures PNG y seront ajoutées par export de l'artefact. Écart assumé : l'implémentation suit les jetons de la charte (`mood-dot` de 56 points dans le sélecteur, `mood-dot-sm` de 40 dans la liste, `mood-dot-lg` de 72 dans le détail) là où la maquette dessine 52 et 60 points dans le sélecteur. Écrans : liste vide, liste avec entrées, saisie (nominale, vide, enregistrement, erreur), détail avec et sans texte, confirmation de suppression ; en clair et en sombre.

## Cas limites et erreurs

- Passage de minuit pendant la saisie : l'heure retenue est celle de l'appui sur « Enregistrer ».
- Jour d'une entrée : le jour local de sa saisie (décalage enregistré), pas le jour local actuel ; dans un jour, les entrées sont triées sur l'instant de saisie ; « Aujourd'hui » et « Hier » se calculent sur la date locale actuelle et sont recalculés au retour de l'app au premier plan.
- Changement de fuseau horaire : une entrée reste rangée dans le jour local où elle a été saisie.
- Texte avec émoji ou caractères accentués : comptés comme des caractères visibles pour la limite de 2 000 (un drapeau, un émoji composé ou une lettre suivie d'un accent combinant comptent pour un).
- Clé absente du trousseau alors que la base existe (restauration partielle, trousseau effacé, erreur du Keystore) : aucune nouvelle clé n'est créée, la base n'est ni recréée ni effacée, un message d'erreur s'affiche ; la suite est à préciser par la spec de la suppression totale (lot H).
- Clé restée dans le trousseau iOS après une désinstallation : parade du marqueur d'installation (ADR-002), mise en œuvre au lot H avec la suppression totale.

## Hors périmètre

- Détection de détresse et écran d'aide (lot F) : dans ce lot, aucune entrée n'est analysée. Les entrées `pending` créées avant le lot F n'ont jamais été contrôlées : le lot G doit faire passer toute entrée `pending` par le `DistressDetector` avant de l'analyser (RM5, RM8).
- Analyse et étiquettes (lot G) ; leur affichage sur les cartes et le détail.
- Export et suppression totale (lot H).
- Modification d'une entrée (RM15), saisie pour un jour passé (RM16), dictée.

## Questions ouvertes

Aucune. Confirmation sur « Annuler » seulement quand un texte est écrit (CA13, CA30) : décision de Yanis du 2026-10-14.
