#!/usr/bin/env bash
# Vérifie scripts/verifier-noms-exclus.sh selon sa spec (CA1 à CA14), sur des
# dépôts temporaires. Le script est lancé depuis la racine du dépôt, avec une
# plage de commits (défaut origin/main..HEAD). Codes : 0 rien trouvé, 1 nom
# trouvé ou liste vide en CI, 2 usage invalide.
# Seuls des noms fictifs sont utilisés : Acmecorp, Globex, Initech.
set -u

template="$(cd "$(dirname "$0")/.." && pwd -P)"
script="$template/scripts/verifier-noms-exclus.sh"
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

# Isole les tests de la configuration Git et de l'environnement de l'appelant
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE CI EXCLUDED_NAMES
unset GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL
cat >"$work/gitconfig" <<'CONF'
[user]
	name = Test
	email = test@example.com
[init]
	defaultBranch = main
[commit]
	gpgsign = false
CONF
export GIT_CONFIG_GLOBAL="$work/gitconfig"
export GIT_CONFIG_NOSYSTEM=1

# --- Outils de vérification -------------------------------------------------

output=""
code=0

pass() {
  echo "OK     $1"
}

failed() {
  echo "ÉCHEC  $1${2:+ ($2)}"
  fail=1
}

# Lance le script depuis la racine du dépôt, sans variable particulière
run_script() {
  local repo=$1
  shift
  output=$(cd "$repo" && "$script" "$@" 2>&1)
  code=$?
}

# run_env <dépôt> [NOM=valeur]... -- [arguments du script]
run_env() {
  local repo=$1
  shift
  local -a envs=()
  while [ $# -gt 0 ] && [ "$1" != "--" ]; do
    envs+=("$1")
    shift
  done
  [ $# -gt 0 ] && shift
  output=$(cd "$repo" && env ${envs[@]+"${envs[@]}"} "$script" "$@" 2>&1)
  code=$?
}

# verify <code attendu> <description> <fragment ou vide> : vérifie le dernier lancement
verify() {
  local expected=$1 description=$2 fragment=$3
  if [ "$code" -ne "$expected" ]; then
    failed "$description" "attendu $expected, obtenu $code : $(head -n 1 <<<"$output")"
  elif [ -n "$fragment" ] && ! grep -qiF -- "$fragment" <<<"$output"; then
    failed "$description" "fragment « $fragment » absent de la sortie : $(head -n 1 <<<"$output")"
  else
    pass "$description"
  fi
}

# verify_hidden <description> : CA9, échec (code 1) sans divulguer aucun nom
verify_hidden() {
  local description="CA9 : $1, aucun nom divulgué" name
  if [ "$code" -ne 1 ]; then
    failed "$description" "attendu 1, obtenu $code : $(head -n 1 <<<"$output")"
    return
  fi
  for name in Acmecorp Globex Initech; do
    if grep -qiF -- "$name" <<<"$output"; then
      failed "$description" "le nom $name apparaît dans la sortie"
      return
    fi
  done
  pass "$description"
}

# write_file <dépôt> <chemin> <contenu>
write_file() {
  mkdir -p "$(dirname "$1/$2")"
  printf '%s\n' "$3" >"$1/$2"
}

commit_all() {
  git -C "$1" add -A
  git -C "$1" commit -q -m "$2"
}

# Nouveau dépôt : main avec un README neutre ; affiche son chemin
new_repo() {
  local r
  r=$(mktemp -d "$work/repo.XXXXXX")
  git init -q -b main "$r"
  write_file "$r" README.md "Projet de test"
  commit_all "$r" "chore: initialisation"
  echo "$r"
}

# Dépôt dont main contient un fichier suivi (message de commit neutre) : la
# plage main..HEAD est vide, seule la recherche dans les fichiers est exercée.
# repo_with_file <chemin> <contenu>
repo_with_file() {
  local r
  r=$(new_repo)
  write_file "$r" "$1" "$2"
  commit_all "$r" "docs: ajout de notes"
  echo "$r"
}

# file_case <code attendu> <description> <fragment> <liste> <chemin> <contenu>
# Fichier suivi sur main, plage main..HEAD vide
file_case() {
  local expected=$1 description=$2 fragment=$3 list=$4 path=$5 content=$6 r
  r=$(repo_with_file "$path" "$content")
  run_env "$r" "EXCLUDED_NAMES=$list" -- main..HEAD
  verify "$expected" "$description" "$fragment"
  if [ "$expected" -eq 1 ]; then
    verify_hidden "$description"
  fi
}

# Crée la branche feat/pr avec un commit vide ; le SHA se lit ensuite avec
# git rev-parse HEAD.
# branch_commit <dépôt> <message> [NOM=valeur]... (variables Git d'auteur)
branch_commit() {
  local r=$1 message=$2
  shift 2
  git -C "$r" checkout -q -b feat/pr
  env ${1+"$@"} git -C "$r" commit -q --allow-empty -m "$message"
}

# --- CA1 : liste dans EXCLUDED_NAMES -----------------------------------------

file_case 1 "CA1 : « Acmecorp , Globex » détecte Globex (espaces ignorés)" "docs/notes.md" \
  "Acmecorp , Globex" docs/notes.md "Réunion avec Globex demain"
file_case 1 "CA1 : entrée vide ignorée, Globex détecté dans « Acmecorp,,Globex »" "docs/notes.md" \
  "Acmecorp,,Globex" docs/notes.md "Réunion avec Globex demain"
file_case 1 "CA1 : espaces autour d'un nom ignorés (« Acmecorp » détecté)" "docs/notes.md" \
  "   Acmecorp   " docs/notes.md "Réunion avec Acmecorp demain"

# Une entrée vide ne doit pas matcher tout le contenu
r=$(repo_with_file docs/notes.md "Un contenu parfaitement neutre")
run_env "$r" "EXCLUDED_NAMES=Acmecorp,,Globex, ," -- main..HEAD
verify 0 "CA1 : les entrées vides n'équivalent pas à un motif vide" ""

# --- CA2 : repli sur .excluded-names, priorité à EXCLUDED_NAMES --------------

r=$(repo_with_file docs/notes.md "Réunion avec Acmecorp demain")
printf 'Acmecorp\n' >"$r/.excluded-names"
run_script "$r" main..HEAD
verify 1 "CA2 : variable absente, nom du fichier .excluded-names détecté" "docs/notes.md"

r=$(repo_with_file docs/notes.md "Réunion avec Acmecorp demain")
printf 'Acmecorp\n' >"$r/.excluded-names"
run_env "$r" "EXCLUDED_NAMES=" -- main..HEAD
verify 1 "CA2 : variable vide, nom du fichier .excluded-names détecté" "docs/notes.md"

r=$(repo_with_file docs/notes.md "Réunion avec Globex demain")
printf 'Initech\n\nGlobex\n\n' >"$r/.excluded-names"
run_script "$r" main..HEAD
verify 1 "CA2 : un nom par ligne, lignes vides ignorées (Globex détecté)" "docs/notes.md"

r=$(repo_with_file docs/notes.md "Réunion avec Globex demain")
printf 'Initech, Globex\n' >"$r/.excluded-names"
run_script "$r" main..HEAD
verify 1 "CA2 : noms séparés par des virgules dans le fichier (Globex détecté)" "docs/notes.md"

r=$(repo_with_file docs/notes.md "Réunion avec Acmecorp demain")
printf 'Acmecorp\n' >"$r/.excluded-names"
run_env "$r" "EXCLUDED_NAMES=Globex" -- main..HEAD
verify 0 "CA2 : EXCLUDED_NAMES non vide prime sur le fichier (Acmecorp ignoré)" ""

r=$(repo_with_file docs/notes.md "Réunion avec Globex demain")
printf 'Acmecorp\n' >"$r/.excluded-names"
run_env "$r" "EXCLUDED_NAMES=Globex" -- main..HEAD
verify 1 "CA2 : EXCLUDED_NAMES non vide prime sur le fichier (Globex détecté)" "docs/notes.md"

# --- CA3 : fichier suivi, fichier non suivi ----------------------------------

file_case 1 "CA3 : nom dans un fichier suivi, chemin cité" "docs/notes.md" \
  "Acmecorp" docs/notes.md "Réunion avec Acmecorp demain"

r=$(new_repo)
write_file "$r" docs/brouillon.md "Réunion avec Acmecorp demain"
run_env "$r" "EXCLUDED_NAMES=Acmecorp" -- main..HEAD
verify 0 "CA3 : fichier non suivi contenant le nom accepté" ""

r=$(new_repo)
printf 'Acmecorp\n' >"$r/.excluded-names"
run_script "$r" main..HEAD
verify 0 "CA3 : .excluded-names non suivi ne déclenche rien" ""

# --- CA4 : insensible à la casse ---------------------------------------------

file_case 1 "CA4 : contenu « ACMECORP », liste « acmecorp »" "docs/notes.md" \
  "acmecorp" docs/notes.md "Réunion avec ACMECORP demain"
file_case 1 "CA4 : contenu « acmecorp », liste « ACMECORP »" "docs/notes.md" \
  "ACMECORP" docs/notes.md "Réunion avec acmecorp demain"

# --- CA5 : sous-chaîne -------------------------------------------------------

file_case 1 "CA5 : « SuperAcmecorpX » détecté" "docs/notes.md" \
  "Acmecorp" docs/notes.md "Le projet SuperAcmecorpX avance"

# --- CA6 : message de commit -------------------------------------------------

r=$(new_repo)
branch_commit "$r" "feat: travail pour Acmecorp"
sha=$(git -C "$r" rev-parse HEAD)
run_env "$r" "EXCLUDED_NAMES=Acmecorp" -- main..HEAD
verify 1 "CA6 : nom dans le message d'un commit de la plage, SHA complet cité" "$sha"
verify_hidden "CA6 message (plage explicite)"

r=$(new_repo)
git -C "$r" update-ref refs/remotes/origin/main main
branch_commit "$r" "feat: travail pour Acmecorp"
sha=$(git -C "$r" rev-parse HEAD)
run_env "$r" "EXCLUDED_NAMES=Acmecorp" --
verify 1 "CA6 : plage par défaut origin/main..HEAD, SHA complet cité" "$sha"
verify_hidden "CA6 message (plage par défaut)"

r=$(new_repo)
branch_commit "$r" "feat: ajout

Corps du message : demande de Globex"
sha=$(git -C "$r" rev-parse HEAD)
run_env "$r" "EXCLUDED_NAMES=Globex" -- main..HEAD
verify 1 "CA6 : nom dans le corps du message, SHA complet cité" "$sha"
verify_hidden "CA6 corps du message"

# Commit hors plage (déjà sur main) : accepté
r=$(new_repo)
git -C "$r" commit -q --allow-empty -m "chore: demande de Acmecorp"
branch_commit "$r" "feat: travail neutre"
run_env "$r" "EXCLUDED_NAMES=Acmecorp" -- main..HEAD
verify 0 "CA6 : commit hors plage (sur main) accepté, plage explicite" ""

r=$(new_repo)
git -C "$r" commit -q --allow-empty -m "chore: demande de Acmecorp"
git -C "$r" update-ref refs/remotes/origin/main main
branch_commit "$r" "feat: travail neutre"
run_env "$r" "EXCLUDED_NAMES=Acmecorp" --
verify 0 "CA6 : commit hors plage (sur origin/main) accepté, plage par défaut" ""

# --- CA7 : auteur et committer -----------------------------------------------

r=$(new_repo)
branch_commit "$r" "feat: travail neutre" GIT_AUTHOR_EMAIL=dev@acmecorp.example
sha=$(git -C "$r" rev-parse HEAD)
run_env "$r" "EXCLUDED_NAMES=Acmecorp" -- main..HEAD
verify 1 "CA7 : nom dans l'e-mail de l'auteur, SHA cité" "$sha"
verify_hidden "CA7 e-mail de l'auteur"

r=$(new_repo)
branch_commit "$r" "feat: travail neutre" GIT_AUTHOR_NAME="Dev Globex"
sha=$(git -C "$r" rev-parse HEAD)
run_env "$r" "EXCLUDED_NAMES=Globex" -- main..HEAD
verify 1 "CA7 : nom dans le nom de l'auteur, SHA cité" "$sha"
verify_hidden "CA7 nom de l'auteur"

r=$(new_repo)
branch_commit "$r" "feat: travail neutre" GIT_COMMITTER_NAME="Dev Acmecorp"
sha=$(git -C "$r" rev-parse HEAD)
run_env "$r" "EXCLUDED_NAMES=Acmecorp" -- main..HEAD
verify 1 "CA7 : nom dans le nom du committer, SHA cité" "$sha"
verify_hidden "CA7 nom du committer"

r=$(new_repo)
branch_commit "$r" "feat: travail neutre" GIT_COMMITTER_EMAIL=ops@globex.example
sha=$(git -C "$r" rev-parse HEAD)
run_env "$r" "EXCLUDED_NAMES=Globex" -- main..HEAD
verify 1 "CA7 : nom dans l'e-mail du committer, SHA cité" "$sha"
verify_hidden "CA7 e-mail du committer"

# --- CA8 : chemin d'un fichier suivi -----------------------------------------

file_case 1 "CA8 : nom dans le chemin d'un fichier suivi, contenu neutre" "" \
  "Acmecorp" docs/acmecorp-notes.md "Un contenu parfaitement neutre"

# Renforcé après revue : le fichier masqué est désigné par son objet Git, non vide
r=$(repo_with_file docs/acmecorp-notes.md "Un contenu parfaitement neutre")
blob=$(git -C "$r" rev-parse HEAD:docs/acmecorp-notes.md)
run_env "$r" "EXCLUDED_NAMES=Acmecorp" -- main..HEAD
verify 1 "CA8 : chemin masqué, objet Git du fichier cité" "objet $blob"
verify_hidden "CA8 objet Git cité"

# --- CA9 : plusieurs noms dans la liste et dans les résultats ----------------

r=$(repo_with_file docs/notes.md "Acmecorp et Globex dans le même fichier")
run_env "$r" "EXCLUDED_NAMES=Acmecorp,Globex,Initech" -- main..HEAD
verify 1 "CA9 : plusieurs noms trouvés dans un fichier, chemin cité" "docs/notes.md"
verify_hidden "plusieurs noms dans un fichier"

r=$(new_repo)
write_file "$r" docs/globex-acmecorp.md "Un contenu parfaitement neutre"
commit_all "$r" "docs: ajout de notes"
branch_commit "$r" "feat: demande de Globex" GIT_AUTHOR_EMAIL=dev@acmecorp.example
run_env "$r" "EXCLUDED_NAMES=Acmecorp,Globex,Initech" -- main..HEAD
verify 1 "CA9 : plusieurs noms (chemin, message, auteur), code 1" ""
verify_hidden "plusieurs noms (chemin, message, auteur)"

# --- CA10 : liste vide ou absente en CI --------------------------------------

r=$(new_repo)
run_env "$r" CI=true -- main..HEAD
verify 1 "CA10 : CI=true, variable absente et sans fichier, EXCLUDED_NAMES mentionnée" "EXCLUDED_NAMES"

r=$(new_repo)
run_env "$r" CI=true "EXCLUDED_NAMES=, ," -- main..HEAD
verify 1 "CA10 : CI=true, variable « , , » et sans fichier, EXCLUDED_NAMES mentionnée" "EXCLUDED_NAMES"

# --- CA11 : liste vide ou absente hors CI ------------------------------------

r=$(new_repo)
run_script "$r" main..HEAD
verify 0 "CA11 : hors CI, variable absente et sans fichier, avertissement EXCLUDED_NAMES" "EXCLUDED_NAMES"

r=$(new_repo)
run_env "$r" "EXCLUDED_NAMES=, ," -- main..HEAD
verify 0 "CA11 : hors CI, variable « , , » et sans fichier, avertissement EXCLUDED_NAMES" "EXCLUDED_NAMES"

# --- CA12 : dépôt propre -----------------------------------------------------

r=$(repo_with_file docs/notes.md "Un contenu parfaitement neutre")
branch_commit "$r" "feat: travail neutre"
run_env "$r" "EXCLUDED_NAMES=Acmecorp,Globex" -- main..HEAD
verify 0 "CA12 : dépôt propre accepté" ""

# --- CA13 : usage ------------------------------------------------------------

r=$(new_repo)
run_env "$r" "EXCLUDED_NAMES=Acmecorp" -- inexistant..HEAD
verify 2 "CA13 : plage invalide, code de sortie 2" ""

r=$(new_repo)
run_env "$r" "EXCLUDED_NAMES=Acmecorp" -- main..HEAD main..HEAD
verify 2 "CA13 : deux arguments, code de sortie 2" ""

# --- CA15 : en CI, seul le secret compte ; .excluded-names suivi refusé -------
# (ajouté après la revue de sécurité : un fichier versionné ne doit pas tenir
# lieu de secret)

r=$(repo_with_file docs/notes.md "Réunion avec Acmecorp demain")
printf 'Acmecorp\n' >"$r/.excluded-names"
run_env "$r" CI=true -- main..HEAD
verify 1 "CA15 : CI=true, fichier .excluded-names ignoré, secret exigé" "EXCLUDED_NAMES"
verify_hidden "CA15 fichier ignoré en CI"

r=$(new_repo)
printf 'Zzzzneutre\n' >"$r/.excluded-names"
git -C "$r" add -f .excluded-names
git -C "$r" commit -q -m "chore: ajout"
run_env "$r" "EXCLUDED_NAMES=Acmecorp" -- main..HEAD
verify 1 "CA15 : .excluded-names suivi par Git refusé" ".excluded-names"

r=$(new_repo)
printf '\n\n' >"$r/.excluded-names"
run_script "$r" main..HEAD
verify 0 "CA15 : hors CI, fichier fait de lignes vides, avertissement EXCLUDED_NAMES" "EXCLUDED_NAMES"

# --- CA16 : titre, description et branche de la PR ---------------------------

r=$(new_repo)
run_env "$r" "EXCLUDED_NAMES=Acmecorp" "PR_TITLE=feat: demande de Acmecorp" -- main..HEAD
verify 1 "CA16 : nom dans le titre de la PR" "titre"
verify_hidden "CA16 titre de la PR"

r=$(new_repo)
run_env "$r" "EXCLUDED_NAMES=Globex" "PR_BODY=Contexte : retour de GLOBEX" -- main..HEAD
verify 1 "CA16 : nom dans la description de la PR" "description"
verify_hidden "CA16 description de la PR"

r=$(new_repo)
run_env "$r" "EXCLUDED_NAMES=Acmecorp" "PR_HEAD_REF=feat/acmecorp-export" -- main..HEAD
verify 1 "CA16 : nom dans la branche de la PR" "branche"
verify_hidden "CA16 branche de la PR"

r=$(new_repo)
run_env "$r" "EXCLUDED_NAMES=Acmecorp" "PR_TITLE=feat: export" "PR_BODY=Neutre" "PR_HEAD_REF=feat/export" -- main..HEAD
verify 0 "CA16 : titre, description et branche neutres acceptés" ""

# --- CA17 : chemins non ASCII ou avec espaces --------------------------------

r=$(repo_with_file "docs/été notes.md" "Réunion avec Acmecorp demain")
run_env "$r" "EXCLUDED_NAMES=Acmecorp" -- main..HEAD
verify 1 "CA17 : chemin accentué avec espace cité en clair" "docs/été notes.md"
verify_hidden "CA17 chemin accentué"

r=$(repo_with_file "docs/Acmé notes.md" "Un contenu parfaitement neutre")
run_env "$r" "EXCLUDED_NAMES=Acmé" -- main..HEAD
verify 1 "CA17 : nom accentué dans un chemin détecté" ""
if grep -qiF -- "acm" <<<"$output"; then
  failed "CA17 : nom accentué dans un chemin jamais affiché, même échappé" "$(head -n 1 <<<"$output")"
else
  pass "CA17 : nom accentué dans un chemin jamais affiché, même échappé"
fi

r=$(repo_with_file "docs/Acmé notes.md" "Réunion avec Acmé demain")
run_env "$r" "EXCLUDED_NAMES=Acmé" -- main..HEAD
verify 1 "CA17 : nom accentué dans le chemin et le contenu détecté" ""
if grep -qiF -- "acm" <<<"$output"; then
  failed "CA17 : chemin accentué masqué dans le rapport du contenu" "$(head -n 1 <<<"$output")"
else
  pass "CA17 : chemin accentué masqué dans le rapport du contenu"
fi

# --- CA18 : lignes ajoutées par les commits de la plage ----------------------

# Nom ajouté puis retiré dans la PR : absent de l'arbre final, mais présent
# dans l'historique qui sera publié
r=$(new_repo)
git -C "$r" checkout -q -b feat/pr
write_file "$r" docs/notes.md "Réunion avec Acmecorp demain"
commit_all "$r" "docs: notes"
sha=$(git -C "$r" rev-parse HEAD)
write_file "$r" docs/notes.md "Réunion demain"
commit_all "$r" "docs: notes revues"
run_env "$r" "EXCLUDED_NAMES=Acmecorp" -- main..HEAD
verify 1 "CA18 : nom ajouté puis retiré dans la plage, SHA du commit cité" "$sha"
verify_hidden "CA18 nom ajouté puis retiré"

# Une PR qui retire un nom déjà présent sur main est acceptée
r=$(repo_with_file docs/notes.md "Réunion avec Acmecorp demain")
git -C "$r" checkout -q -b feat/pr
write_file "$r" docs/notes.md "Réunion demain"
commit_all "$r" "docs: retrait"
run_env "$r" "EXCLUDED_NAMES=Acmecorp" -- main..HEAD
verify 0 "CA18 : PR qui retire un nom acceptée (lignes retirées ignorées)" ""

# --- CA19 : tout l'historique ------------------------------------------------

r=$(new_repo)
write_file "$r" docs/notes.md "Réunion avec Globex demain"
commit_all "$r" "docs: notes"
sha=$(git -C "$r" rev-parse HEAD)
write_file "$r" docs/notes.md "Réunion demain"
commit_all "$r" "docs: notes revues"
run_env "$r" "EXCLUDED_NAMES=Globex" -- main..HEAD
verify 0 "CA19 : sans --all, l'historique de main n'est pas relu" ""
run_env "$r" "EXCLUDED_NAMES=Globex" -- --all
verify 1 "CA19 : --all relit tout l'historique, SHA cité" "$sha"
verify_hidden "CA19 tout l'historique"

# --- CA20 : motif trop court -------------------------------------------------

r=$(new_repo)
run_env "$r" "EXCLUDED_NAMES=Acmecorp,Gx" -- main..HEAD
verify 2 "CA20 : nom de moins de 3 caractères refusé, code 2" ""
if grep -qF -- "Gx" <<<"$output"; then
  failed "CA20 : nom trop court jamais affiché" "$(head -n 1 <<<"$output")"
else
  pass "CA20 : nom trop court jamais affiché"
fi

# --- CA21 : une erreur de Git ne vaut jamais « rien trouvé » -----------------

mkdir -p "$work/fakebin"
real_git=$(command -v git)
cat >"$work/fakebin/git" <<EOF
#!/usr/bin/env bash
for a in "\$@"; do
  [ "\$a" = "\$FAIL_GIT_SUBCOMMAND" ] && exit 128
done
exec "$real_git" "\$@"
EOF
chmod +x "$work/fakebin/git"

for sub in grep log show rev-list ls-files; do
  r=$(repo_with_file docs/notes.md "Un contenu parfaitement neutre")
  branch_commit "$r" "feat: travail neutre"
  run_env "$r" "PATH=$work/fakebin:$PATH" "FAIL_GIT_SUBCOMMAND=$sub" "EXCLUDED_NAMES=Acmecorp" -- main..HEAD
  verify 2 "CA21 : échec de git $sub, code de sortie 2" ""
done

# --- CA14 : .excluded-names ignoré par Git dans le vrai dépôt ----------------

if git -C "$template" check-ignore -q .excluded-names; then
  pass "CA14 : .excluded-names est ignoré par Git"
else
  failed "CA14 : .excluded-names est ignoré par Git" "absent de .gitignore"
fi

exit $fail
