#!/usr/bin/env bash
# Limite les écritures du subagent learning-curator aux fichiers de piège docs/learnings/<slug>.md.
# Branché sur tous les outils dans .claude/settings.json : n'agit que si l'entrée du hook porte
# agent_type = learning-curator (ou <plugin>:learning-curator), champ que Claude Code renseigne
# pendant un subagent. Pourquoi pas un hook dans l'en-tête du subagent : décision du 2026-10-13 de la spec.
# Spec : https://github.com/yanis-vroland/agentic-dev-workflow/blob/main/docs/specs/005-capitalisation-des-pieges.md
# Exit 2 = action refusée, le message sur stderr est renvoyé à l'agent.
set -euo pipefail

# Fermeture en cas de panne : toute sortie autre que 0 ou 2 devient un refus
# Appelée par le trap, que shellcheck ne suit pas (SC2317 avant 0.11, SC2329 ensuite)
# shellcheck disable=SC2317,SC2329
fail_closed() {
  local code=$?
  if [ "$code" -ne 0 ] && [ "$code" -ne 2 ]; then
    echo "restrict-learnings : erreur interne (code $code), action refusée par précaution." >&2
    exit 2
  fi
}
trap fail_closed EXIT

deny() {
  echo "restrict-learnings : $1" >&2
  exit 2
}

command -v jq >/dev/null 2>&1 ||
  deny "jq n'est pas installé, action refusée. Installe jq pour rétablir les hooks de Claude Code."

input=$(cat)

# Un seul appel à jq pour tous les agents. Entrée vide, JSON invalide ou agent_type non
# textuel : refus quel que soit l'agent, faute de savoir qui appelle.
agent=$(jq -er 'if type == "object" and (.agent_type == null or (.agent_type | type == "string"))
  then (.agent_type // "") else error("entrée") end' <<<"$input" 2>/dev/null) ||
  deny "entrée illisible (JSON invalide ou agent_type non textuel), action refusée."

case $agent in
  learning-curator | *:learning-curator) ;;
  *) exit 0 ;;
esac

project=${CLAUDE_PROJECT_DIR:-}
project=${project%/}
[ -n "$project" ] || deny "CLAUDE_PROJECT_DIR absent, action refusée par précaution."

tool=$(jq -er '.tool_name | strings' <<<"$input" 2>/dev/null) ||
  deny "entrée illisible (tool_name absent), action refusée."

case $tool in
  Read | Grep | Glob)
    exit 0
    ;;
  Write | Edit) ;;
  *)
    deny "outil « $tool » interdit à learning-curator (Read, Grep, Glob, Write et Edit seulement)."
    ;;
esac

path=$(jq -er '.tool_input.file_path | strings' <<<"$input" 2>/dev/null) ||
  deny "$tool sans file_path, action refusée."

dir="$project/docs/learnings"

# Validation par jq sur la chaîne d'origine : $(...) retire les sauts de ligne finaux, et bash
# les caractères NUL. \A et \z ancrent sur toute la chaîne ($ accepterait un saut de ligne final).
# Le slug ne contient ni « / » ni « . » : ni sous-dossier ni « .. » possibles.
jq -e --arg dir "$dir/" '.tool_input.file_path | startswith($dir)
  and (.[($dir | length):] | test("\\A[a-z0-9]+(-[a-z0-9]+)*\\.md\\z"))' <<<"$input" >/dev/null 2>&1 ||
  deny "écriture refusée sur $path : learning-curator n'écrit que dans $dir/<slug>.md (slug en kebab-case)."

if [ -L "$project/docs" ] || [ -L "$dir" ] || [ -L "$path" ]; then
  deny "écriture refusée sur $path : lien symbolique dans le chemin."
fi

exit 0
