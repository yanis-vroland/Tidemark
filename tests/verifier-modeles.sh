#!/usr/bin/env bash
# Vérifie .github/scripts/verifier-modeles.sh selon la spec
# docs/specs/007-modele-par-agent.md (CA1 à CA9 et CA11), sur des projets factices.
#
# Interface testée :
#   verifier-modeles.sh                      vérifie tous les .claude/agents/*.md
#                                            du répertoire courant ;
#   verifier-modeles.sh <fichier.md>...      vérifie seulement les fichiers donnés ;
#   verifier-modeles.sh --afficher <fichier> vérifie un fichier et, s'il est valide,
#                                            écrit le modèle seul sur stdout.
# Liste autorisée : sonnet, opus, haiku (alias nus). Erreurs sur stderr, code non nul.
# L'en-tête est le bloc entre la ligne 1 « --- » et la ligne « --- » suivante.
#
# Un échec attendu est un code entre 1 et 125 : 126 et 127 (script non exécutable
# ou absent) ne comptent pas comme un refus.
set -u

template="$(cd "$(dirname "$0")/.." && pwd -P)"
script="$template/.github/scripts/verifier-modeles.sh"
fail=0

if [ ! -f "$script" ]; then
  echo "ÉCHEC  $script est absent : toutes les vérifications vont échouer"
  fail=1
fi

# Chemin canonique : sous macOS, /var est un lien vers /private/var
# Un échec de mktemp arrête le test : sinon « cd "" » laisserait $work sur le
# dossier courant, que le trap effacerait.
if ! work=$(mktemp -d) || ! work=$(cd "$work" && pwd -P); then
  echo "Erreur : mktemp -d a échoué" >&2
  exit 1
fi
trap 'rm -rf "$work"' EXIT

# --- Outils de vérification -------------------------------------------------

out=""
err=""
code=0

pass() {
  echo "OK     $1"
}

failed() {
  echo "ÉCHEC  $1${2:+ ($2)}"
  fail=1
}

# run <répertoire> <arguments...> : lance le script depuis ce répertoire,
# stdout dans $out, stderr dans $err, code dans $code
run() {
  local dir=$1
  shift
  out=$(cd "$dir" && "$script" "$@" 2>"$work/stderr")
  code=$?
  err=$(cat "$work/stderr")
}

# check_ok <description> : le dernier lancement a réussi
check_ok() {
  if [ "$code" -eq 0 ]; then
    pass "$1"
  else
    failed "$1" "attendu 0, obtenu $code : $(head -n 1 <<<"$err")"
  fi
}

# check_refused <description> : le dernier lancement a échoué de façon contrôlée
check_refused() {
  if [ "$code" -ge 1 ] && [ "$code" -le 125 ]; then
    pass "$1"
  else
    failed "$1" "attendu un refus (1 à 125), obtenu $code : $(head -n 1 <<<"$err")"
  fi
}

# check_err <description> <fragment> : le fragment apparaît sur stderr
check_err() {
  if grep -qF -- "$2" <<<"$err"; then
    pass "$1"
  else
    failed "$1" "fragment « $2 » absent de stderr : $(head -n 3 <<<"$err")"
  fi
}

# check_list <libellé> : stderr cite la liste autorisée
check_list() {
  local model
  for model in sonnet opus haiku; do
    check_err "$1 : stderr cite « $model » de la liste autorisée" "$model"
  done
}

# check_out <description> <valeur> : stdout vaut exactement la valeur
check_out() {
  # La substitution retire le saut de ligne final ; un \r ou une seconde ligne
  # restent et font échouer la comparaison
  if [ "$out" = "$2" ]; then
    pass "$1"
  else
    failed "$1" "stdout attendu « $2 », obtenu « $out »"
  fi
}

# check_out_empty <description> : rien sur stdout
check_out_empty() {
  if [ -z "$out" ]; then
    pass "$1"
  else
    failed "$1" "stdout non vide : « $out »"
  fi
}

# --- Projets factices -------------------------------------------------------

# new_project : crée un projet avec un dossier .claude/agents vide, écrit son chemin.
# Appelée dans $(...) : mktemp garantit un dossier neuf à chaque appel.
new_project() {
  local dir
  dir=$(mktemp -d "$work/projet.XXXXXX")
  mkdir -p "$dir/.claude/agents"
  echo "$dir"
}

# agent <projet> <nom> <ligne model ou vide> : subagent avec en-tête complet.
# Une ligne vide en troisième argument : pas de ligne model.
agent() {
  local dir=$1 name=$2 model_line=$3
  {
    printf -- '---\n'
    printf 'name: %s\n' "$name"
    printf 'description: Subagent factice.\n'
    [ -n "$model_line" ] && printf '%s\n' "$model_line"
    printf 'tools: Read, Grep\n'
    printf -- '---\n'
    printf '\nConsignes du subagent.\n'
  } >"$dir/.claude/agents/$name.md"
}

# --- CA1 : modèles autorisés ------------------------------------------------

p=$(new_project)
agent "$p" alpha "model: sonnet"
agent "$p" beta "model: opus"
agent "$p" gamma "model: haiku"
run "$p"
check_ok "CA1 : sonnet, opus et haiku déclarés : code 0"
run "$p" .claude/agents/alpha.md .claude/agents/beta.md .claude/agents/gamma.md
check_ok "CA1 : mêmes fichiers passés en arguments : code 0"

# --- CA2 : ligne model absente ----------------------------------------------

p=$(new_project)
agent "$p" valide "model: opus"
agent "$p" sans-modele ""
run "$p"
check_refused "CA2 : subagent sans ligne model : refus"
check_err "CA2 : stderr nomme le fichier" "sans-modele.md"
# Message propre à la ligne absente : sans lui, le refus viendrait seulement de la
# valeur vide, et l'humain lirait « modèle « » refusé » (mutation CA14)
check_err "CA2 : stderr dit que la ligne model: manque" "aucune ligne « model: »"
check_list "CA2"
run "$p" .claude/agents/sans-modele.md
check_refused "CA2 : fichier sans ligne model passé en argument : refus"
check_err "CA2 : fichier en argument, stderr nomme le fichier" "sans-modele.md"

# --- CA3 : valeur refusée ---------------------------------------------------

# check_value_refused <libellé> <ligne model> <valeur à retrouver sur stderr ou vide>
check_value_refused() {
  local label=$1 line=$2 value=$3 dir
  dir=$(new_project)
  agent "$dir" valide "model: sonnet"
  agent "$dir" fautif "$line"
  run "$dir"
  check_refused "CA3 : $label : refus"
  check_err "CA3 : $label : stderr nomme le fichier" "fautif.md"
  if [ -n "$value" ]; then
    check_err "CA3 : $label : stderr cite la valeur trouvée" "$value"
  fi
  check_list "CA3 : $label"
}

check_value_refused "model: inherit" "model: inherit" "inherit"
check_value_refused "model: vide" "model:" ""
check_value_refused "model: vide suivi d'espaces" "model:   " ""
check_value_refused "identifiant complet claude-opus-5-5" "model: claude-opus-5-5" "claude-opus-5-5"
# Alias documenté par Claude Code mais hors de la liste (spec, « Hors périmètre »)
check_value_refused "alias fable hors liste" "model: fable" "fable"
# Alias nu, sensible à la casse
check_value_refused "Opus avec majuscule" "model: Opus" "Opus"
# Alias nu : la valeur entre guillemets est refusée
check_value_refused "valeur entre guillemets \"opus\"" 'model: "opus"' '"opus"'
# Deux alias autorisés consécutifs : un seul mot attendu, sinon le second
# deviendrait un argument de plus après --model dans ai-review.yml
check_value_refused "deux alias « opus haiku »" "model: opus haiku" "opus haiku"
check_value_refused "alias suivi d'une option « opus --x »" "model: opus --x" "opus --x"

# --- CA4 : ligne model en double --------------------------------------------

p=$(new_project)
cat >"$p/.claude/agents/double.md" <<'EOF'
---
name: double
description: Subagent factice.
model: opus
tools: Read
model: opus
---

Consignes.
EOF
run "$p"
check_refused "CA4 : deux lignes model identiques dans l'en-tête : refus"
check_err "CA4 : doublon identique, stderr nomme le fichier" "double.md"

p=$(new_project)
cat >"$p/.claude/agents/double.md" <<'EOF'
---
name: double
description: Subagent factice.
model: sonnet
model: opus
---

Consignes.
EOF
run "$p"
check_refused "CA4 : deux lignes model différentes dans l'en-tête : refus"
check_err "CA4 : doublon différent, stderr nomme le fichier" "double.md"

# --- CA5 : seule compte la ligne de l'en-tête -------------------------------

p=$(new_project)
cat >"$p/.claude/agents/corps.md" <<'EOF'
---
name: corps
description: Subagent factice.
tools: Read
---

Consignes.

model: opus
EOF
run "$p"
check_refused "CA5 : model: opus dans le corps seulement : refus"
check_err "CA5 : stderr nomme le fichier" "corps.md"

# Un second bloc --- ... --- dans le corps n'est pas l'en-tête
p=$(new_project)
cat >"$p/.claude/agents/second-bloc.md" <<'EOF'
---
name: second-bloc
description: Subagent factice.
---

Consignes.

---
model: opus
---
EOF
run "$p"
check_refused "CA5 : model: opus dans un second bloc --- du corps : refus"
check_err "CA5 : second bloc, stderr nomme le fichier" "second-bloc.md"

# Ligne valide dans l'en-tête et autre ligne dans le corps : pas un doublon
p=$(new_project)
cat >"$p/.claude/agents/entete-et-corps.md" <<'EOF'
---
name: entete-et-corps
description: Subagent factice.
model: opus
---

Exemple à recopier :

model: inherit
EOF
run "$p"
check_ok "CA5 : model: opus dans l'en-tête et model: inherit dans le corps : code 0"

# --- CA6 : pas d'arrêt au premier fichier invalide --------------------------

p=$(new_project)
agent "$p" a-premier-invalide ""
agent "$p" b-valide "model: sonnet"
agent "$p" c-second-invalide "model: inherit"
run "$p"
check_refused "CA6 : deux subagents invalides sur trois : refus"
check_err "CA6 : stderr nomme le premier fichier invalide" "a-premier-invalide.md"
check_err "CA6 : stderr nomme le second fichier invalide" "c-second-invalide.md"
run "$p" .claude/agents/a-premier-invalide.md .claude/agents/b-valide.md \
  .claude/agents/c-second-invalide.md
check_err "CA6 : fichiers en arguments, stderr nomme le premier invalide" "a-premier-invalide.md"
check_err "CA6 : fichiers en arguments, stderr nomme le second invalide" "c-second-invalide.md"

# --- CA7 : aucun subagent ---------------------------------------------------

p=$(new_project)
run "$p"
check_ok "CA7 : dossier .claude/agents vide : code 0"
rmdir "$p/.claude/agents"
run "$p"
check_ok "CA7 : dossier .claude/agents absent : code 0"
rmdir "$p/.claude"
run "$p"
check_ok "CA7 : dossier .claude absent : code 0"

# --- CA8 : espaces de fin et CRLF -------------------------------------------

p=$(new_project)
agent "$p" espaces "model: opus  "
run "$p"
check_ok "CA8 : model: opus suivi d'espaces : code 0"
run "$p" --afficher .claude/agents/espaces.md
check_ok "CA8 : --afficher, espaces de fin : code 0"
check_out "CA8 : --afficher, espaces de fin : stdout exactement opus" "opus"

p=$(new_project)
printf -- '---\r\nname: crlf\r\ndescription: Subagent factice.\r\nmodel: sonnet\r\n---\r\n\r\nConsignes.\r\n' \
  >"$p/.claude/agents/crlf.md"
run "$p"
check_ok "CA8 : fichier en CRLF : code 0"
run "$p" --afficher .claude/agents/crlf.md
check_ok "CA8 : --afficher, CRLF : code 0"
check_out "CA8 : --afficher, CRLF : stdout exactement sonnet, sans retour chariot" "sonnet"

# --- Cas limite : fichier qui n'est pas un subagent -------------------------

p=$(new_project)
agent "$p" valide "model: haiku"
printf '# Subagents du projet\n\nmodel: opus\n' >"$p/.claude/agents/README.md"
run "$p"
check_refused "Limite : README.md sans en-tête dans .claude/agents : refus"
check_err "Limite : README.md, stderr nomme le fichier" "README.md"

# --- Cas limites : en-tête non fermé, fichier inexistant --------------------

p=$(new_project)
printf -- '---\nname: ouvert\nmodel: opus\n\nConsignes sans fin d'"'"'en-tête.\n' \
  >"$p/.claude/agents/ouvert.md"
run "$p"
check_refused "Limite : en-tête sans « --- » de fermeture : refus"
check_err "Limite : en-tête non fermé, stderr nomme le fichier" "ouvert.md"

p=$(new_project)
agent "$p" valide "model: opus"
run "$p" .claude/agents/valide.md .claude/agents/absent.md
check_refused "Limite : fichier passé en argument mais inexistant : refus"
check_err "Limite : fichier inexistant, stderr nomme le fichier" "absent.md"
run "$p" --afficher .claude/agents/absent.md
check_refused "Limite : --afficher sur un fichier inexistant : refus"
check_out_empty "Limite : --afficher sur un fichier inexistant : stdout vide"

# --- CA11 : --afficher, lecture du modèle pour ai-review.yml ----------------

p=$(new_project)
agent "$p" reviewer "model: opus"
agent "$p" autre-invalide "model: inherit"
run "$p" --afficher .claude/agents/reviewer.md
check_ok "CA11 : --afficher sur un reviewer valide : code 0"
check_out "CA11 : --afficher sur un reviewer valide : stdout exactement opus" "opus"

# check_show_refused <libellé> <ligne model ou vide>
check_show_refused() {
  local label=$1 line=$2 dir
  dir=$(new_project)
  agent "$dir" reviewer "$line"
  run "$dir" --afficher .claude/agents/reviewer.md
  check_refused "CA11 : --afficher, $label : refus"
  check_out_empty "CA11 : --afficher, $label : stdout vide"
  check_err "CA11 : --afficher, $label : stderr nomme le fichier" "reviewer.md"
}

check_show_refused "modèle absent" ""
check_show_refused "model: inherit" "model: inherit"
check_show_refused "model: vide" "model:"
check_show_refused "identifiant complet" "model: claude-opus-5-5"
check_show_refused "alias fable" "model: fable"
check_show_refused "model en double" $'model: opus\nmodel: opus'
check_show_refused "deux alias « sonnet opus »" "model: sonnet opus"

p=$(new_project)
cat >"$p/.claude/agents/reviewer.md" <<'EOF'
---
name: reviewer
description: Subagent factice.
---

model: opus
EOF
run "$p" --afficher .claude/agents/reviewer.md
check_refused "CA11 : --afficher, model dans le corps seulement : refus"
check_out_empty "CA11 : --afficher, model dans le corps seulement : stdout vide"

# --- CA9 : subagents du template --------------------------------------------

run "$template"
check_ok "CA9 : script sans argument à la racine du template : code 0"

# Tableau « Modèles des subagents du template » de la spec 007
for pair in test-writer:sonnet reviewer:opus security-reviewer:opus learning-curator:sonnet; do
  name=${pair%%:*}
  expected=${pair#*:}
  run "$template" --afficher ".claude/agents/$name.md"
  check_ok "CA9 : $name déclare un modèle valide"
  check_out "CA9 : $name déclare $expected" "$expected"
done

exit $fail
