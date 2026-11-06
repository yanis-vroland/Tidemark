# Journal de la branche docs/demo-etiquetage

## 2026-11-05 23:10

### Fait

- Démo refaite pour montrer l'étiquetage par le modèle local (spec 004) et la mise en mots du bilan (spec 006), sur le simulateur iOS (iPhone 17 Pro), avec l'app réelle :
  - `docs/demo/tidemark.mp4` : H.264, 30 i/s, 496 × 1080, sans son, 36 s, 1,4 Mo ;
  - `docs/demo/tidemark.gif` : 320 × 697, 10 i/s, palette `ffmpeg`, 36 s, 3,2 Mo ;
  - captures `docs/captures/ios-accueil-etiquettes.png` et `docs/captures/ios-detail-etiquettes.png` (1206 × 2622).
- Modèle téléchargé par l'app elle-même, depuis son écran « Télécharger le modèle », dans un lancement préparatoire non filmé : 59 s (Wi-Fi du Mac), un seul essai, empreinte vérifiée. Aucun autre moyen de téléchargement.
- Parcours filmé : bienvenue ; accueil du soir animé ; check-in « Bien » ; sujets travail et nature ; phrase « Longue journée au travail, mais la balade du soir au bord de l'eau m'a fait du bien. » ; « Enregistrer » ; coquillage ramassé ; « Continuer » ; accueil, carte avec « Analyse en cours sur ton téléphone… » puis ses étiquettes ; détail (section « Étiquettes », « Analysé sur ton téléphone ») ; onglet « Semaine » avec « Mise en mots sur ton téléphone… » puis le texte du bilan.
- Mesures sur le simulateur (processeur du Mac, Apple M3) :
  - étiquetage de l'entrée filmée : 4,5 s entre « Enregistrer » et les étiquettes, chargement du modèle compris ;
  - mise en mots du bilan : 5,9 s ;
  - premier chargement du modèle dans le lancement : 13,4 s ; étiquetage des trois entrées des jours précédents, modèle chargé : 1,1 à 1,7 s chacune.
- Étiquettes obtenues pour l'entrée filmée : émotions solitude, joie ; thèmes travail, nature.
- Texte du bilan : « La semaine a été dédiée à la routine du travail et aux moments de joie, tout en s'occupant de sa santé. La régularité est maintenue avec quelques jours spécifiques. »
- Montage : touchers ×1,4 à ×1,5, frappe ×2, attente du bilan ×1,5 ; apparition des étiquettes sur l'accueil et lecture du bilan en vitesse réelle.
- README : texte alternatif et légende de la démo, tableau des deux nouvelles captures ; la phrase qui renvoyait aux captures Android pour l'étiquetage ne renvoie plus qu'à l'ancien design ; lien direct vers la capture Android étiquetée dans « Mesures ».

### Décisions

- Agent : scénario d'intégration temporaire, jamais committé (`integration_test` retiré, `git diff pubspec.yaml pubspec.lock` vide) ; horloge fixée au jeudi 5 novembre 2026, 20 h 41 ; barre d'état fixée ; bannière DEBUG masquée ; animations d'ambiance actives.
- Agent : base de démo dans un dossier propre et clé en mémoire, pour ne pas toucher au trousseau du simulateur.
- Agent : les trois entrées fictives des jours précédents sont étiquetées par le vrai modèle avant le tournage, plutôt qu'avec des étiquettes écrites à la main.
- Agent : journal daté du 2026-11-05, jour réel de création sur le poste (23 h 10), et non du 2026-11-06 prévu dans la consigne : `verifier-journal.sh` refuse une entrée antérieure à la date du nom.
- Agent : touchers envoyés comme des événements du périphérique, pour éviter la croix rouge du moteur de test ; aucune image rouge détectée dans la vidéo brute.

### Corrections et limites

- Deux tournages : le premier montrait déjà tout, mais l'analyse finissait avant le retour à l'accueil. Le second quitte la célébration plus tôt : « Analyse en cours sur ton téléphone… » reste visible environ 1 s, en vitesse réelle.
- Qualité du modèle de 1,5 milliard de paramètres : « solitude » pour une balade, et un bilan qui parle de santé à partir des étiquettes « santé » proposées pour les jours précédents. Sortie montrée telle quelle.
- Les temps viennent du simulateur, donc du processeur du Mac ; ils ne valent pas ceux d'un iPhone. Le modèle venait d'être lu, ce qui accélère son chargement (cache du système).
- `flutter test` désinstalle l'app à la fin du scénario : l'app installée sur le simulateur, avec ses données fictives et le modèle, n'y est plus.
- Écran d'accueil de la démo avec bienvenue forcée (`showWelcome`) alors que le journal contient déjà des entrées, comme pour la démo précédente.
- Test humain : sans objet (aucun comportement de l'app modifié).

### Prochaine étape

- PR en brouillon ; relecture et merge par Yanis.

## 2026-11-06 09:40

### Fait

- PR passée de brouillon à prête, pour lancer la revue IA : rien de bloquant, rien à corriger, cinq suggestions.
- Légende de la démo dans le README : 5,9 s au lieu de 6 s pour le bilan ; mention de l'horloge fixée et de la bienvenue forcée ; sortie du modèle montrée telle quelle, erreurs comprises, avec renvoi vers « Limites » (suggestions 1 à 3).

### Décisions

- Agent : suggestion 4 (poids du GIF, 3,2 Mo) laissée à l'arbitrage de Yanis ; suggestion 5 (case du plan) à cocher après sa validation.

### Corrections et limites

- Aucune.

### Prochaine étape

- Relecture de la vidéo et du GIF, puis merge par Yanis.
