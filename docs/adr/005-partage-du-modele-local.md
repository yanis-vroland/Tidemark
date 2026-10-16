# ADR-005 : Partage du modèle local entre l'étiquetage et le bilan

Statut : accepté (Yanis, 2026-10-16)
Date : 2026-10-15

Contexte : le modèle local (Qwen2.5-1.5B-Instruct, environ 1,1 Go, [ADR-001](001-moteur-ia-local.md)) sert à deux fonctionnalités. La file d'analyse de la [spec 004](../specs/004-etiquetage-automatique.md) étiquette les entrées « en attente » une à la fois ; elle charge le modèle avant la première entrée et ne le libère qu'une fois la file vide. Le bilan de la [spec 006](../specs/006-bilan-de-la-semaine.md) demande une mise en mots « sur le même modèle que l'étiquetage, une génération à la fois », et prévoit que « la mise en mots attend son tour, dans la limite des 30 secondes » quand le modèle étiquette une entrée. La spec ne dit pas comment les deux se partagent le moteur.

Exigences :

- **Jamais deux générations à la fois** sur le moteur (spec 006).
- **Jamais deux copies du modèle en mémoire** : un iPhone ou un Android d'entrée de gamme ne supporte pas 2,2 Go de poids en plus de l'app, et le système tue l'app sans prévenir.
- **Aucune régression de l'étiquetage** : la file de la spec 004 garde son comportement et ses tests ; `analysis_queue.dart` et `llama_mood_analyzer.dart` sont corrigés en parallèle sur `fix/etiquetage-interruption` et ne doivent pas être touchés par le lot I.
- **Testable en CI** sans vrai modèle, avec `FakeMoodAnalyzer` et `FakeReviewWriter`.

## Options envisagées

- **Un verrou d'accès au modèle (`ModelGate`), posé autour des deux clients par des décorateurs.** `GatedMoodAnalyzer` détient le verrou du chargement du modèle (`prepare`) à sa libération (`release`) ; `GatedReviewWriter` le détient le temps d'une mise en mots (chargement, génération, libération). Les demandes sont servies dans l'ordre d'arrivée ; une demande du bilan abandonnée (délai de 30 s, écran quitté) sort de la file d'attente sans jamais charger le modèle. Aucun fichier de la spec 004 n'est modifié : les décorateurs sont posés dans `openJournal`. Retenue.
- **Un moteur partagé** : un seul `LlamaEngine` chargé, utilisé tour à tour par l'analyseur et par le rédacteur. Le modèle ne serait chargé qu'une fois pour les deux, ce qui épargne jusqu'à 12 s de chargement au bilan quand la file vient de tourner. Mais il faut sortir le moteur de `LlamaMoodAnalyzer`, donc réécrire l'analyseur et la file de la spec 004 en même temps que leur correction en cours. Écartée pour le lot I ; à reconsidérer si le temps de chargement gêne au test humain.
- **Un moteur par client, sans coordination** : le plus simple à écrire, mais deux modèles en mémoire et deux générations simultanées possibles. Contraire aux exigences. Écartée.
- **Passer la mise en mots par la file d'analyse** (une « tâche » de plus dans `AnalysisQueue`) : une seule file, un seul moteur. Mais la file est construite autour des entrées « en attente » de la base, et le bilan n'écrit rien dans la base (RM54) ; il faudrait changer son contrat, et toucher au fichier corrigé en parallèle. Écartée.

## Décision

Proposition de l'agent (2026-10-15), acceptée par Yanis le 2026-10-16 : **un verrou d'accès au modèle, `ModelGate`** (`lib/model/model_gate.dart`), partagé par `GatedMoodAnalyzer` (`lib/model/gated_mood_analyzer.dart`) et `GatedReviewWriter` (`lib/review/gated_review_writer.dart`), créés ensemble dans `openJournal`.

- L'analyseur garde le verrou tant que la file garde le modèle chargé, c'est-à-dire jusqu'à ce qu'elle soit vide : le bilan attend la fin du lot d'entrées en cours.
- Le rédacteur attend le verrou dans la limite des 30 s de la spec 006 ; au-delà, le bilan s'affiche sans texte et la demande quitte la file d'attente.
- Le verrou n'est rendu qu'une fois le moteur revenu : après une annulation, le rédacteur attend la fin de la génération avant de le rendre.

## Conséquences

- **Mémoire** : une seule copie du modèle à la fois, vérifiée en CI avec les faux (le rédacteur n'est appelé qu'après la libération de l'analyseur).
- **Attente du bilan** : juste après l'enregistrement de plusieurs entrées, la file peut garder le modèle plus de 30 s ; le bilan s'affiche alors sans texte, et revenir sur l'écran relance la mise en mots. Limite assumée, conforme à la spec 006 (« Modèle occupé par l'étiquetage »).
- **Temps de chargement** : chaque mise en mots charge le modèle (jusqu'à 12 s sur iPhone 15 Pro au premier chargement), puis le libère. À mesurer au test humain.
- **File bloquée par le bilan** : la file attend le verrou le temps d'une mise en mots, soit au plus 30 s, plus la fin du chargement du modèle si l'abandon arrive pendant ce chargement (`cancelGeneration` ne l'interrompt pas : jusqu'à 12 s mesurées sur iPhone 15 Pro). Elle ne voit pas ce délai : son chargement (`prepare`) prend simplement plus longtemps.
- **Contre-argument** : le moteur partagé serait plus rapide au bilan et plus économe en chargements. Il reste possible plus tard, derrière les mêmes interfaces `MoodAnalyzer` et `ReviewWriter`.

### Incertitudes

- Durée réelle d'un lot d'étiquetage sur les téléphones visés : non mesurée, donc fréquence réelle du bilan sans texte pour cause d'attente inconnue.
- Verrou sans limite de temps de détention : `cancelGeneration` n'interrompt pas le chargement du modèle (`setModel`). Si le chargement ou la libération ne revenait jamais, le verrou ne serait jamais rendu et l'étiquetage resterait bloqué jusqu'au redémarrage de l'app (échec fermé, sans fuite de données). Non observé, à vérifier au test humain ; une limite de détention côté rédacteur serait la parade.
- Comportement de `llamadart` quand deux `LlamaEngine` sont créés l'un après l'autre dans le même processus : prévu par l'API (`dispose`), non vérifié sur appareil. À vérifier au test humain.
