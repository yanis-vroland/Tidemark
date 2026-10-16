#!/usr/bin/env bash
# Contrôle du cache de pub (ADR-004, option B, en complément de A) : avec
# llamadart_native_path, le hook de llamadart ne range ses extractions que sous
# native_bundles/local/. Tout autre dossier de native_bundles/ (tag ou autre dépôt)
# est un moteur que le hook a téléchargé lui-même, sans contrôle d'empreinte.
#
# Usage : scripts/check-llama-hook-cache.sh [--purge]
#   sans option : échoue si un tel dossier existe, si aucun paquet llamadart n'est
#                 dans le cache (rien n'aurait été contrôlé), ou si aucune
#                 extraction du dossier vérifié (local/) n'existe (le hook ne l'a
#                 pas pris) ;
#   --purge     : efface ces dossiers (cache restauré par la CI), puis réussit,
#                 avec ou sans paquet llamadart.
# Variable : PUB_CACHE (par défaut ~/.pub-cache). Tous les hôtes de paquets
# (hosted/*) sont parcourus, miroirs compris. Une dépendance llamadart par git/ ou
# par chemin n'est pas couverte : Tidemark prend llamadart sur pub.dev, version fixée.
set -euo pipefail

cache="${PUB_CACHE:-$HOME/.pub-cache}"
purge=0
case "${1:-}" in
  "") ;;
  --purge) purge=1 ;;
  *) echo "check-llama-hook-cache : option inconnue : $1" >&2; exit 2 ;;
esac

packages=0
local_extractions=0
found=()
for package in "$cache"/hosted/*/llamadart-*; do
  [ -d "$package" ] || continue
  packages=$((packages + 1))
  bundles="$package/.dart_tool/llamadart/native_bundles"
  [ -d "$bundles" ] || continue
  # Toutes les entrées, cachées comprises : find, pas un motif.
  while IFS= read -r -d '' entry; do
    if [ "$(basename "$entry")" = "local" ] && [ -d "$entry" ] && [ ! -L "$entry" ]; then
      [ -z "$(find "$entry" -mindepth 1 -maxdepth 1)" ] ||
        local_extractions=$((local_extractions + 1))
      continue
    fi
    found+=("$entry")
  done < <(find "$bundles" -mindepth 1 -maxdepth 1 -print0)
done

if [ "$purge" -eq 1 ]; then
  for entry in ${found[@]+"${found[@]}"}; do
    echo "Effacé : $entry"
    rm -rf "$entry"
  done
  exit 0
fi

if [ "${#found[@]}" -gt 0 ]; then
  echo "check-llama-hook-cache : moteur téléchargé par le hook, sans contrôle d'empreinte :" >&2
  printf '  %s\n' "${found[@]}" >&2
  exit 1
fi
if [ "$packages" -eq 0 ]; then
  echo "check-llama-hook-cache : aucun paquet llamadart dans $cache : rien n'a été contrôlé" >&2
  exit 1
fi
if [ "$local_extractions" -eq 0 ]; then
  echo "check-llama-hook-cache : aucune extraction du dossier vérifié (native_bundles/local/) : le hook ne l'a pas pris" >&2
  exit 1
fi
echo "Aucun moteur téléchargé par le hook de llamadart dans $cache ; extraction du dossier vérifié présente"
