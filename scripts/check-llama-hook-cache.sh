#!/usr/bin/env bash
# Contrôle du cache de pub (ADR-004, option B, en complément de A) : avec
# llamadart_native_path, le hook de llamadart ne range ses extractions que sous
# native_bundles/local/. Tout autre dossier de native_bundles/ (tag ou autre dépôt)
# est un moteur que le hook a téléchargé lui-même, sans contrôle d'empreinte.
#
# Usage : scripts/check-llama-hook-cache.sh [--purge]
#   sans option : échoue si un tel dossier existe ;
#   --purge     : efface ces dossiers (cache restauré par la CI), puis réussit.
set -euo pipefail

cache="${PUB_CACHE:-$HOME/.pub-cache}"
purge=0
case "${1:-}" in
  "") ;;
  --purge) purge=1 ;;
  *) echo "check-llama-hook-cache : option inconnue : $1" >&2; exit 2 ;;
esac

found=()
for bundles in "$cache"/hosted/pub.dev/llamadart-*/.dart_tool/llamadart/native_bundles; do
  [ -d "$bundles" ] || continue
  for entry in "$bundles"/* "$bundles"/.[!.]*; do
    [ -e "$entry" ] || continue
    [ "$(basename "$entry")" = "local" ] && continue
    found+=("$entry")
  done
done

if [ "${#found[@]}" -eq 0 ]; then
  echo "Aucun moteur téléchargé par le hook de llamadart dans $cache"
  exit 0
fi

if [ "$purge" -eq 1 ]; then
  for entry in "${found[@]}"; do
    echo "Effacé : $entry"
    rm -rf "$entry"
  done
  exit 0
fi

echo "check-llama-hook-cache : moteur téléchargé par le hook, sans contrôle d'empreinte :" >&2
printf '  %s\n' "${found[@]}" >&2
exit 1
