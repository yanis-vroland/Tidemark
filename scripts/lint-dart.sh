#!/usr/bin/env bash
# Lint d'un fichier pour le hook de Claude Code (.claude/quality.json, spec 006 de la
# chaîne) : analyse statique des seuls fichiers Dart, rien pour les autres.
set -u
case "${1:-}" in
  *.dart) exec dart analyze --fatal-infos "$1" ;;
  *) exit 0 ;;
esac
