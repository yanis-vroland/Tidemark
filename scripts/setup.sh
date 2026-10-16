#!/usr/bin/env bash
# Installe tout ce qu'il faut avant flutter run, flutter build ou flutter test :
# les dépendances Dart (flutter pub get), puis le moteur natif llama.cpp vérifié
# par empreinte SHA-256 (scripts/fetch-llama-native.sh, ADR-004).
#
# Usage : scripts/setup.sh [bundle...]
#   Les arguments éventuels sont passés tels quels à fetch-llama-native.sh (bundles
#   à préparer) ; sans argument, les bundles de l'hôte.
#
# À lancer après chaque clonage et avant toute construction destinée à être
# installée ou distribuée : le script du moteur revérifie les archives à chaque
# lancement.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$root"

flutter pub get
scripts/fetch-llama-native.sh "$@"
