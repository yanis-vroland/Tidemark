#!/usr/bin/env bash
# Vérifie le hook restrict-learnings du subagent learning-curator selon la spec
# https://github.com/yanis-vroland/agentic-dev-workflow/blob/main/docs/specs/005-capitalisation-des-pieges.md
# (section « Subagent learning-curator », CA15 à CA20 et CA25). Claude Code renseigne
# agent_type dans l'entrée d'un hook lancé pendant un subagent.
set -u

hook="$(cd "$(dirname "$0")/.." && pwd)/.claude/hooks/restrict-learnings.sh"
fail=0

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

project="$work/projet"
mkdir -p "$project/docs/learnings"

# PATH réduit aux binaires dont le hook a besoin, sans jq
no_jq="$work/bin"
mkdir "$no_jq"
for cmd in bash cat; do
  ln -s "$(command -v "$cmd")" "$no_jq/$cmd"
done

# Sortie (stderr) du dernier lancement, pour vérifier un fragment du message
output=""

# check <code attendu> <description> <entrée> [PATH] [CLAUDE_PROJECT_DIR]
check() {
  local expected=$1 description=$2 input=$3 path=${4:-$PATH} dir=${5-$project}
  output=$(printf '%s' "$input" | PATH="$path" CLAUDE_PROJECT_DIR="$dir" "$hook" 2>&1 >/dev/null)
  local code=$?
  if [ "$code" -eq "$expected" ]; then
    echo "OK     $description"
  else
    echo "ÉCHEC  $description (attendu $expected, obtenu $code)"
    fail=1
  fi
}

# input <outil> <chemin> [agent] : entrée JSON d'un appel d'outil sur un fichier,
# par learning-curator par défaut
input() {
  printf '{"agent_type":"%s","tool_name":"%s","tool_input":{"file_path":"%s"}}' "${3:-learning-curator}" "$1" "$2"
}

# --- Écriture autorisée -----------------------------------------------------

check 0 "CA15 : Write d'un piège" "$(input Write "$project/docs/learnings/quantite-non-recalculee.md")"
check 0 "CA15 : Edit d'un piège"  "$(input Edit "$project/docs/learnings/quantite-non-recalculee.md")"
check 0 "CA15 : slug avec chiffres" "$(input Write "$project/docs/learnings/migration-002-avant-fixtures.md")"
printf '# Piège existant\n' >"$project/docs/learnings/existant.md"
check 0 "CA15 : Edit d'un piège existant (enrichissement)" "$(input Edit "$project/docs/learnings/existant.md")"
check 0 "CA15 : CLAUDE_PROJECT_DIR avec une barre finale" \
  "$(input Write "$project/docs/learnings/x.md")" "$PATH" "$project/"

# --- Écriture hors de docs/learnings/ ---------------------------------------

for file in README.md CLAUDE.md .claude/agents/reviewer.md src/app.ts; do
  check 2 "CA16 : Write $file" "$(input Write "$project/$file")"
done
check 2 "CA16 : Edit CLAUDE.md"      "$(input Edit "$project/CLAUDE.md")"
check 2 "CA16 : MultiEdit README.md" "$(input MultiEdit "$project/README.md")"
check 2 "CA18 : MultiEdit d'un piège (absent des outils du subagent)" \
  "$(input MultiEdit "$project/docs/learnings/x.md")"
check 2 "CA16 : message qui cite le chemin" "$(input Write "$project/README.md")"
if grep -qF "$project/README.md" <<<"$output"; then
  echo "OK     CA16 : chemin cité dans le message"
else
  echo "ÉCHEC  CA16 : chemin absent du message (sortie : $output)"
  fail=1
fi

# --- Chemins qui sortent du dossier ou n'ont pas la forme attendue -----------

check 2 "CA17 : remontée par .."      "$(input Write "$project/docs/learnings/../CLAUDE.md")"
check 2 "CA17 : remontée par .. (2)"  "$(input Write "$project/docs/learnings/../../docs/learnings/x.md")"
check 2 "CA17 : sous-dossier"         "$(input Write "$project/docs/learnings/a/b.md")"
check 2 "CA17 : extension .txt"       "$(input Write "$project/docs/learnings/piege.txt")"
check 2 "CA17 : .gitkeep"             "$(input Write "$project/docs/learnings/.gitkeep")"
check 2 "CA17 : slug en majuscules"   "$(input Write "$project/docs/learnings/Piege.md")"
check 2 "CA17 : slug avec espace"     "$(input Write "$project/docs/learnings/mon piege.md")"
check 2 "CA17 : slug vide"            "$(input Write "$project/docs/learnings/.md")"
check 2 "CA17 : autre projet"         "$(input Write "/tmp/autre/docs/learnings/x.md")"
check 2 "CA17 : chemin relatif"       "$(input Write "docs/learnings/x.md")"
check 2 "CA17 : nom seul, relatif"    "$(input Write "piege.md")"
check 2 "CA17 : sans extension"       "$(input Write "$project/docs/learnings/piege")"
check 2 "CA17 : dossier lui-même"     "$(input Write "$project/docs/learnings/")"
# Échappements JSON : la substitution $(...) retirerait le saut de ligne final, bash le NUL
check 2 "CA17 : saut de ligne final"  "$(input Write "$project/docs/learnings/x.md\\n")"
check 2 "CA17 : NUL dans le nom"      "$(input Write "$project/docs/learnings/x\\u0000.md")"

# --- Outils -------------------------------------------------------------------

check 0 "CA18 : Read hors de docs/learnings/" "$(input Read "$project/README.md")"
check 0 "CA18 : Grep" '{"agent_type":"learning-curator","tool_name":"Grep","tool_input":{"pattern":"x"}}'
check 0 "CA18 : Glob" '{"agent_type":"learning-curator","tool_name":"Glob","tool_input":{"pattern":"**/*.md"}}'
check 2 "CA18 : Bash" '{"agent_type":"learning-curator","tool_name":"Bash","tool_input":{"command":"echo x > docs/learnings/x.md"}}'
check 2 "CA18 : NotebookEdit" "$(input NotebookEdit "$project/docs/learnings/x.md")"
check 2 "CA18 : WebFetch" '{"agent_type":"learning-curator","tool_name":"WebFetch","tool_input":{"url":"https://example.com"}}'

# --- Autres agents : non concernés (CA25) -----------------------------------

check 0 "CA25 : session principale, Write README.md" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$project/README.md\"}}"
check 0 "CA25 : agent_type nul, Write README.md" \
  "{\"agent_type\":null,\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$project/README.md\"}}"
check 0 "CA25 : test-writer, Write tests/x.sh" "$(input Write "$project/tests/x.sh" test-writer)"
check 0 "CA25 : autre agent, Bash" '{"agent_type":"reviewer","tool_name":"Bash","tool_input":{"command":"git diff"}}'
check 0 "CA25 : nom voisin, learning-curator-bis" "$(input Write "$project/README.md" learning-curator-bis)"
check 2 "CA25 : nom préfixé par un plugin" "$(input Write "$project/README.md" plugin:learning-curator)"
check 0 "CA25 : autre agent, CLAUDE_PROJECT_DIR vide" "$(input Write "$project/README.md" reviewer)" "$PATH" ""
check 2 "CA25 : agent_type non textuel" \
  "{\"agent_type\":5,\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$project/README.md\"}}"
check 2 "CA25 : JSON invalide, quel que soit l'agent" '{"agent_type":"reviewer",'
check 2 "CA25 : jq absent, quel que soit l'agent" "$(input Read "$project/README.md" reviewer)" "$no_jq"

# --- Liens symboliques --------------------------------------------------------

ln -s "$project/CLAUDE.md" "$project/docs/learnings/lien.md"
check 2 "CA19 : piège qui est un lien symbolique" "$(input Write "$project/docs/learnings/lien.md")"

linked="$work/projet-lie"
mkdir -p "$linked/docs" "$work/ailleurs"
ln -s "$work/ailleurs" "$linked/docs/learnings"
check 2 "CA19 : docs/learnings/ qui est un lien symbolique" \
  "$(input Write "$linked/docs/learnings/x.md")" "$PATH" "$linked"

docs_linked="$work/projet-docs-lie"
mkdir -p "$docs_linked" "$work/ailleurs-docs/learnings"
ln -s "$work/ailleurs-docs" "$docs_linked/docs"
check 2 "CA19 : docs/ qui est un lien symbolique" \
  "$(input Write "$docs_linked/docs/learnings/x.md")" "$PATH" "$docs_linked"

# --- Fermeture en cas de panne ------------------------------------------------

check 2 "CA20 : JSON invalide"        'pas du json {'
check 2 "CA20 : entrée vide"          ''
check 2 "CA20 : tool_name absent"     "{\"agent_type\":\"learning-curator\",\"tool_input\":{\"file_path\":\"$project/docs/learnings/x.md\"}}"
check 2 "CA20 : tool_name non textuel" "{\"agent_type\":\"learning-curator\",\"tool_name\":5,\"tool_input\":{\"file_path\":\"$project/docs/learnings/x.md\"}}"
check 2 "CA20 : Write sans file_path" '{"agent_type":"learning-curator","tool_name":"Write","tool_input":{}}'
check 2 "CA20 : Edit sans tool_input" '{"agent_type":"learning-curator","tool_name":"Edit"}'

check 2 "CA20 : jq absent" "$(input Write "$project/docs/learnings/x.md")" "$no_jq"
if grep -q "jq" <<<"$output"; then
  echo "OK     CA20 : jq absent : message cite jq"
else
  echo "ÉCHEC  CA20 : jq absent : message sans jq (sortie : $output)"
  fail=1
fi

check 2 "CA20 : CLAUDE_PROJECT_DIR vide" "$(input Write "$project/docs/learnings/x.md")" "$PATH" ""
# Projet vide : le dossier attendu deviendrait /docs/learnings
check 2 "CA20 : CLAUDE_PROJECT_DIR vide, /docs/learnings/x.md" "$(input Write "/docs/learnings/x.md")" "$PATH" ""

# Une erreur interne ne doit jamais laisser passer : cat absent, le trap EXIT
# transforme la sortie 127 en refus (vérifié par mutation)
no_cat="$work/bin-sans-cat"
mkdir "$no_cat"
for cmd in bash jq; do
  ln -s "$(command -v "$cmd")" "$no_cat/$cmd"
done
check 2 "CA20 : cat absent" "$(input Write "$project/docs/learnings/x.md")" "$no_cat"
output=$(input Write "$project/docs/learnings/x.md" | env -u CLAUDE_PROJECT_DIR "$hook" 2>&1 >/dev/null)
code=$?
if [ "$code" -eq 2 ]; then
  echo "OK     CA20 : CLAUDE_PROJECT_DIR absent"
else
  echo "ÉCHEC  CA20 : CLAUDE_PROJECT_DIR absent (attendu 2, obtenu $code)"
  fail=1
fi

exit $fail
