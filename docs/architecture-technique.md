# Architecture technique

Comment le produit est construit : composants, données, contrats, sécurité et infrastructure. Ce document décrit l'état actuel. Le pourquoi de chaque choix est dans un ADR de `docs/adr/`, et les règles métier sont dans [`cahier-des-charges-fonctionnel.md`](cahier-des-charges-fonctionnel.md).

Il est mis à jour dans la PR qui change ce qu'il décrit : modèle de données, contrat, sécurité, infrastructure, ou ADR accepté. Une section sans objet pour le projet reste, avec « Sans objet » et une phrase d'explication.

## Vue d'ensemble

Une app Flutter (iOS 16.4+, Android) sans serveur. Le socle existe (lot D) : thème de la charte, interface `MoodAnalyzer` et son implémentation factice. Le moteur réel et le stockage chiffré arrivent avec les specs des lots E et G.

```mermaid
flowchart LR
  ui[Écrans Flutter] --> analyzer[MoodAnalyzer]
  analyzer --> engine[llamadart : llama.cpp]
  engine --> model[(Qwen2.5-1.5B-Instruct Q4_K_M, GGUF, sur le téléphone)]
```

- **`MoodAnalyzer`** : interface qui isole le modèle local. Une implémentation factice sert aux tests et à la CI ; l'implémentation réelle repose sur `llamadart` 0.12.0, version épinglée exactement ([ADR-001](adr/001-moteur-ia-local.md)).
- **Sortie** : contrainte par un schéma JSON qui porte la liste fermée des étiquettes (RM19), puis validée par l'app (RM9).
- **Accélération** : GPU (Metal) sur iOS ; processeur seul sur Android tant que le GPU n'est pas vérifié sur un appareil réel.
- **Modèle** : environ 1,1 Go, téléchargé une fois (RM11, RM18), chargé en arrière-plan (jusqu'à 12 s au premier chargement sur iPhone 15 Pro).

## Modèle de données

À ADAPTER : les entités, leurs relations et leurs contraintes. Les noms sont ceux du glossaire du cahier des charges.

```mermaid
erDiagram
  ENTITE_A ||--o{ ENTITE_B : "À ADAPTER"
```

| Entité | Contraintes et invariants | Règle métier |
| --- | --- | --- |
| À ADAPTER | | RMn |

## Contrats entre composants

Les composants ne communiquent que par ces contrats. Le fichier de contrat fait foi ; ce tableau dit où il se trouve et qui en dépend. Un changement de contrat exige une spec.

| Contrat | Producteur | Consommateurs | Format | Fichier |
| --- | --- | --- | --- | --- |
| À ADAPTER | | | OpenAPI, MCP… | |

## Conventions d'API

À ADAPTER : nommage des routes, format des erreurs, pagination, versionnement, dates. Si un ADR les fixe, le résumer et renvoyer vers lui.

## Sécurité

- **Identification** : sans objet. Pas de compte : l'app sert une seule personne, sur son téléphone.
- **Droits** : sans objet pour la même raison ; la protection repose sur le verrouillage du téléphone et le chiffrement de la base.
- **Audit** : sans objet. Aucun journal d'usage ni analytics (RM1).
- **Chiffrement** : base `drift` chiffrée par SQLite3MultipleCiphers, clé aléatoire de 256 bits dans le trousseau iOS ou le Keystore Android, base exclue des sauvegardes du système ([ADR-002](adr/002-stockage-local-chiffre.md)). Mise en œuvre au lot E.
- **Secrets** : aucun dans le dépôt ni dans l'app ; la seule clé est générée sur le téléphone. Seul `.env.example` serait versionné.

## Infrastructure

- **Lancement local** : `flutter pub get` puis `flutter run`, sur un simulateur, un émulateur ou un appareil. Aucun service à démarrer.
- **Environnements** : un seul, le téléphone. Pas de serveur.
- **CI** : deux workflows, hérités de la chaîne agentic-dev-workflow. `garde-fous.yml` teste les hooks et les scripts, contrôle le journal de la PR et cherche des secrets dans tout l'historique ; `ai-review.yml` lance la revue IA à l'ouverture de la PR, avec le modèle déclaré dans `.claude/agents/reviewer.md`. Aucun job requis sur `main` : les rulesets ne sont pas disponibles sur un dépôt privé sans GitHub Pro, la règle « seul Yanis merge » tient par discipline. `flutter.yml` vérifie le format, lance l'analyse statique (`--fatal-infos`) et les tests, avec Flutter 3.47.7 ; l'action `subosito/flutter-action` est épinglée par SHA.
- **Déploiement** : À ADAPTER.

## Décisions d'architecture

| ADR | Titre | Statut |
| --- | --- | --- |
| [ADR-001](adr/001-moteur-ia-local.md) | Moteur d'IA local | accepté |
| [ADR-002](adr/002-stockage-local-chiffre.md) | Stockage local chiffré | accepté |
