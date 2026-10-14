# ADR-003 : Export par la feuille de partage

Statut : proposé (agent, 2026-10-14) ; à accepter par Yanis
Date : 2026-10-14

Contexte : RM1 interdit qu'une donnée de la personne quitte le téléphone par l'app ; le seul accès réseau admis est le téléchargement du modèle. Or la personne doit pouvoir emporter son journal (RM20), par exemple avant de changer de téléphone : la base est exclue des sauvegardes et sa clé ne quitte pas l'appareil (ADR-002), donc sans export, changer de téléphone fait perdre le journal. Yanis a décidé le 2026-10-14 que l'export passe par la feuille de partage du système, déclenché par la personne seulement, et qu'un ADR documente cette exception (RM23). Le comportement de l'export est fixé par la [spec 005](../specs/005-export-et-suppression-totale.md).

Exigences :

- **Aucun envoi par l'app elle-même** : ni serveur, ni compte, ni connexion ouverte par le code de Tidemark.
- **Toujours déclenché par la personne**, qui choisit la destination.
- **Pas de reste** : le fichier en clair ne doit pas traîner sur le téléphone après l'export.
- **Testable en CI** sans appareil, comme `MoodAnalyzer` et `KeyStore`.
- iOS 16.4+ et Android ; dépôt public sous licence MIT.

## Options envisagées

- **Feuille de partage du système** (`UIActivityViewController` sur iOS, `Intent.ACTION_SEND` et sélecteur sur Android) : la personne choisit la destination parmi les apps installées (Fichiers, AirDrop, mail, messagerie, Google Drive…). C'est le geste habituel sur les deux systèmes. Le fichier sort par une app que la personne choisit ; Tidemark n'ouvre aucune connexion. Risque : certaines destinations envoient le fichier sur un serveur (mail, stockage en ligne), mais c'est le choix explicite de la personne. Retenue.
- **Enregistrement dans Fichiers seulement** (`UIDocumentPickerViewController` en mode export sur iOS, Storage Access Framework `ACTION_CREATE_DOCUMENT` sur Android) : la personne choisit un dossier. Plus restrictif en apparence, mais Fichiers sur iOS et le sélecteur de documents sur Android donnent aussi accès à iCloud Drive ou Google Drive : la donnée peut quand même partir sur un serveur. Moins pratique pour passer d'un téléphone à l'autre (pas d'AirDrop direct), et deux implémentations natives à écrire, ou un autre paquet. Écartée : contrôle à peine meilleur, usage moins simple.
- **Pas d'export** : RM1 tenue à la lettre. Mais la personne perd son journal en changeant de téléphone, et ne peut pas le relire hors de l'app : contraire à RM20 et à l'idée que la personne reste maîtresse de ses données. Écartée.
- **Copie dans le presse-papiers** : aucun fichier, mais le presse-papiers est lu par d'autres apps (et synchronisé entre appareils Apple par Handoff). Écartée.

## Décision

Proposition de l'agent (2026-10-14), à accepter par Yanis : **export par la feuille de partage du système, avec le paquet `share_plus` 13.3.1**, épinglé exactement.

- **Seule exception à RM1** : le fichier d'export, et lui seul, quitte l'app, par la feuille de partage, après un appui de la personne sur « Exporter mes données ». Aucun autre chemin ne transmet de donnée de la personne.
- **Fichier en clair** : la personne en est prévenue sous le bouton (spec 005). Un export chiffré par mot de passe est hors périmètre du MVP.
- **Fichier temporaire** : écrit dans le cache de l'app, effacé à la fermeture de la feuille de partage ; dossiers temporaires d'export purgés au démarrage et avant chaque export (spec 005).
- **Isolé derrière une interface** `ShareSheet`, avec une implémentation factice pour les tests : la CI vérifie que la feuille n'est ouverte que sur l'appui de la personne, une fois, avec le seul fichier d'export.

## Dépendance : `share_plus`

Relevé sur pub.dev le 2026-10-14 (API `pub.dev/api/packages/share_plus`) et dans l'archive de la version 13.3.1 :

- **Version** 13.3.1 du 2026-10-01 ; Flutter 3.38.1 et Dart 3.10 au moins (le projet est en Flutter 3.47.7) ; « Flutter Favorite », 150 points sur pub.dev, éditeur `fluttercommunity.dev` (projet Plus Plugins).
- **Licence** BSD-3-Clause, compatible avec un dépôt MIT.
- **Réseau** : aucun. Le code natif iOS (`FPPSharePlusPlugin.m`) présente `UIActivityViewController` ; le code Android crée un `Intent` et passe le fichier par un `FileProvider` propre au paquet. Aucun appel réseau dans le code natif lu, aucune permission `INTERNET` ajoutée par son manifeste Android ; son manifeste de confidentialité iOS (`PrivacyInfo.xcprivacy`) ne déclare ni suivi ni donnée collectée. Les dépendances `url_launcher_*` qu'il tire ne servent que sur le web et le bureau.
- **Copie sur Android** : avant le partage, le paquet copie le fichier dans `cache/share_plus` de l'app, et ne vide ce dossier qu'au partage suivant. La spec 005 le purge aussi au démarrage et avant chaque export.
- **Résultat du partage** : `ShareResult`, avec `success`, `dismissed` ou `unavailable` ; la spec 005 efface le fichier quel que soit le résultat.

## Conséquences

- **RM1 reformulée** dans le cahier des charges : déjà fait par RM23 ; cet ADR en est la justification, cité par RM1, RM23 et la spec 005.
- **Destinations en ligne** : une personne peut envoyer son journal en clair par mail ou vers un stockage en ligne. C'est son choix, rendu explicite par la mention « Il n'est pas chiffré : choisis bien où tu l'envoies ». Le README le dira (lot J).
- **Contre-argument** : l'enregistrement dans Fichiers seulement réduirait un peu les destinations possibles et donnerait l'impression d'un contrôle plus strict. Mais iCloud Drive et Google Drive y restent accessibles : la protection serait surtout apparente, pour un usage moins simple.
- **Nouvelle dépendance native** : un paquet de plus à suivre, sur un projet communautaire actif ; atténué par l'interface `ShareSheet`, qui permet d'en changer sans toucher au reste de l'app.
- **Android, lecture différée** : l'app de destination peut lire le fichier après que `share_plus` a rendu la main. Le fichier de l'app est effacé à ce moment ; la copie de `share_plus` reste jusqu'au démarrage ou à l'export suivant. À vérifier au test humain (spec 005, « Cas limites »).
- **Aucun accès réseau ajouté à l'app** : à revérifier au test humain du lot H, en mode avion (l'export vers Fichiers doit fonctionner).

### Incertitudes

- Comportement de chaque destination Android (messagerie, mail, Google Drive) quand le fichier de l'app est effacé juste après le retour de `share_plus` : non essayé.
- Lecture du code natif faite sur la version 13.3.1 seulement ; toute montée de version relit le code natif avant d'être acceptée.

## Sources

- pub.dev, relevé le 2026-10-14 : [share_plus](https://pub.dev/packages/share_plus) (version, date, licence, points, contraintes de SDK).
- Code de la version 13.3.1 : archive `pub.dev/api/archives/share_plus-13.3.1.tar.gz`, fichiers `README.md` (« Share Results », « Known Issues »), `ios/share_plus/Sources/share_plus/FPPSharePlusPlugin.m` et `PrivacyInfo.xcprivacy`, `android/src/main/AndroidManifest.xml`, `android/src/main/kotlin/dev/fluttercommunity/plus/share/Share.kt`.
- Dépôt : [fluttercommunity/plus_plugins](https://github.com/fluttercommunity/plus_plugins/tree/main/packages/share_plus/share_plus).
