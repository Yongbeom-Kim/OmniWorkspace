#!/usr/bin/env bash
set -euo pipefail

## Control Sequences ##

if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
	RESET='\033[0m'
	BOLD='\033[1m'
	DIM='\033[2m'
	ITALIC='\033[3m'
	UNDERLINE='\033[4m'
	BLINK='\033[5m'
	BLINK_FAST='\033[6m'
	REVERSE='\033[7m'
	HIDDEN='\033[8m'
	STRIKETHROUGH='\033[9m'

	BLACK='\033[30m'
	RED='\033[31m'
	GREEN='\033[32m'
	YELLOW='\033[33m'
	BLUE='\033[34m'
	MAGENTA='\033[35m'
	CYAN='\033[36m'
	WHITE='\033[37m'
	DEFAULT='\033[39m'

	BRIGHT_BLACK='\033[90m' # (Dark Gray)
	BRIGHT_RED='\033[91m'
	BRIGHT_GREEN='\033[92m'
	BRIGHT_YELLOW='\033[93m'
	BRIGHT_BLUE='\033[94m'
	BRIGHT_MAGENTA='\033[95m'
	BRIGHT_CYAN='\033[96m'
	BRIGHT_WHITE='\033[97m'

	BG_BLACK='\033[40m'
	BG_RED='\033[41m'
	BG_GREEN='\033[42m'
	BG_YELLOW='\033[43m'
	BG_BLUE='\033[44m'
	BG_MAGENTA='\033[45m'
	BG_CYAN='\033[46m'
	BG_WHITE='\033[47m'
	BG_DEFAULT='\033[49m'

	BG_BRIGHT_BLACK='\033[100m'
	BG_BRIGHT_RED='\033[101m'
	BG_BRIGHT_GREEN='\033[102m'
	BG_BRIGHT_YELLOW='\033[103m'
	BG_BRIGHT_BLUE='\033[104m'
	BG_BRIGHT_MAGENTA='\033[105m'
	BG_BRIGHT_CYAN='\033[106m'
	BG_BRIGHT_WHITE='\033[107m'

	CURSOR_UP='\033[1A'
	CURSOR_DOWN='\033[1B'
	CURSOR_RIGHT='\033[1C'
	CURSOR_LEFT='\033[1D'
	CURSOR_HOME='\033[H'    # Move to top-left
	CURSOR_SAVE='\033[s'    # Save cursor position
	CURSOR_RESTORE='\033[u' # Restore cursor position
	CURSOR_HIDE='\033[?25l'
	CURSOR_SHOW='\033[?25h'

	ERASE_LINE='\033[2K'         # Erase entire current line
	ERASE_LINE_END='\033[K'      # Erase from cursor to end of line
	ERASE_LINE_START='\033[1K'   # Erase from cursor to start of line
	ERASE_SCREEN='\033[2J'       # Erase entire screen
	ERASE_SCREEN_END='\033[0J'   # Erase from cursor to end of screen
	ERASE_SCREEN_START='\033[1J' # Erase from cursor to start of screen
else
	RESET=''
	BOLD=''
	DIM=''
	ITALIC=''
	UNDERLINE=''
	BLINK=''
	BLINK_FAST=''
	REVERSE=''
	HIDDEN=''
	STRIKETHROUGH=''

	BLACK=''
	RED=''
	GREEN=''
	YELLOW=''
	BLUE=''
	MAGENTA=''
	CYAN=''
	WHITE=''
	DEFAULT=''

	BRIGHT_BLACK=''
	BRIGHT_RED=''
	BRIGHT_GREEN=''
	BRIGHT_YELLOW=''
	BRIGHT_BLUE=''
	BRIGHT_MAGENTA=''
	BRIGHT_CYAN=''
	BRIGHT_WHITE=''

	BG_BLACK=''
	BG_RED=''
	BG_GREEN=''
	BG_YELLOW=''
	BG_BLUE=''
	BG_MAGENTA=''
	BG_CYAN=''
	BG_WHITE=''
	BG_DEFAULT=''

	BG_BRIGHT_BLACK=''
	BG_BRIGHT_RED=''
	BG_BRIGHT_GREEN=''
	BG_BRIGHT_YELLOW=''
	BG_BRIGHT_BLUE=''
	BG_BRIGHT_MAGENTA=''
	BG_BRIGHT_CYAN=''
	BG_BRIGHT_WHITE=''

	CURSOR_UP=''
	CURSOR_DOWN=''
	CURSOR_RIGHT=''
	CURSOR_LEFT=''
	CURSOR_HOME=''
	CURSOR_SAVE=''
	CURSOR_RESTORE=''
	CURSOR_HIDE=''
	CURSOR_SHOW=''

	ERASE_LINE=''
	ERASE_LINE_END=''
	ERASE_LINE_START=''
	ERASE_SCREEN=''
	ERASE_SCREEN_END=''
	ERASE_SCREEN_START=''
fi

## Project Variables ##

SCRIPT_NAME=$(basename "$0")
PROJ_DIR="${PROJ_DIR:-$HOME/.ows}"
REPOS_DIR="${REPOS_DIR:-$PROJ_DIR/repos}"
WORKSPACES_DIR="${WORKSPACES_DIR:-$PROJ_DIR/workspaces}"

# Validate that critical directories are absolute paths under $HOME
for _dir_var in PROJ_DIR REPOS_DIR WORKSPACES_DIR; do
	if [[ "${!_dir_var}" != "$HOME"/* ]]; then
		echo "[FATAL] $_dir_var must be under \$HOME ($HOME), got '${!_dir_var}'" >&2
		exit 1
	fi
done
unset _dir_var

trap 'echo "Error on line $LINENO in ${FUNCNAME[0]:-main}" >&2; debug_stack_trace' ERR

fatal() {
	echo -e "[FATAL] $*" >&2
	debug_stack_trace
	exit 1
}

warn() {
	echo -e "[WARN] $*" >&2
}

info() {
	if [[ -z ${DEBUG:-} ]]; then
		echo -e "$*" >&2
	else
		echo -e "[INFO] $*" >&2
	fi
}

debug() {
	if [[ -z ${DEBUG:-} ]]; then
		return 0
	fi
	echo -e "[DEBUG] ${BASH_SOURCE[1]}:${BASH_LINENO[0]} ${FUNCNAME[1]}() $*" >&2
}

debug_stack_trace() {
	if [[ -z ${DEBUG:-} ]]; then
		return 0
	fi

	echo "Stack trace:" >&2
	local i
	for i in "${!FUNCNAME[@]}"; do
		# skip stack_trace itself
		[[ $i -eq 0 ]] && continue
		echo "  [$i] ${FUNCNAME[$i]}() ${BASH_SOURCE[$i]}:${BASH_LINENO[$i-1]}" >&2
	done
}

main() {
	debug "$*"
	dependency__assert_git
	dependency__assert_yq

	local cmd="${1:-}"

	if [[ -z "$cmd" ]]; then
		echo "Usage: ows <command> [args]"
		echo "Commands: workspace (ws), workspaces (wss), repo (r), repos (rs)"
		exit 1
	fi

	case "$cmd" in
	"workspaces" | "wss")
		shift
		cmd__workspace__list "$@"
		;;
	"workspace" | "ws" | "w" | "wsp")
		shift
		cmd__workspace "$@"
		;;
	"repos" | "rs")
		shift
		cmd__repo__list "$@"
		;;
	"repo" | "r")
		shift
		cmd__repo "$@"
		;;
	*)
		echo "Unknown command: $cmd"
		exit 1
		;;
	esac
}

####################################
##### High-Level User Commands #####
####################################

####################
### Workspaces ###
####################

cmd__workspace() {
	debug "$*"

	case ${1:-} in
	"add" | "add-repo")
		shift
		cmd__workspace__add "$@"
		;;
	"remove-repo")
		shift
		cmd__workspace__remove_repo "$@"
		;;
	"delete")
		shift
		cmd__workspace__delete "$@"
		;;
	"list")
		shift
		cmd__workspace__list "$@"
		;;
	"exec")
		shift
		cmd__workspace__exec "$@"
		;;
	"checkout")
		shift
		cmd__workspace__checkout "$@"
		;;
	*)
		echo "Unknown sub-command: ${1:-}. Available sub-commands: add, add-repo, remove-repo, delete, list, exec, checkout"
		exit 1
		;;
	esac
}

# Functions as both "create workspace" and "add repo to workspace"
cmd__workspace__add() {
	local USAGE="

Usage (workspace add):
    $SCRIPT_NAME workspace add <workspace_name> [repo1 repo2 ...]
    $SCRIPT_NAME workspace add-repo <workspace_name> [repo1 repo2 ...]

Creates a workspace and/or adds repos to an existing workspace.
"

	local curr_workspace
	if ! config__workspace__exists "${1:-}" && curr_workspace=$(env__get_caller_workspace); then
		info "Workspace detected as $curr_workspace"
		set -- "$curr_workspace" "$@"
	fi

	local workspace_name="${1:?"Error: workspace name is required.$USAGE"}"
	validate_name "$workspace_name" "workspace name"
	shift
	local workspace_repos=("$@")

	workspace__add "$workspace_name" "${workspace_repos[@]}"
}

cmd__workspace__delete() {
	local USAGE="

Usage (workspace delete):
    $SCRIPT_NAME workspace delete <workspace_name>

Deletes a workspace and its worktree directories.
"

	local curr_workspace
	if ! config__workspace__exists "${1:-}" && curr_workspace=$(env__get_caller_workspace); then
		info "Workspace detected as $curr_workspace"
		set -- "$curr_workspace" "$@"
	fi

	local workspace_name="${1:?"Error: workspace name is required.$USAGE"}"
	validate_name "$workspace_name" "workspace name"
	workspace__delete "$workspace_name"
}

cmd__workspace__list() {
	local USAGE="

Usage (workspace list):
    $SCRIPT_NAME workspaces
    $SCRIPT_NAME workspace list

Lists all workspaces.
"

	workspace__list
}

cmd__workspace__remove_repo() {
	local USAGE="

Usage (workspace remove-repo):
    $SCRIPT_NAME workspace remove-repo <workspace_name> <repo1> [repo2 ...]

Removes one or more repos from a workspace.
"

	local curr_workspace
	if ! config__workspace__exists "${1:-}" && curr_workspace=$(env__get_caller_workspace); then
		info "Workspace detected as $curr_workspace"
		set -- "$curr_workspace" "$@"
	fi

	local workspace_name="${1:?"Error: workspace name is required.$USAGE"}"
	validate_name "$workspace_name" "workspace name"
	shift
	local repos_to_remove=("$@")

	if [[ ${#repos_to_remove[@]} -eq 0 ]]; then
		warn "Error: No repos to remove from workspace $workspace_name.$USAGE"
		return 0
	fi

	workspace__remove_repos "$workspace_name" "${repos_to_remove[@]}"
}

cmd__workspace__exec() {
	local USAGE="

Usage (workspace exec):
    $SCRIPT_NAME workspace exec <workspace_name> <command> [args ...]

Executes a command in each repo directory of the workspace.
"

	local curr_workspace
	if ! config__workspace__exists "${1:-}" && curr_workspace=$(env__get_caller_workspace); then
		info "Workspace detected as $curr_workspace"
		set -- "$curr_workspace" "$@"
	fi

	local workspace_name="${1:?"Error: workspace name is required.$USAGE"}"
	validate_name "$workspace_name" "workspace name"
	shift

	if [[ $# -eq 0 ]]; then
		fatal "Error: command is required.$USAGE"
	fi

	local args=("$@")

	workspace__exec "$workspace_name" "${args[@]}"
}

cmd__workspace__checkout() {
	local USAGE="

Usage (workspace checkout):
    $SCRIPT_NAME workspace checkout <workspace_name> <branch_name>
    $SCRIPT_NAME workspace checkout <workspace_name> -b <branch_name>

Checks out all worktree repositories in a particular workspace to a given branch.
If the branch does not exist, it is always created. The -b option does nothing, but exists to match the git checkout -b syntax.
"

	local curr_workspace
	if ! config__workspace__exists "${1:-}" && curr_workspace=$(env__get_caller_workspace); then
		info "Workspace detected as $curr_workspace"
		set -- "$curr_workspace" "$@"
	fi

	local workspace_name="${1:?"Error: workspace_name is required.$USAGE"}"
	validate_name "$workspace_name" "workspace name"
	shift
	if [[ "${1:?"Error: branch_name is required.$USAGE"}" == "-b" ]]; then
		shift # ignore -b flag, because we want to treat checkout -b BRANCH vs checkout BRANCH to be the same
	fi
	local branch_name="${1:?"Error: branch_name is required.$USAGE"}"
	validate_name "$branch_name" "branch name"
	shift

	if [[ "$#" -ne 0 ]]; then
		fatal "Error: invalid syntax (too many parameters)." "$USAGE"
	fi

	workspace__checkout__branch "$workspace_name" "$branch_name"
}

####################
### Repositories ###
####################

cmd__repo() {
	debug "$*"
	repo__validate_all
	case ${1:-} in
	"add")
		shift
		cmd__repo__add "$@"
		;;
	"remove")
		shift
		cmd__repo__remove "$@"
		;;
	"list")
		shift
		cmd__repo__list "$@"
		;;
	*)
		echo "Unknown sub-command: ${1:-}. Available sub-commands: add, remove, list"
		exit 1
		;;
	esac
}

cmd__repo__add() {
	local USAGE="

Usage (repo add):
    $SCRIPT_NAME repo add <repo_url> [repo_name]

Registers a git repository. If repo_name is omitted, it is derived from the URL.
"

	debug "$*"
	local repo_url="${1:?"Error: repo_url is required.$USAGE"}"
	local repo_name=${2:-}

	if [[ -z "$repo_name" ]] && ! repo_name_from_url=$(git__get_repo_name "$repo_url"); then
		warn "Failed to get repository name from URL: $repo_url"
		return 1
	fi

	local repo_name=${repo_name:-$repo_name_from_url}
	validate_name "$repo_name" "repo name"

	repo__add "$repo_url" "$repo_name"
}

cmd__repo__remove() {
	local USAGE="

Usage (repo remove):
    $SCRIPT_NAME repo remove <repo_name>

Removes a registered repository.
"

	debug "$*"
	local repo_name="${1:?"Error: repo_name is required.$USAGE"}"
	validate_name "$repo_name" "repo name"

	repo__remove "$repo_name"
}

cmd__repo__list() {
	local USAGE="

Usage (repo list):
    $SCRIPT_NAME repos
    $SCRIPT_NAME repo list

Lists all registered repositories.
"

	debug "$*"
	repo__validate_all
	local repos=($(config__repo__list))
	local cells=()

	for repo in "${repos[@]+"${repos[@]}"}"; do
		cells+=("$repo")
		cells+=("$(config__repo__get_originurl "$repo")")
		cells+=("$(config__repo__get_dir "$repo")")
	done

	print_table_horizontally 3 "repo" "origin" "directory" "${cells[@]+"${cells[@]}"}"
}

###########################################
##### High-Level Workspace Management #####
###########################################

workspace__add() {
	debug "$*"
	workspace__validate_all
	repo__validate_all

	local workspace_name="$1"
	shift
	local workspace_repos=("$@")

	if ! config__workspace__create_idempotent "$workspace_name"; then
		warn "Failed to create workspace $workspace_name."
		return 1
	fi

	local workspace_dir
	workspace_dir="$(fs__workspace_get_dir "$workspace_name")"
	fs__workspace_mkdir_idempotent "$workspace_name"

	for repo in "${workspace_repos[@]+"${workspace_repos[@]}"}"; do
		if [[ -z $repo ]]; then
			continue
		fi
		if ! config__workspace__add_repo_idempotent "$workspace_name" "$repo"; then
			warn "Failed to add repo $repo to workspace $workspace_name. Try again later."
			continue
		fi

		local repo_dir
		repo_dir="$(config__repo__get_dir "$repo")"
		local subtree_dir="$workspace_dir/$repo"
		local branch_name="$workspace_name"

		if ! git__create_workspace_worktree_idempotent "$repo_dir" "$subtree_dir" "$branch_name"; then
			warn "Failed to add git worktree of $repo to workspace $workspace_name. Maybe it already exists? Try again later."
			continue
		fi

		echo "Successfully added repo $repo to workspace $workspace_name."
	done
}

workspace__delete() {
	debug "$*"
	workspace__validate_all
	local workspace_name="$1"

	local repos=($(config__workspace__get_repos "$workspace_name"))
	workspace__remove_repos "$workspace_name" "${repos[@]+"${repos[@]}"}"

	if ! config__workspace__delete_idempotent "$workspace_name"; then
		warn "Failed to delete workspace $workspace_name."
		return 1
	fi

	fs__safe_rm_rf "$(fs__workspace_get_dir "$workspace_name")" "$WORKSPACES_DIR"
}

workspace__list() {
	debug "$*"
	workspace__validate_all
	local workspaces=($(config__workspace__list))
	local repos_column=()
	local branch_column=()

	for workspace in "${workspaces[@]+"${workspaces[@]}"}"; do
		if [[ -z "$workspace" ]]; then
			continue
		fi
		local repos
		repos=($(config__workspace__get_repos "$workspace"))
		local repo_cell=""
		for i in "${!repos[@]}"; do
			repo_cell+="${repos[$i]}"
			if [[ i -lt $((${#repos[@]} - 1)) ]]; then
				repo_cell+=", "
			fi
		done
		repos_column+=("$repo_cell")

		local branch
		branch="$(config__workspace__get_branch "$workspace")"

		branch_column+=("$branch")
	done

	print_table_vertically 3 "workspace" "${workspaces[@]+"${workspaces[@]}"}" "branch" "${branch_column[@]+"${branch_column[@]}"}" "repos" "${repos_column[@]+"${repos_column[@]}"}"
}

workspace__remove_repos() {
	debug "$*"
	workspace__validate_all
	local workspace_name="${1:?"workspace name is required"}"
	shift
	# we checked this in cmd__workspace__remove_repo, so guaranteed to have value
	local repos_to_remove=("$@")

	for repo in "${repos_to_remove[@]+"${repos_to_remove[@]}"}"; do
		local repo_dir
		repo_dir="$(config__repo__get_dir "$repo")"
		local subtree_dir
		subtree_dir="$(fs__workspace_get_repo_subtree_dir "$workspace_name" "$repo")"
		git__remove_workspace_worktree_idempotent "$repo_dir" "$subtree_dir"

		if ! config__workspace__remove_repo_idempotent "$workspace_name" "$repo"; then
			warn "Failed to remove repo $repo from workspace $workspace_name"
		fi
	done
}

workspace__exec() {
	debug "$*"
	workspace__validate_all

	local workspace_name="${1:?"workspace name is required"}"
	shift

	if ! config__workspace__exists "$workspace_name"; then
		fatal "Workspace $workspace_name does not exist"
	fi

	local workspace_dir="$WORKSPACES_DIR/$workspace_name"
	if [[ ! -d "$workspace_dir" ]]; then
		warn "Workspace directory $workspace_dir does not exist"
		return 1
	fi

	cd "$workspace_dir" && "$@"
}

workspace__checkout__branch() {
	debug "$*"
	workspace__validate_all
	repo__validate_all

	local workspace_name="$1"
	local branch_name="$2"

	if ! config__workspace__exists "$workspace_name"; then
		fatal "Workspace $workspace_name does not exist"
	fi

	local repos=($(config__workspace__get_repos "$workspace_name"))

	if ! config__workspace__set_branch_idempotent "$workspace_name" "$branch_name"; then
		fatal "Failed to checkout branch $branch_name for workspace $workspace_name"
	fi

	for repo_name in "${repos[@]+"${repos[@]}"}"; do
		local destination_worktree_dir
		destination_worktree_dir="$(fs__workspace_get_repo_subtree_dir "$workspace_name" "$repo_name")"
		if ! git__checkout_branch_on_worktree "$destination_worktree_dir" "$branch_name"; then
			warn "Failed to checkout branch $branch_name for repo $repo_name ($destination_worktree_dir) under workspace $workspace_name"
		fi
	done

}

workspace__validate_all() {
	debug "$*"
	local workspaces=($(config__workspace__list))

	for workspace in "${workspaces[@]+"${workspaces[@]}"}"; do
		if [[ -z "$workspace" ]]; then
			continue
		fi
		workspace__validate "$workspace"
	done

	# TODO: delete workspaces and worktrees that aren't in the config anymore
}

workspace__validate() {
	debug "$*"
	local workspace_name="$1"
	local workspace_dir
	workspace_dir="$(fs__workspace_get_dir "$workspace_name")"
	local repos
	repos=($(config__workspace__get_repos "$workspace_name"))

	fs__workspace_mkdir_idempotent "$workspace_name"

	for repo in "${repos[@]+"${repos[@]}"}"; do
		if [[ -z "$repo" ]]; then
			continue
		fi

		local repo_dir
		repo_dir="$(config__repo__get_dir "$repo")"
		local subtree_dir
		subtree_dir=$(fs__workspace_get_repo_subtree_dir "$workspace_name" "$repo")
		local branch_name="$workspace_name"

		if ! git__create_workspace_worktree_idempotent "$repo_dir" "$subtree_dir" "$branch_name"; then
			warn "Failed to add git worktree of $repo to workspace $workspace_name. Maybe it already exists? Try again later."
			continue
		fi
	done
}

######################################
##### High-Level Repo Management #####
######################################

# Validate all repos.
repo__validate_all() {
	debug "$*"
	config__create_file_if_not_exist

	local repos
	repos=($(config__repo__list))

	for repo_name in "${repos[@]+"${repos[@]}"}"; do
		# Funny bash business for empty arrays
		if [[ -z $repo_name ]]; then
			continue
		fi

		repo__validate__restore_from_config "$repo_name"
	done
}

repo__validate__restore_from_config() {
	debug "$*"
	local repo_name="$1"
	local repo_dir
	repo_dir=$(config__repo__get_dir "$repo_name")
	local repo_originurl
	repo_originurl=$(config__repo__get_originurl "$repo_name")

	# 1. Try to reconstruct variables
	if [[ -z "$repo_dir" ]]; then
		repo_dir="$REPOS_DIR/$repo_name"
	fi
	if [[ -z "$repo_originurl" && -d "$repo_dir" ]]; then
		repo_originurl="$(git__get_origin "$repo_dir")"
	fi

	# 2. If origin url is no more, cannot be restored
	if [[ -z "$repo_originurl" ]]; then
		repo__remove "$repo_name"
		return 0
	fi

	# 3. We add the repo back
	repo__add "$repo_originurl" "$repo_name" "$repo_dir" || true
}

repo__add() {
	debug "$*"

	local repo_url=${1:?}
	local repo_name=${2:?}
	local repo_dir="${3:-$REPOS_DIR/$repo_name}"

	# Check if repo already exists with the same config — skip if so
	local existing_url
	existing_url=$(config__repo__get_originurl "$repo_name")
	local existing_dir
	existing_dir=$(config__repo__get_dir "$repo_name")
	if [[ "$existing_url" == "$repo_url" && "$existing_dir" == "$repo_dir" ]]; then
		if git__validate_repo "$repo_url" "$repo_name"; then
			debug "Repository $repo_name already exists with same config, skipping"
			return 0
		fi
	fi

	# Configs are always the source of truth, so we always add to config first.
	if ! config__repo__set "$repo_url" "$repo_name" "$repo_dir"; then
		warn "Failed to add repository $repo_name to config."
		return 1
	fi

	if ! repo_dir=$(git__add_repo_idempotent "$repo_url" "$repo_name"); then
		config__repo__remove_idempotent "$repo_name"
		warn "Failed to add repository $repo_name. Parameters: $repo_url, $repo_name"
		return 1
	fi

	echo "Repository $repo_name added successfully."
}

repo__remove() {
	debug "$*"

	local repo_name=${1:?}
	local repo_dir="$REPOS_DIR/$repo_name"

	# Remove directory if it exists
	if [[ -d "$repo_dir" ]]; then
		if ! fs__safe_rm_rf "$repo_dir" "$REPOS_DIR"; then
			warn "Failed to remove repository directory $repo_name."
			return 1
		fi
	fi

	# Remove from config (idempotent — OK if already absent)
	config__repo__remove_idempotent "$repo_name"

	echo "Repository $repo_name removed successfully."
}

###############################
##### Yaml Configurations #####
###############################

CONFIG_FILE_PATH="$PROJ_DIR/config.yaml"

#############################
### Yaml Workspace Config ###
#############################

config__workspace__create_idempotent() {
	debug "$*"
	config__create_file_if_not_exist

	local workspace_name="$1"

	if config__workspace__exists "$workspace_name"; then
		warn "Creating workspace $workspace_name: already exists"
		# Idempotent, so OK to return 0
		return 0
	fi

	if ! yq -i ".workspaces.[\"${workspace_name}\"].repos = []" "$CONFIG_FILE_PATH"; then
		warn "Failed to create new workspace ${workspace_name}"
		return 1
	fi
}

config__workspace__delete_idempotent() {
	debug "$*"
	config__create_file_if_not_exist

	local workspace_name="$1"

	if ! config__workspace__exists "$workspace_name"; then
		warn "Deleting workspace $workspace_name: already absent"
		return 0
	fi

	yq -i "del(.workspaces.[\"${workspace_name}\"])" "$CONFIG_FILE_PATH"
}

config__workspace__add_repo_idempotent() {
	debug "$*"
	config__create_file_if_not_exist
	local workspace_name="$1"
	local repo_name="$2"

	if config__workspace__has_repo "$workspace_name" "$repo_name"; then
		warn "Adding repo $repo_name to workspace $workspace_name: already exists"
		return 0
	fi

	yq -i ".workspaces.[\"${workspace_name}\"].repos += [\"$repo_name\"]" "$CONFIG_FILE_PATH"
}

config__workspace__remove_repo_idempotent() {
	debug "$*"
	config__create_file_if_not_exist
	local workspace_name="$1"
	local repo_name="$2"

	if ! config__workspace__has_repo "$workspace_name" "$repo_name"; then
		warn "Removing repo $repo_name from workspace $workspace_name: does not exist"
		return 0
	fi

	yq -i "del(.workspaces.[\"${workspace_name}\"].repos[] | select(. == \"$repo_name\"))" "$CONFIG_FILE_PATH"
}

config__workspace__exists() {
	debug "$*"
	config__create_file_if_not_exist
	local workspace_name="$1"
	yq -e ".workspaces.[\"${workspace_name}\"]" "$CONFIG_FILE_PATH" &>/dev/null
}

config__workspace__has_repo() {
	debug "$*"
	config__create_file_if_not_exist

	local workspace_name="$1"
	local repo_name="$2"

	if [[ -n $(yq ".workspaces.[\"${workspace_name}\"].repos[] | select(. == \"$repo_name\")" "$CONFIG_FILE_PATH") ]]; then
		return 0
	else
		return 1
	fi
}

config__workspace__get_repos() {
	debug "$*"
	config__create_file_if_not_exist

	local workspace="${1:?}"

	local result
	result=$(yq ".workspaces.[\"${workspace}\"].repos[]" "$CONFIG_FILE_PATH" 2>/dev/null) || true

	if [[ -n "$result" && "$result" != "null" ]]; then
		echo "$result"
	fi
}

config__workspace__set_branch_idempotent() {
	debug "$*"
	config__create_file_if_not_exist

	local workspace_name="${1:?}"
	local branch_name="${2:?}"

	if config__test_workspace_branch_exists "$branch_name" && [[ "$(config__workspace__get_branch "$workspace_name")" != "$branch_name" ]]; then
		fatal "Failed to set branch for workspace $workspace_name: Branch $branch_name already exists in a different workspace."
	fi

	yq -i ".workspaces.[\"${workspace_name}\"].branch = \"$branch_name\"" "$CONFIG_FILE_PATH"
}

config__test_workspace_branch_exists() {
	debug "$*"
	config__create_file_if_not_exist

	local branch_name="${1:?}"
	local workspaces

	workspaces=($(config__workspace__list))
	for workspace_name in "${workspaces[@]+"${workspaces[@]}"}"; do
		if [[ -z "$workspace_name" ]]; then
			continue
		fi
		local current_branch
		current_branch="$(config__workspace__get_branch "$workspace_name")"
		if [[ "$current_branch" == "$branch_name" ]]; then
			debug "Found branch $branch_name"
			return 0
		fi
	done

	debug "Did not find $branch_name"
	return 1
}

config__workspace__get_branch() {
	debug "$*"
	config__create_file_if_not_exist

	local workspace="${1:?}"

	local result
	result=$(yq ".workspaces.[\"${workspace}\"].branch" "$CONFIG_FILE_PATH" 2>/dev/null) || true

	if [[ -n "$result" && "$result" != "null" ]]; then
		echo "$result"
	else
		# Default branch is the workspace name
		echo "$workspace"
	fi
}

config__workspace__list() {
	debug "$*"
	config__create_file_if_not_exist

	local result
	result=$(yq '.workspaces | keys | .[]' "$CONFIG_FILE_PATH" 2>/dev/null) || true

	if [[ -n "$result" && "$result" != "null" ]]; then
		echo "$result"
	fi
}

########################
### Yaml Repo Config ###
########################

config__repo__set() {
	debug "$*"
	config__create_file_if_not_exist

	local repo_url=${1:?}
	local repo_name=${2:?}
	local repo_dir=${3:?}

	yq -i ".repos.[\"${repo_name}\"] = {\"origin_url\": \"$repo_url\", \"dir\": \"$repo_dir\"}" "$CONFIG_FILE_PATH"
}

config__repo__remove_idempotent() {
	debug "$*"
	config__create_file_if_not_exist
	local repo_name=${1:?}

	yq -i "del(.repos.[\"${repo_name}\"])" "$CONFIG_FILE_PATH"
}

config__repo__list() {
	debug "$*"
	config__create_file_if_not_exist

	local result
	result=$(yq '.repos | keys | .[]' "$CONFIG_FILE_PATH" 2>/dev/null) || true

	if [[ -n "$result" && "$result" != "null" ]]; then
		echo "$result"
	fi
}

config__repo__get_dir() {
	debug "$*"
	config__create_file_if_not_exist
	local repo_name="${1:?}"

	local result
	result=$(yq -r ".repos.[\"${repo_name}\"].dir" "$CONFIG_FILE_PATH")
	if [[ -n "$result" && "$result" != "null" ]]; then
		echo "$result"
	fi
}

config__repo__get_originurl() {
	debug "$*"
	config__create_file_if_not_exist
	local repo_name=${1:?}

	local result
	result=$(yq -r ".repos.[\"${repo_name}\"].origin_url" "$CONFIG_FILE_PATH")
	if [[ "$result" == "null" ]]; then
		echo ""
	else
		echo "$result"
	fi
}

config__create_file_if_not_exist() {
	if [[ ! -f "$CONFIG_FILE_PATH" ]]; then
		mkdir -p "$REPOS_DIR"
		mkdir -p "$WORKSPACES_DIR"
		touch "$CONFIG_FILE_PATH"
	fi
}

#######################
##### Git Facades #####
#######################

git__add_repo_idempotent() {
	debug "$*"
	local repo_url=${1:?}
	local repo_name=${2:?}
	local repo_dir
	repo_dir="$(const__get_repo_dir "$repo_name")"

	if ! git__validate_repo "$repo_url" "$repo_name"; then
		warn "Pre-clone check: there is an issue with the repo. Clearing and re-cloning..."
		fs__safe_rm_rf "$repo_dir" "$REPOS_DIR"
		if ! git clone "$repo_url" "$repo_dir"; then
			warn "Failed to clone repository $repo_name."
			return 1
		fi
	fi

	realpath "$repo_dir"
}

# return 1 = no repo, or repo is wrong
# return 2 = yes repo
# Checked by origin.
git__validate_repo() {
	debug "$*"
	local repo_url=${1:?}
	local repo_name=${2:?}
	local repo_dir
	repo_dir="$(const__get_repo_dir "$repo_name")"

	if [[ ! -d "$repo_dir" ]]; then
		warn "Git::Validate Repo. Failed validation (repo does not exist, expected '$repo_dir')"
		return 1
	fi

	if [[ "$(git__get_origin "$repo_dir")" != "$repo_url" ]]; then
		warn "Git::Validate Repo. Failed validation (expected origin '$repo_url', got '$(git__get_origin "$repo_dir")')"
		return 1
	fi

	return 0
}

git__get_origin() {
	debug "$*"
	local repo_dir=${1:?}

	git -C "$repo_dir" remote get-url origin 2>/dev/null || true
}

git__get_repo_name() {
	debug "$*"
	local repo_url=${1:?}

	local name
	name="$(basename "$repo_url" .git)"

	if [[ -z "$name" ]]; then
		warn "Could not extract repository name from URL: $repo_url"
		return 1
	fi

	echo "$name"
}

git__create_workspace_worktree_idempotent() {
	debug "$*"
	local source_repo_dir="$1"
	local destination_worktree_dir="$2"
	local branch_name="$3"

	if git__check_worktree_exists "$source_repo_dir" "$destination_worktree_dir"; then
		debug "Git worktree already exists" "$source_repo_dir" to "$destination_worktree_dir"
		return 0
	fi

	# Try creating with new branch first; if branch already exists, use it directly
	if ! git -C "$source_repo_dir" worktree add -b "$branch_name" "$destination_worktree_dir" 2>/dev/null; then
		git -C "$source_repo_dir" worktree add "$destination_worktree_dir" "$branch_name"
	fi
}

git__remove_workspace_worktree_idempotent() {
	debug "$*"
	local source_repo_dir="$1"
	local destination_worktree_dir="$2"

	if ! git__check_worktree_exists "$source_repo_dir" "$destination_worktree_dir"; then
		debug "Git worktree does not exist" "$source_repo_dir" to "$destination_worktree_dir"
		return 0
	fi

	if ! git -C "$source_repo_dir" worktree remove --force "$destination_worktree_dir"; then
		warn "Failed to remove git worktree at '$destination_worktree_dir'"
		return 1
	fi
}

git__check_worktree_exists() {
	debug "$*"
	local source_repo_dir="$1"
	local destination_worktree_dir="$2"

	if [[ -z "$(git -C "$source_repo_dir" worktree list --porcelain | grep -e "^worktree " | cut -f 2 -d ' ' | grep -Fx "$destination_worktree_dir")" ]]; then
		return 1
	else
		return 0
	fi
}

git__checkout_branch_on_worktree() {
	debug "$*"
	local destination_worktree_dir="$1"
	local checkout_branch_name="$2"

	if ! git -C "$destination_worktree_dir" checkout -b "$checkout_branch_name" 2>/dev/null && ! git -C "$destination_worktree_dir" checkout "$checkout_branch_name"; then
		warn "Failed to checkout branch $checkout_branch_name on $destination_worktree_dir"
		return 1
	fi
}

######################
##### Filesystem #####
######################

# Create workspace dir and return the path
fs__workspace_mkdir_idempotent() {
	debug "$*"
	local workspace_name="$1"

	if [[ -z "$workspace_name" ]]; then
		fatal "Workspace name is empty"
	fi

	local workspace_dir
	workspace_dir=$(fs__workspace_get_dir "$workspace_name")

	mkdir -p "$workspace_dir"
}

fs__workspace_get_repo_subtree_dir() {
	debug "$*"
	local workspace_name="$1"
	if [[ -z "$workspace_name" ]]; then
		fatal "Workspace name is empty"
	fi
	local repo_name="$2"
	if [[ -z "$repo_name" ]]; then
		fatal "Repo name is empty"
	fi

	echo "$(fs__workspace_get_dir "$workspace_name")/$repo_name"
}

fs__workspace_get_dir() {
	debug "$*"
	local workspace_name="$1"
	if [[ -z "$workspace_name" ]]; then
		fatal "Workspace name is empty"
	fi

	echo "$WORKSPACES_DIR/$workspace_name"
}

fs__safe_rm_rf() {
	debug "$*"
	local target="$1"
	local allowed_parent="$2"

	if [[ -z "$target" || "$target" == "/" ]]; then
		echo "[FATAL] Refusing to rm -rf empty or root path" >&2
		exit 1
	fi

	# Resolve paths (use -m to allow non-existent targets)
	local resolved
	resolved="$(realpath -m "$target" 2>/dev/null || echo "$target")"
	local resolved_parent
	resolved_parent="$(realpath "$allowed_parent" 2>/dev/null || echo "$allowed_parent")"

	if [[ "$resolved" != "$resolved_parent"/* ]]; then
		echo "[FATAL] Refusing to delete '$resolved' — not under '$resolved_parent'" >&2
		exit 1
	fi

	rm -rf "$resolved"
}

#############################
##### Dependency Checks #####
#############################

dependency__assert() {
	debug "$*"
	local dependency="$1"
	local error_message=${2:-"$dependency is not installed. Please install $dependency and try again."}
	if ! command -v "$dependency" &>/dev/null; then
		fatal "$error_message"
	fi
}

dependency__assert_git() {
	debug "$*"
	if env_is_macos; then
		dependency__assert "git" $'Git is required on macOS. Please install it with: \n brew install git \n and try again.'
	else
		dependency__assert "git"
	fi
}

dependency__assert_yq() {
	debug "$*"
	if env_is_macos; then
		dependency__assert "yq" $'yq is required on macOS. Please install it with: \n brew install yq \n and try again.'
	else
		dependency__assert "yq"
	fi
}

#################
##### Utils #####
#################

const__get_repo_dir() {
	local repo_name="$1"
	echo "$REPOS_DIR/$repo_name"
}

env_is_macos() {
	debug "$*"
	[[ "$(uname)" == "Darwin" ]]
}

env__get_caller_workspace() {
	if [[ "$PWD" == $WORKSPACES_DIR/* ]]; then
		local temp="${PWD#$WORKSPACES_DIR/}"
		echo "${temp%%/*}"
		return 0
	else
		return 1
	fi
}

validate_name() {
	local name="$1"
	local label="${2:-name}"
	if [[ ! "$name" =~ ^[a-zA-Z0-9/_-]*$ ]] || [[ $(echo "$name" | tr -cd '/' | wc -c) -gt 1 ]]; then
		fatal "Invalid $label: '$name'. Only alphanumeric characters, dashes, underscores, and at most one slash are allowed."
	fi
}

print_table_vertically() {
	debug "$*"
	local n_cols=${1:?}
	shift

	local n_cells="$#"
	local cells=("$@")

	if [[ $n_cells -eq 0 ]]; then
		return 0
	fi

	local n_rows=$((n_cells / n_cols))
	local leftover_cells=$((n_cells % n_cols))

	if [[ $leftover_cells -ne 0 ]]; then
		warn "Table has leftover cells: $leftover_cells"
		return 1
	fi

	# We can just transpose and print horizontally
	local transposed_cells=()

	for ((r = 0; r < $n_rows; r++)); do
		for ((c = 0; c < $n_cols; c++)); do
			local cell_idx=$((c * n_rows + r))
			transposed_cells+=("${cells[$cell_idx]}")
		done
	done

	print_table_horizontally $n_cols "${transposed_cells[@]+"${transposed_cells[@]}"}"

}

print_table_horizontally() {
	debug "$*"
	local n_cols=${1:?}
	shift
	local cells=("$@")
	local n_rows=$((${#cells[@]} / $n_cols))
	local leftover_cells=$((${#cells[@]} % $n_cols))

	if [[ $leftover_cells -ne 0 ]]; then
		warn "Table has leftover cells: $leftover_cells"
		return 1
	fi

	local column_widths=()
	for ((i = 0; i < $n_cols; i++)); do
		column_widths+=(0)
	done

	for ((r = 0; r < $n_rows; r++)); do
		for ((c = 0; c < $n_cols; c++)); do
			local curr_width=${column_widths[c]}
			local new_width=${#cells[$((r * n_cols + c))]}
			column_widths[c]=$((new_width > curr_width ? new_width : curr_width))
		done
	done

	local fmtstr=""
	for ((c = 0; c < $n_cols; c++)); do
		fmtstr+=" %-${column_widths[c]}s "
	done

	printf "\n"
	for ((r = 0; r < $n_rows; r++)); do
		if [[ r -eq 0 ]]; then
			printf "${BOLD}$fmtstr\n${RESET}" "${cells[@]:$((r * n_cols)):$n_cols}"
		else
			printf "$fmtstr\n" "${cells[@]:$((r * n_cols)):$n_cols}"
		fi
	done
	printf "\n"
}

main "$@"
