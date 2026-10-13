# shellcheck shell=bash
# Fonctions partagées par lint.sh et run-tests.sh (spec 006). Fichier sourcé, non exécuté.

# pending_marker <projet> <session> : chemin de la marque « tests à lancer » de la
# session, dans le répertoire Git du worktree. Échoue hors d'un dépôt Git.
pending_marker() {
  local project=$1 session=$2 path
  # Identifiant réduit à des caractères sûrs pour un nom de fichier, et raccourci
  # (un nom trop long empêcherait de créer la marque)
  session=$(printf '%s' "${session:-sans-session}" | tr -c 'A-Za-z0-9_-' '_' | cut -c1-64)
  path=$(cd "$project" 2>/dev/null && git rev-parse --git-path "claude-quality/tests-pending-$session" 2>/dev/null) || return 1
  case "$path" in
    /*) printf '%s\n' "$path" ;;
    *) printf '%s/%s\n' "$project" "$path" ;;
  esac
}
