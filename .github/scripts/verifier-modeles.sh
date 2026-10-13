#!/usr/bin/env bash
# Vérifie que chaque subagent déclare un modèle autorisé dans son en-tête.
# Spec : https://github.com/yanis-vroland/agentic-dev-workflow/blob/main/docs/specs/007-modele-par-agent.md
# Choix du modèle : https://github.com/yanis-vroland/agentic-dev-workflow/blob/main/docs/adr/005-choix-du-modele-par-agent.md
# Usage :
#   verifier-modeles.sh                      tous les .claude/agents/*.md du répertoire courant
#   verifier-modeles.sh <fichier.md>...      les fichiers donnés
#   verifier-modeles.sh --afficher <fichier> vérifie le fichier et écrit son modèle sur stdout
set -uo pipefail

allowed="sonnet opus haiku"

# model_of <fichier> : écrit le modèle sur stdout s'il est valide, sinon un message sur
# stderr et code 1. Seule compte la ligne model: de l'en-tête (entre les deux « --- »).
model_of() {
  local file=$1 line n=0 in_header=0 closed=0 count=0 value=""
  if [ ! -f "$file" ]; then
    echo "$file : fichier introuvable." >&2
    return 1
  fi
  while IFS= read -r line || [ -n "$line" ]; do
    line=${line%$'\r'}
    n=$((n + 1))
    if [ "$n" -eq 1 ]; then
      [ "$line" = "---" ] || break
      in_header=1
      continue
    fi
    if [ "$line" = "---" ]; then
      closed=1
      break
    fi
    if [[ $line =~ ^model:(.*)$ ]]; then
      count=$((count + 1))
      value=${BASH_REMATCH[1]}
      # Espaces de début et de fin retirés
      value="${value#"${value%%[![:space:]]*}"}"
      value="${value%"${value##*[![:space:]]}"}"
    fi
  done <"$file"

  if [ "$in_header" -eq 0 ] || [ "$closed" -eq 0 ]; then
    echo "$file : en-tête absent ou non fermé (« --- » en première ligne et en fin d'en-tête)." >&2
    return 1
  fi
  if [ "$count" -eq 0 ]; then
    echo "$file : aucune ligne « model: » dans l'en-tête. Modèles autorisés : $allowed (ADR-005)." >&2
    return 1
  fi
  if [ "$count" -gt 1 ]; then
    echo "$file : $count lignes « model: » dans l'en-tête, une seule attendue." >&2
    return 1
  fi
  # Égalité exacte avec un alias : une valeur de plusieurs mots (« opus haiku »)
  # ajouterait un argument après --model dans ai-review.yml
  local alias
  for alias in $allowed; do
    if [ "$value" = "$alias" ]; then
      echo "$value"
      return 0
    fi
  done
  echo "$file : modèle « $value » refusé. Modèles autorisés : $allowed (ADR-005)." >&2
  return 1
}

if [ "${1:-}" = "--afficher" ]; then
  if [ "$#" -ne 2 ]; then
    echo "Usage : verifier-modeles.sh --afficher <fichier>" >&2
    exit 2
  fi
  model_of "$2"
  exit
fi

files=("$@")
if [ "$#" -eq 0 ]; then
  shopt -s nullglob
  files=(.claude/agents/*.md)
fi

fail=0
# Tableau vide : la forme +"…" évite l'erreur de set -u sous bash 3.2 (macOS)
for file in ${files[@]+"${files[@]}"}; do
  model_of "$file" >/dev/null || fail=1
done
exit "$fail"
