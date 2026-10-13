#!/usr/bin/env bash
# Vérifie les hooks de lint et de tests selon la spec
# https://github.com/yanis-vroland/agentic-dev-workflow/blob/main/docs/specs/006-revue-securite-et-hooks-qualite.md
# Chaque vérification cite son critère d'acceptation (CAn) ou le cas limite testé.
# Les commandes de lint et de tests sont de faux scripts qui laissent une trace
# (arguments reçus, nombre de lancements) hors du projet testé.
# Les fonctions de vérification sont appelées via check, que shellcheck ne suit pas.
# Le code d'avertissement dépend de la version : SC2317 avant 0.11, SC2329 ensuite.
# shellcheck disable=SC2317,SC2329
set -u

repo="$(cd "$(dirname "$0")/.." && pwd -P)"
lint_hook="$repo/.claude/hooks/lint.sh"
tests_hook="$repo/.claude/hooks/run-tests.sh"
fail=0

for hook in "$lint_hook" "$tests_hook"; do
  if [ ! -f "$hook" ]; then
    echo "ÉCHEC  $hook est absent : les vérifications qui l'utilisent vont échouer"
    fail=1
  fi
done

# Chemin canonique : sous macOS, /var est un lien vers /private/var
# Un échec de mktemp arrête le test : sinon « cd "" » laisserait $work sur le
# dossier courant, que le trap effacerait.
if ! work=$(mktemp -d) || ! work=$(cd "$work" && pwd -P); then
  echo "Erreur : mktemp -d a échoué" >&2
  exit 1
fi
trap 'rm -rf "$work"' EXIT

# Isole les tests de la configuration Git de l'utilisateur et de l'appelant
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
: >"$work/gitconfig"
export GIT_CONFIG_GLOBAL="$work/gitconfig"
export GIT_CONFIG_NOSYSTEM=1

# Répertoire courant neutre : les hooks trouvent le projet par CLAUDE_PROJECT_DIR
neutral="$work/cwd"
mkdir "$neutral"

# --- Outils de vérification -------------------------------------------------

code=0
out=""
err=""

pass() {
  echo "OK     $1"
}

failed() {
  echo "ÉCHEC  $1${2:+ ($2)}"
  fail=1
}

# check <description> <commande...> : OK si la commande réussit
check() {
  local description=$1
  shift
  if "$@"; then
    pass "$description"
  else
    failed "$description"
  fi
}

# Vérifie le code de sortie du dernier lancement
check_code() {
  local expected=$1 description=$2
  if [ "$code" -eq "$expected" ]; then
    pass "$description"
  else
    failed "$description" "attendu $expected, obtenu $code : $(head -n 1 <<<"$err")"
  fi
}

# run_hook <hook> <projet> <entrée JSON> [PATH] : lance le hook depuis le
# répertoire neutre ; remplit code, out (stdout) et err (stderr)
run_hook() {
  local hook=$1 project=$2 input=$3 path=${4:-$PATH}
  (cd "$neutral" && printf '%s' "$input" |
    PATH="$path" CLAUDE_PROJECT_DIR="$project" "$hook") >"$work/stdout" 2>"$work/stderr"
  code=$?
  out=$(cat "$work/stdout")
  err=$(cat "$work/stderr")
}

# Entrée de PostToolUse pour une modification de fichier
edit_input() {
  local session=$1 file=$2 tool=${3:-Edit}
  jq -nc --arg s "$session" --arg f "$file" --arg t "$tool" \
    '{session_id: $s, hook_event_name: "PostToolUse", tool_name: $t, tool_input: {file_path: $f}}'
}

# Entrée de Stop
stop_input() {
  local session=$1 active=$2
  jq -nc --arg s "$session" --argjson a "$active" \
    '{session_id: $s, hook_event_name: "Stop", stop_hook_active: $a}'
}

run_lint() {
  run_hook "$lint_hook" "$1" "$(edit_input "$2" "$3" "${4:-Edit}")"
}

run_stop() {
  run_hook "$tests_hook" "$1" "$(stop_input "$2" "$3")"
}

# Nouveau projet : dépôt Git avec un fichier src/a.ts
new_project() {
  local dir
  dir=$(mktemp -d "$work/projet.XXXXXX")
  git init -q "$dir"
  mkdir "$dir/src"
  printf 'const a = 1;\n' >"$dir/src/a.ts"
  echo "$dir"
}

# write_config <projet> <lint> <test> : .claude/quality.json avec les deux clés
write_config() {
  mkdir -p "$1/.claude"
  jq -n --arg l "$2" --arg t "$3" '{lint: $l, test: $t}' >"$1/.claude/quality.json"
}

# Nouveau dossier d'outils factices, hors de tout projet
new_tools() {
  mktemp -d "$work/outils.XXXXXX"
}

# make_lint <dossier> <code de sortie> [nombre de lignes de sortie]
# Faux lint : compte ses lancements, écrit ses arguments un par ligne, affiche
# des lignes numérotées lint-ligne-001… sur stdout et sort avec le code donné.
make_lint() {
  local dir=$1 status=$2 lines=${3:-1}
  cat >"$dir/lint" <<EOF
#!/usr/bin/env bash
echo run >>"$dir/lint-calls"
: >"$dir/lint-args"
for arg in "\$@"; do printf '%s\n' "\$arg" >>"$dir/lint-args"; done
i=1
while [ "\$i" -le $lines ]; do printf 'lint-ligne-%03d\n' "\$i"; i=\$((i + 1)); done
exit $status
EOF
  chmod +x "$dir/lint"
}

# make_test_tool <dossier> : fausse commande de tests. Compte ses lancements,
# note son répertoire courant et son nombre d'arguments, affiche 120 lignes
# test-ligne-001… et sort avec le code écrit dans <dossier>/test-exit (0 sinon).
make_test_tool() {
  local dir=$1
  cat >"$dir/tests" <<EOF
#!/usr/bin/env bash
echo run >>"$dir/test-calls"
pwd -P >"$dir/test-cwd"
echo "\$#" >"$dir/test-argc"
i=1
while [ "\$i" -le 120 ]; do printf 'test-ligne-%03d\n' "\$i"; i=\$((i + 1)); done
if [ -f "$dir/test-exit" ]; then exit "\$(cat "$dir/test-exit")"; fi
exit 0
EOF
  chmod +x "$dir/tests"
}

# Nombre de lignes d'un fichier de trace (0 s'il est absent)
count_lines() {
  if [ -f "$1" ]; then
    wc -l <"$1" | tr -d ' '
  else
    echo 0
  fi
}

equal() {
  [ "$1" = "$2" ]
}

not_exists() {
  [ ! -e "$1" ] && [ ! -L "$1" ]
}

err_has() {
  grep -qF -- "$1" <<<"$err"
}

err_lacks() {
  ! grep -qF -- "$1" <<<"$err"
}

err_matches_i() {
  grep -qiE -- "$1" <<<"$err"
}

first_err_line_has() {
  head -n 1 <<<"$err" | grep -qF -- "$1"
}

# Nombre de lignes de stderr qui contiennent le fragment
err_count() {
  grep -cF -- "$1" <<<"$err"
}

at_most() {
  [ "$1" -le "$2" ]
}

# stdout est un JSON dont systemMessage est un texte non vide
out_has_system_message() {
  jq -e '.systemMessage | type == "string" and length > 0' <<<"$out" >/dev/null 2>&1
}

# systemMessage contient le fragment
system_message_has() {
  jq -e --arg f "$1" '.systemMessage | contains($f)' <<<"$out" >/dev/null 2>&1
}

# systemMessage correspond à l'expression (insensible à la casse)
system_message_matches_i() {
  jq -r '.systemMessage // empty' <<<"$out" 2>/dev/null | grep -qiE -- "$1"
}

# État de l'arbre de travail, fichiers ignorés et non suivis détaillés compris
tree_status() {
  git -C "$1" status --porcelain --ignored --untracked-files=all
}

# Aucun fichier de ce nom sous le dossier de travail
no_file_named() {
  [ -z "$(find "$work" -name "$1" -print)" ]
}

# Dossier bin contenant des liens vers toutes les commandes du PATH réel, sauf une
make_bin_without() {
  local excluded=$1 bin dir file name
  local -a dirs
  bin=$(mktemp -d "$work/bin.XXXXXX")
  IFS=: read -ra dirs <<<"$PATH"
  for dir in "${dirs[@]}"; do
    if [ -z "$dir" ] || [ ! -d "$dir" ]; then
      continue
    fi
    for file in "$dir"/*; do
      name=${file##*/}
      if [ "$name" = "$excluded" ] || [ -d "$file" ] || [ ! -x "$file" ]; then
        continue
      fi
      # Le premier dossier du PATH l'emporte, comme pour le shell
      if [ -e "$bin/$name" ] || [ -L "$bin/$name" ]; then
        continue
      fi
      ln -s "$file" "$bin/$name"
    done
  done
  echo "$bin"
}

command_absent_from() {
  ! (PATH="$1" && command -v "$2" >/dev/null 2>&1)
}

# --- CA1 : pas de configuration ---------------------------------------------

p=$(new_project)
run_lint "$p" s-ca1 "$p/src/a.ts"
check_code 0 "Spec 006 CA1 : sans .claude/quality.json, lint.sh sort avec le code 0"

# --- CA2 : lint qui réussit -----------------------------------------------

p=$(new_project)
tools=$(new_tools)
make_lint "$tools" 0
write_config "$p" "$tools/lint --strict" ""
run_lint "$p" s-ca2 "$p/src/a.ts"
check_code 0 "Spec 006 CA2 : lint qui réussit, code 0"
check "Spec 006 CA2 : le lint est lancé une fois" equal 1 "$(count_lines "$tools/lint-calls")"
check "Spec 006 CA2 : dernier argument = chemin absolu de src/a.ts" \
  equal "$p/src/a.ts" "$(tail -n 1 "$tools/lint-args" 2>/dev/null)"
check "Spec 006 CA2 : les arguments configurés précèdent le chemin" \
  equal "--strict" "$(head -n 1 "$tools/lint-args" 2>/dev/null)"
check "Spec 006 CA2 : exactement deux arguments (option configurée, fichier)" \
  equal 2 "$(count_lines "$tools/lint-args")"

# --- CA3 : lint qui échoue --------------------------------------------------

p=$(new_project)
tools=$(new_tools)
make_lint "$tools" 1 1
write_config "$p" "$tools/lint" ""
run_lint "$p" s-ca3 "$p/src/a.ts"
check_code 2 "Spec 006 CA3 : lint en échec, code 2"
check "Spec 006 CA3 : stderr cite le fichier" err_has "src/a.ts"
check "Spec 006 CA3 : stderr contient la sortie du lint" err_has "lint-ligne-001"

# Renfort (agent principal) : la sortie d'erreur du lint est transmise aussi
p=$(new_project)
tools=$(new_tools)
cat >"$tools/lint" <<'EOF'
#!/usr/bin/env bash
echo "lint-erreur-stderr" >&2
exit 1
EOF
chmod +x "$tools/lint"
write_config "$p" "$tools/lint" ""
run_lint "$p" s-ca3b "$p/src/a.ts"
check_code 2 "Spec 006 CA3 : lint en échec sur stderr, code 2"
check "Spec 006 CA3 : la sortie d'erreur du lint est transmise" err_has "lint-erreur-stderr"

# --- CA4 : sortie de lint de plus de 50 lignes ------------------------------

p=$(new_project)
tools=$(new_tools)
make_lint "$tools" 1 120
write_config "$p" "$tools/lint" ""
run_lint "$p" s-ca4 "$p/src/a.ts"
check_code 2 "Spec 006 CA4 : lint en échec avec 120 lignes, code 2"
check "Spec 006 CA4 : dernière ligne du lint présente" err_has "lint-ligne-120"
check "Spec 006 CA4 : 50e ligne avant la fin présente" err_has "lint-ligne-071"
check "Spec 006 CA4 : 51e ligne avant la fin absente (garde)" err_lacks "lint-ligne-070"
check "Spec 006 CA4 : première ligne du lint absente (garde)" err_lacks "lint-ligne-001"
check "Spec 006 CA4 : au plus 50 lignes de sortie du lint sur stderr (garde)" \
  at_most "$(err_count "lint-ligne-")" 50

# --- CA5 : entrée sans file_path, fichier hors du projet --------------------

p=$(new_project)
tools=$(new_tools)
make_lint "$tools" 1
write_config "$p" "$tools/lint" ""
run_hook "$lint_hook" "$p" '{"session_id":"s-ca5","hook_event_name":"PostToolUse","tool_name":"Edit","tool_input":{}}'
check_code 0 "Spec 006 CA5 : entrée sans file_path, code 0"
# Garde : vérification négative, vraie aussi sans hook
check "Spec 006 CA5 : entrée sans file_path, lint non lancé (garde)" \
  equal 0 "$(count_lines "$tools/lint-calls")"

mkdir "$work/ailleurs"
printf 'x\n' >"$work/ailleurs/b.ts"
run_lint "$p" s-ca5 "$work/ailleurs/b.ts"
check_code 0 "Spec 006 CA5 : fichier hors du projet, code 0"
check "Spec 006 CA5 : fichier hors du projet, lint non lancé (garde)" \
  equal 0 "$(count_lines "$tools/lint-calls")"

# Dossier voisin dont le nom commence par celui du projet
mkdir "$p-voisin"
printf 'x\n' >"$p-voisin/c.ts"
run_lint "$p" s-ca5 "$p-voisin/c.ts"
check_code 0 "Spec 006 CA5 : dossier voisin au nom préfixé par le projet, code 0"
check "Spec 006 CA5 : dossier voisin au nom préfixé, lint non lancé (garde)" \
  equal 0 "$(count_lines "$tools/lint-calls")"

# --- CA5 bis : noms de fichiers hostiles ------------------------------------

# Guillemets simples voulus : les noms contiennent des métacaractères tels quels
# shellcheck disable=SC2016
for name in '-x.ts' 'a;touch pwned.ts' '$(touch pwned).ts' 'a b.ts'; do
  p=$(new_project)
  tools=$(new_tools)
  make_lint "$tools" 0
  write_config "$p" "$tools/lint" ""
  printf 'x\n' >"$p/src/$name"
  run_lint "$p" s-ca5bis "$p/src/$name"
  check_code 0 "Spec 006 CA5 bis : « $name », code 0"
  check "Spec 006 CA5 bis : « $name » reçu comme un seul argument" \
    equal 1 "$(count_lines "$tools/lint-args")"
  check "Spec 006 CA5 bis : « $name » reçu tel quel, en chemin absolu" \
    equal "$p/src/$name" "$(cat "$tools/lint-args" 2>/dev/null)"
  # Garde : vérification négative, vraie aussi sans hook
  check "Spec 006 CA5 bis : « $name », aucune commande injectée (pas de fichier pwned) (garde)" \
    no_file_named pwned
  check "Spec 006 CA5 bis : « $name », aucune commande injectée (pas de fichier pwned.ts) (garde)" \
    no_file_named pwned.ts
done

# --- CA6 : formatage puis lint ------------------------------------------------

# Faux Prettier, utilisé par format.sh : réécrit le fichier reçu en dernier argument
make_prettier() {
  mkdir -p "$1/node_modules/.bin"
  cat >"$1/node_modules/.bin/prettier" <<'EOF'
#!/usr/bin/env bash
for last; do :; done
printf 'FORMATE\n' >"$last"
EOF
  chmod +x "$1/node_modules/.bin/prettier"
}

# Faux lint qui échoue si le fichier n'a pas été formaté
make_format_checking_lint() {
  cat >"$1/lint" <<EOF
#!/usr/bin/env bash
echo run >>"$1/lint-calls"
for last; do :; done
if grep -qx FORMATE "\$last"; then exit 0; fi
echo "NON-FORMATE : \$last"
exit 1
EOF
  chmod +x "$1/lint"
}

p=$(new_project)
tools=$(new_tools)
make_prettier "$p"
make_format_checking_lint "$tools"
write_config "$p" "$tools/lint" ""
printf 'const   a=1\n' >"$p/src/a.ts"
run_lint "$p" s-ca6 "$p/src/a.ts"
check_code 0 "Spec 006 CA6 : le lint reçoit le fichier déjà formaté, code 0"
check "Spec 006 CA6 : le lint est lancé" equal 1 "$(count_lines "$tools/lint-calls")"
check "Spec 006 CA6 : le fichier a été formaté" grep -qx FORMATE "$p/src/a.ts"

# Témoin : sans Prettier, le même faux lint détecte le fichier non formaté
p=$(new_project)
tools=$(new_tools)
make_format_checking_lint "$tools"
write_config "$p" "$tools/lint" ""
printf 'const   a=1\n' >"$p/src/a.ts"
run_lint "$p" s-ca6 "$p/src/a.ts"
check_code 2 "Spec 006 CA6 : témoin sans Prettier, le faux lint échoue (code 2)"

# Renfort (agent principal) : lint.sh porte le formatage, qui n'est plus branché
# à part (hooks parallèles) ; il doit donc formater même sans configuration
p=$(new_project)
make_prettier "$p"
printf 'const   a=1\n' >"$p/src/a.ts"
run_lint "$p" s-ca6b "$p/src/a.ts"
check_code 0 "Spec 006 CA6 : sans .claude/quality.json, code 0"
check "Spec 006 CA6 : sans .claude/quality.json, le fichier est quand même formaté" \
  grep -qx FORMATE "$p/src/a.ts"

# --- CA7 : configuration invalide, jq absent --------------------------------

p=$(new_project)
mkdir -p "$p/.claude"
printf '{ "lint": pas du json\n' >"$p/.claude/quality.json"
run_lint "$p" s-ca7 "$p/src/a.ts"
check_code 1 "Spec 006 CA7 : quality.json invalide, code 1"
check "Spec 006 CA7 : quality.json invalide, première ligne de stderr cite quality.json" \
  first_err_line_has "quality.json"

p=$(new_project)
tools=$(new_tools)
make_lint "$tools" 0
write_config "$p" "$tools/lint" ""
bin=$(make_bin_without jq)
check "Spec 006 CA7 : précondition, jq absent du PATH de test" command_absent_from "$bin" jq
run_hook "$lint_hook" "$p" "$(edit_input s-ca7 "$p/src/a.ts")" "$bin"
check_code 1 "Spec 006 CA7 : jq absent, code 1"
check "Spec 006 CA7 : jq absent, première ligne de stderr cite jq" first_err_line_has "jq"

# --- CA8 : commande introuvable, commande qui sort en 127 -------------------

p=$(new_project)
write_config "$p" "commande-introuvable-ca8 --fix" ""
run_lint "$p" s-ca8 "$p/src/a.ts"
check_code 0 "Spec 006 CA8 : premier mot introuvable, code 0"
check "Spec 006 CA8 : systemMessage JSON sur stdout" out_has_system_message
check "Spec 006 CA8 : systemMessage cite la commande introuvable" \
  system_message_has "commande-introuvable-ca8"

p=$(new_project)
write_config "$p" "$work/inexistant/lint" ""
run_lint "$p" s-ca8 "$p/src/a.ts"
check_code 0 "Spec 006 CA8 : chemin de commande inexistant, code 0"
check "Spec 006 CA8 : chemin inexistant, systemMessage cite la commande" \
  system_message_has "$work/inexistant/lint"

p=$(new_project)
tools=$(new_tools)
make_lint "$tools" 127
write_config "$p" "$tools/lint" ""
run_lint "$p" s-ca8 "$p/src/a.ts"
check_code 2 "Spec 006 CA8 : commande trouvée qui sort en 127, code 2"
check "Spec 006 CA8 : commande trouvée qui sort en 127, lint bien lancé" \
  equal 1 "$(count_lines "$tools/lint-calls")"

# --- CA9 : tour sans modification -------------------------------------------

p=$(new_project)
tools=$(new_tools)
make_test_tool "$tools"
write_config "$p" "" "$tools/tests"
run_stop "$p" s-ca9 false
check_code 0 "Spec 006 CA9 : arrêt sans modification, code 0"
# Garde : vérification négative, vraie aussi sans hook
check "Spec 006 CA9 : arrêt sans modification, tests non lancés (garde)" \
  equal 0 "$(count_lines "$tools/test-calls")"

# --- CA10 : modification, tests au vert -------------------------------------

p=$(new_project)
tools=$(new_tools)
make_test_tool "$tools"
# Lint non configuré : la modification marque quand même les tests
write_config "$p" "" "$tools/tests"
run_lint "$p" s-ca10 "$p/src/a.ts"
check_code 0 "Spec 006 CA10 : modification sans lint configuré, code 0"
run_stop "$p" s-ca10 false
check_code 0 "Spec 006 CA10 : tests au vert, code 0"
check "Spec 006 CA10 : tests lancés une fois" equal 1 "$(count_lines "$tools/test-calls")"
check "Spec 006 CA10 : tests lancés depuis la racine du projet" \
  equal "$p" "$(cat "$tools/test-cwd" 2>/dev/null)"
check "Spec 006 CA10 : tests lancés sans argument" \
  equal 0 "$(cat "$tools/test-argc" 2>/dev/null)"
run_stop "$p" s-ca10 false
check_code 0 "Spec 006 CA10 : arrêt suivant sans modification, code 0"
check "Spec 006 CA10 : arrêt suivant sans modification, tests non relancés" \
  equal 1 "$(count_lines "$tools/test-calls")"

# Renfort (agent principal) : un fichier hors du projet ne marque pas les tests,
# mais un fichier du projet, dans la même session, les marque (témoin)
p=$(new_project)
tools=$(new_tools)
make_test_tool "$tools"
write_config "$p" "" "$tools/tests"
printf 'x\n' >"$work/hors-projet.ts"
run_lint "$p" s-hors "$work/hors-projet.ts"
run_stop "$p" s-hors false
check "Spec 006 : fichier hors du projet, tests non lancés" \
  equal 0 "$(count_lines "$tools/test-calls")"
run_lint "$p" s-hors "$p/src/a.ts"
run_stop "$p" s-hors false
check "Spec 006 : témoin, fichier du projet, tests lancés" \
  equal 1 "$(count_lines "$tools/test-calls")"

# --- CA11 : tests en échec, premier arrêt -----------------------------------

p=$(new_project)
tools=$(new_tools)
make_test_tool "$tools"
echo 1 >"$tools/test-exit"
write_config "$p" "" "$tools/tests"
run_lint "$p" s-ca11 "$p/src/a.ts"
run_stop "$p" s-ca11 false
check_code 2 "Spec 006 CA11 : tests en échec, stop_hook_active faux, code 2"
check "Spec 006 CA11 : stderr contient la sortie des tests" err_has "test-ligne-120"
check "Spec 006 CA11 : stderr contient la consigne sur les tests rouges attendus" \
  err_matches_i "test-first|rouge"
check "Spec 006 CA11 : sortie des tests limitée à la fin (première ligne absente) (garde)" \
  err_lacks "test-ligne-001"
check "Spec 006 CA11 : au plus 50 lignes de sortie des tests sur stderr (garde)" \
  at_most "$(err_count "test-ligne-")" 50

# --- CA12 : tests en échec, arrêt déjà relancé ------------------------------

p=$(new_project)
tools=$(new_tools)
make_test_tool "$tools"
echo 1 >"$tools/test-exit"
write_config "$p" "" "$tools/tests"
run_lint "$p" s-ca12 "$p/src/a.ts"
run_stop "$p" s-ca12 true
check_code 0 "Spec 006 CA12 : tests en échec, stop_hook_active vrai, code 0"
check "Spec 006 CA12 : systemMessage JSON sur stdout" out_has_system_message
check "Spec 006 CA12 : systemMessage signale l'échec des tests" \
  system_message_matches_i "échec|Échec|échou|fail"
calls_before=$(count_lines "$tools/test-calls")
run_stop "$p" s-ca12 false
check "Spec 006 CA12 : l'arrêt suivant relance les tests (marque conservée)" \
  equal $((calls_before + 1)) "$(count_lines "$tools/test-calls")"

# --- CA12 bis : deux sessions dans le même worktree -------------------------

p=$(new_project)
tools=$(new_tools)
make_test_tool "$tools"
write_config "$p" "" "$tools/tests"
status_before=$(tree_status "$p")
run_lint "$p" s-ca12bis-a "$p/src/a.ts"
check_code 0 "Spec 006 CA12 bis : modification par la session A, code 0"
check "Spec 006 CA12 bis : aucune marque dans l'arbre de travail (git status inchangé) (garde)" \
  equal "$status_before" "$(tree_status "$p")"
run_stop "$p" s-ca12bis-b false
check_code 0 "Spec 006 CA12 bis : arrêt de la session B, code 0"
check "Spec 006 CA12 bis : arrêt de la session B, tests non lancés (garde)" \
  equal 0 "$(count_lines "$tools/test-calls")"
# La marque de la session A existe bien : son arrêt lance les tests
run_stop "$p" s-ca12bis-a false
check "Spec 006 CA12 bis : arrêt de la session A, tests lancés" \
  equal 1 "$(count_lines "$tools/test-calls")"
check "Spec 006 CA12 bis : git status inchangé après les arrêts (garde)" \
  equal "$status_before" "$(tree_status "$p")"

# Marque propre au worktree : même session, autre worktree du même dépôt
p=$(new_project)
git -C "$p" -c user.name=test -c user.email=test@example.invalid \
  commit -q --allow-empty -m init
git -C "$p" worktree add -q -b autre "$p-worktree" 2>/dev/null
check "Spec 006 CA12 bis : précondition, second worktree créé" test -e "$p-worktree/.git"
tools=$(new_tools)
make_test_tool "$tools"
write_config "$p" "" "$tools/tests"
write_config "$p-worktree" "" "$tools/tests"
wt_status_before=$(tree_status "$p-worktree")
run_lint "$p" s-ca12bis-wt "$p/src/a.ts"
run_stop "$p-worktree" s-ca12bis-wt false
check_code 0 "Spec 006 CA12 bis : même session, autre worktree, code 0"
check "Spec 006 CA12 bis : même session, autre worktree, tests non lancés (garde)" \
  equal 0 "$(count_lines "$tools/test-calls")"
run_stop "$p" s-ca12bis-wt false
check "Spec 006 CA12 bis : même session, worktree modifié, tests lancés" \
  equal 1 "$(count_lines "$tools/test-calls")"
check "Spec 006 CA12 bis : git status de l'autre worktree inchangé (garde)" \
  equal "$wt_status_before" "$(tree_status "$p-worktree")"

# --- CA13 : pas de commande de tests ----------------------------------------

p=$(new_project)
run_lint "$p" s-ca13 "$p/src/a.ts"
run_stop "$p" s-ca13 false
check_code 0 "Spec 006 CA13 : sans quality.json, arrêt après modification, code 0"

p=$(new_project)
write_config "$p" "" ""
run_lint "$p" s-ca13 "$p/src/a.ts"
run_stop "$p" s-ca13 false
check_code 0 "Spec 006 CA13 : clé test vide, arrêt après modification, code 0"

p=$(new_project)
mkdir -p "$p/.claude"
printf '{"lint": ""}\n' >"$p/.claude/quality.json"
run_lint "$p" s-ca13 "$p/src/a.ts"
run_stop "$p" s-ca13 false
check_code 0 "Spec 006 CA13 : clé test absente, arrêt après modification, code 0"

# --- Cas limites ------------------------------------------------------------

# Phase test-first : le hook bloque une fois, puis laisse l'agent s'arrêter
p=$(new_project)
tools=$(new_tools)
make_test_tool "$tools"
echo 1 >"$tools/test-exit"
write_config "$p" "" "$tools/tests"
run_lint "$p" s-tf "$p/src/a.ts"
run_stop "$p" s-tf false
check_code 2 "Spec 006 cas limite test-first : premier arrêt bloqué (code 2)"
run_stop "$p" s-tf true
check_code 0 "Spec 006 cas limite test-first : second arrêt non bloqué (code 0)"

# Modification par un subagent : même session_id, outil Write
p=$(new_project)
tools=$(new_tools)
make_test_tool "$tools"
write_config "$p" "" "$tools/tests"
run_lint "$p" s-subagent "$p/src/nouveau.test.ts" Write
check_code 0 "Spec 006 cas limite subagent : Write d'un fichier de test, code 0"
run_stop "$p" s-subagent false
check "Spec 006 cas limite subagent : tests lancés à l'arrêt de l'agent principal" \
  equal 1 "$(count_lines "$tools/test-calls")"

# Fichier que le linter ne sait pas traiter : transmis tel quel à la commande
p=$(new_project)
tools=$(new_tools)
make_lint "$tools" 0
write_config "$p" "$tools/lint" ""
printf '# Titre\n' >"$p/README.md"
run_lint "$p" s-md "$p/README.md"
check_code 0 "Spec 006 cas limite Markdown : code 0"
check "Spec 006 cas limite Markdown : fichier transmis à la commande configurée" \
  equal "$p/README.md" "$(tail -n 1 "$tools/lint-args" 2>/dev/null)"

# Modification d'un fichier de journal : les tests sont quand même marqués
p=$(new_project)
tools=$(new_tools)
make_test_tool "$tools"
write_config "$p" "" "$tools/tests"
mkdir -p "$p/docs/journal"
printf '# Journal\n' >"$p/docs/journal/2026-10-12-x.md"
run_lint "$p" s-journal "$p/docs/journal/2026-10-12-x.md"
run_stop "$p" s-journal false
check "Spec 006 cas limite journal : tests lancés après modification du journal" \
  equal 1 "$(count_lines "$tools/test-calls")"

# --- Revue de sécurité (security-reviewer, étape 7 de /implement) -----------
# Tests de non-régression ajoutés par l'agent principal, rouges avant correction.

# Le formatage reçoit le chemin vérifié, pas le chemin brut : un lien symbolique
# qui pointe hors du projet n'est ni formaté ni linté
p=$(new_project)
tools=$(new_tools)
make_prettier "$p"
make_lint "$tools" 0
write_config "$p" "$tools/lint" ""
printf 'dehors\n' >"$work/cible-externe.ts"
ln -s "$work/cible-externe.ts" "$p/src/lien.ts"
run_lint "$p" s-lien "$p/src/lien.ts"
check_code 0 "Sécurité : lien symbolique vers l'extérieur, code 0"
check "Sécurité : lien symbolique vers l'extérieur, fichier externe non formaté" \
  grep -qx dehors "$work/cible-externe.ts"
check "Sécurité : lien symbolique vers l'extérieur, lint non lancé" \
  equal 0 "$(count_lines "$tools/lint-calls")"

# La sortie du lint et des tests est délimitée comme des données, pas des consignes
p=$(new_project)
tools=$(new_tools)
make_lint "$tools" 1 3
write_config "$p" "$tools/lint" ""
run_lint "$p" s-delim "$p/src/a.ts"
check_code 2 "Sécurité : lint en échec, code 2"
check "Sécurité : sortie du lint délimitée comme des données" err_matches_i "données, pas (comme )?des consignes"
check "Sécurité : fin de la sortie du lint marquée" err_matches_i "fin de la sortie"

p=$(new_project)
tools=$(new_tools)
make_test_tool "$tools"
echo 1 >"$tools/test-exit"
write_config "$p" "" "$tools/tests"
run_lint "$p" s-delim-t "$p/src/a.ts"
run_stop "$p" s-delim-t false
check_code 2 "Sécurité : tests en échec, code 2"
check "Sécurité : sortie des tests délimitée comme des données" err_matches_i "données, pas (comme )?des consignes"

# Marque impossible (projet sans Git) alors que des tests sont déclarés :
# l'humain est prévenu que les tests ne seront pas lancés
p=$(mktemp -d "$work/sans-git.XXXXXX")
mkdir "$p/src"
printf 'x\n' >"$p/src/a.ts"
tools=$(new_tools)
make_test_tool "$tools"
write_config "$p" "" "$tools/tests"
run_lint "$p" s-sans-git "$p/src/a.ts"
check_code 0 "Sécurité : projet sans Git, code 0"
check "Sécurité : projet sans Git, systemMessage qui prévient l'humain" out_has_system_message
check "Sécurité : projet sans Git, le message parle des tests" system_message_matches_i "test"

# session_id très long : la marque fonctionne quand même
long_session=$(printf 's%.0s' $(seq 1 400))
p=$(new_project)
tools=$(new_tools)
make_test_tool "$tools"
write_config "$p" "" "$tools/tests"
run_lint "$p" "$long_session" "$p/src/a.ts"
run_stop "$p" "$long_session" false
check "Sécurité : session_id de 400 caractères, tests lancés" \
  equal 1 "$(count_lines "$tools/test-calls")"

exit $fail
