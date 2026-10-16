# Tidemark

Journal d'humeur Flutter avec IA 100 % sur l'appareil : rien ne quitte ton téléphone.

> **En cours de cadrage.** Le [plan](docs/plan.md) fixe le périmètre et le calendrier (jusqu'au 2026-11-03) ; les specs et le choix du moteur d'IA local arrivent dans les prochaines PR.

Construit avec la chaîne de fabrication agentique [agentic-dev-workflow](https://github.com/yanis-vroland/agentic-dev-workflow) : plan, spec avec maquettes, tests d'abord, puis implémentation, chaque étape par une PR relue.

## Lancement

```sh
flutter pub get
scripts/fetch-llama-native.sh   # moteur llama.cpp, vérifié par empreinte SHA-256 (ADR-004)
flutter run
```

Le script télécharge les archives de llama.cpp utilisées par `llamadart` et les compare aux empreintes écrites dans `scripts/llama-native.sha256` ; sans lui, la construction échoue. Il revérifie les archives à chaque lancement et efface la sortie gardée du hook, pour que la construction suivante extraie l'archive qu'il vient de vérifier : le relancer après chaque clonage et avant toute construction destinée à être installée ou distribuée. Une construction lancée sans lui reprend le dossier tel qu'il est. Détail : [ADR-004](docs/adr/004-integrite-du-moteur-et-du-modele.md).

## Licence

[MIT](LICENSE)
