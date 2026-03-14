#!/usr/bin/env bash
set -euo pipefail

## Control Sequences ##

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

## Project Variables ##

PROJ_DIR="${PROJ_DIR:-$HOME/.ows}"
REPOS_DIR="${REPOS_DIR:-$PROJ_DIR/repos}"
WORKSPACES_DIR="${WORKSPACES_DIR:-$PROJ_DIR/workspaces}"

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
	local line=${1:?}
	shift
	echo -e "[DEBUG] $0:$line $*" >&2
}

debug_stack_trace() {
	if [[ -z ${DEBUG:-} ]]; then
		return 0
	fi

	echo "Stack trace:"
	local i
	for i in "${!FUNCNAME[@]}"; do
		# skip stack_trace itself
		[[ $i -eq 0 ]] && continue
		echo "  [$i] ${FUNCNAME[$i]}() ${BASH_SOURCE[$i]}:${BASH_LINENO[$i-1]}"
	done
}

main() {
	debug $LINENO "[main]" "$*"
	dependency__assert_git
	dependency__assert_docker
	dependency__assert_yq

	local cmd="${1:-}"

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
	debug $LINENO "[cmd__repo]" "$*"

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
	*)
		echo "Unknown sub-command: ${1:-}. Available sub-commands: add, remove, list, exec"
		exit 1
		;;
	esac
}

# Functions as both "create workspace" and "add repo to workspace"
cmd__workspace__add() {
	local curr_workspace
	if ! config__workspace__exists "${1:-}" && curr_workspace=$(env__get_caller_workspace) ; then
		info "Workspace detected as $curr_workspace"
		set -- "$curr_workspace" "$@"
	fi

	local workspace_name="${1:?"workspace name is required"}"
	shift
	local workspace_repos=("$@")

	workspace__add $workspace_name "${workspace_repos[@]}"
}

cmd__workspace__delete() {
	local curr_workspace
	if ! config__workspace__exists "${1:-}" && curr_workspace=$(env__get_caller_workspace) ; then
		info "Workspace detected as $curr_workspace"
		set -- "$curr_workspace" "$@"
	fi

	local workspace_name="${1:?"workspace name is required"}"
    workspace__delete "$workspace_name"
}

cmd__workspace__list() {
    workspace__list
}

cmd__workspace__remove_repo() {
	local curr_workspace
	if ! config__workspace__exists "${1:-}" && curr_workspace=$(env__get_caller_workspace) ; then
		info "Workspace detected as $curr_workspace"
		set -- "$curr_workspace" "$@"
	fi

    local workspace_name="${1:?"workspace name is required"}"
	shift
	local repos_to_remove=("$@")

    if [[ ${#repos_to_remove[@]} -eq 0 ]]; then
        warn "No repos to remove from workspace $workspace_name"
        return 0
    fi
    
    workspace__remove_repos "$workspace_name" "${repos_to_remove[@]}"
}

cmd__workspace__exec() {
	local curr_workspace
	if ! config__workspace__exists "${1:-}" && curr_workspace=$(env__get_caller_workspace) ; then
		info "Workspace detected as $curr_workspace"
		set -- "$curr_workspace" "$@"
	fi

    local workspace_name="${1:?"workspace name is required"}"
	shift
	local args=("$@")

	workspace__exec "$workspace_name" "${args[@]}"
}

####################
### Repositories ###
####################

cmd__repo() {
	debug $LINENO "[cmd__repo]" "$*"
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
	debug $LINENO "[cmd__repo__add]" "$*"
	local repo_url=$1
	local repo_name=${2:-}

	if [[ -z "$repo_name" ]] && ! repo_name_from_url=$(git__get_repo_name "$repo_url"); then
		warn "Failed to get repository name from URL: $repo_url"
		return 1
	fi

	local repo_name=${repo_name:-$repo_name_from_url}

	repo__add "$repo_url" "$repo_name"
}

cmd__repo__remove() {
	debug $LINENO "[cmd__repo__remove]" "$*"
	local repo_name=$1

	repo__remove "$repo_name"
}

cmd__repo__list() {
	debug $LINENO "[cmd__repo__list]" "$*"
	repo__validate_all
	local repos=($(config__repo__list))
	local cells=()

    # funny syntax to avoid throw on empty array
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
	debug $LINENO "[workspace__add]" "$*"
	workspace__validate_all
	repo__validate_all

	local workspace_name="$1"
	shift
	local workspace_repos=("$@")

    if ! config__workspace__create_idempotent "$workspace_name"; then
        warn "Failed to create workspace $workspace_name."
        return 1
    fi
	
	local workspace_dir=$(fs__workspace_mkdir "$workspace_name")

    for repo in "${workspace_repos[@]+"${workspace_repos[@]}"}"; do
        if [[ -z $repo ]]; then
            continue
        fi
        if ! config__workspace__add_repo_idempotent "$workspace_name" "$repo"; then
            warn "Failed to add repo $repo to workspace $workspace_name. Try again later."
            continue
        fi

		local repo_dir="$(config__repo__get_dir "$repo")"
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
	debug $LINENO "[workspace__delete]" "$*"
	workspace__validate_all
	local workspace_name="$1"

	local repos=($(config__workspace__get_repos "$workspace_name"))
	workspace__remove_repo "$workspace_name" "${repos[@]+"${repos[@]}"}"

	rm -rf "$(fs__workspace_get_dir "$workspace_name")"
    
    if ! config__workspace__delete_idempotent "$workspace_name"; then
        warn "Failed to delete workspace $workspace_name."
        return 1
    fi
}

workspace__list() {
	debug $LINENO "[workspace__list]" "$*"
	workspace__validate_all
	local workspaces=($(config__workspace__list))
	local cells=()

	for workspace in "${workspaces[@]+"${workspaces[@]}"}"; do
		if [[ -z "$workspace" ]]; then 
			continue
		fi
		local repos=($(config__workspace__get_repos "$workspace"))
		local cell=""
		for i in "${!repos[@]}"; do
			cell+="${repos[$i]}"
			if [[ i -lt $(( ${#repos[@]} - 1)) ]]; then
				cell+=", "
			fi
		done
		cells+=("$cell")
	done

	print_table_vertically 2 "workspace" "${workspaces[@]+"${workspaces[@]}"}" "repos" "${cells[@]+"${cells[@]}"}"
}

workspace__remove_repos() {
	debug $LINENO "[workspace__remove_repos]" "$*"
	workspace__validate_all
    local workspace_name="${1:?"workspace name is required"}"
	shift
	# we checked this in cmd__workspace__remove_repo, so guaranteed to have value
	local repos_to_remove=("$@")

	for repo in "${repos_to_remove[@]+"${repos_to_remove[@]}"}"; do
		local repo_dir="$(config__repo__get_dir "$repo")"
		local subtree_dir="$(fs__workspace_get_repo_subtree_dir "$workspace_name" "$repo")"
		git__remove_workspace_worktree_idempotent "$repo_dir" "$subtree_dir"

        if ! config__workspace__remove_repo_idempotent "$workspace_name" "$repo"; then
            warn "Failed to remove repo $repo from workspace $workspace_name"
        fi
    done
}

workspace__exec() {
	debug $LINENO "[workspace__exec]" "$*"
	workspace__validate_all

    local workspace_name="${1:?"workspace name is required"}"
	shift

	if ! config__workspace__exists "$workspace_name"; then
		warn "Workspace $workspace_name does not exist"
		return 1
	fi

	local workspace_dir="$WORKSPACES_DIR/$workspace_name"
	if [[ ! -d "$workspace_dir" ]]; then
		warn "Workspace directory $workspace_dir does not exist"
		return 1
	fi

	cd "$workspace_dir" && "$@"
}

workspace__validate_all() {
	debug $LINENO "[workspace__validate_all]" "$*"
	local workspaces=($(config__workspace__list))

	for workspace in "${workspaces[@]+"${workspaces[@]}"}"; do
		if [[ -z workspace ]]; then 
			continue
		fi
		workspace__validate "$workspace"
	done

	# TODO: delete workspaces and worktrees that aren't in the config anymore
}

workspace__validate() {
	debug $LINENO "[workspace__validate]" "$*"
	local workspace_name="$1"
	local workspace_dir="$(fs__workspace_get_dir "$workspace_name")"
	local repos=($(config__workspace__get_repos "$workspace"))
    
    fs__workspace_mkdir_idempotent "$workspace"

	for repo in "${repos[@]+"${repos[@]}"}"; do
		if [[ -z "$repo" ]]; then
			continue
		fi

		local repo_dir="$(config__repo__get_dir "$repo")"
		local subtree_dir=$(fs__workspace_get_repo_subtree_dir "$workspace_name" "$repo")
		local branch_name="$workspace"

		if ! git__create_workspace_worktree_idempotent "$repo_dir" "$subtree_dir" "$branch_name"; then
			warn "Failed to add git worktree of $repo to workspace $workspace. Maybe it already exists? Try again later."
			continue
		fi
	done
}

######################################
##### High-Level Repo Management #####
######################################

# Validate all repos.
repo__validate_all() {
	debug $LINENO "[repo__validate_all]" "$*"
	config__create_file_if_not_exist

	local repos=($(config__repo__list))
	for repo_name in "${repos[@]+"${repos[@]}"}"; do
        # Funny bash business for empty arrays
        if [[ -z $repo_name ]]; then
            continue
        fi

		repo__validate__restore_from_config "$repo_name"
	done
}

repo__validate__restore_from_config() {
	debug $LINENO "[repo__validate__restore_from_config]" "$*"
	local repo_name="$1"
	local repo_dir=$(config__repo__get_dir "$repo_name")
	local repo_originurl=$(config__repo__get_originurl "$repo_name")

	# 1. Try to reconstruct variables
	if [[ -z "$repo_dir" ]]; then
		repo_dir=${repo_dir:-"$REPOS_DIR/$repo_name"}
	fi
	if [[ -z "$repo_originurl" && -d "$repo_dir" ]]; then
		repo_originurl="$(git__get_origin "$repo_dir")"
	fi

	# 2. If origin url is no more, cannot be restored
	if [[ -z "$repo_originurl" ]]; then
		repo__remove "$repo_name"
	fi

	# 3. We add the repo back
	repo__add "$repo_originurl" "$repo_name" "$repo_dir" || true
}

repo__add() {
	debug $LINENO "[repo__add]" "$*"

	local repo_url=${1:?}
	local repo_name=${2:?}
	local repo_dir="${3:-$REPOS_DIR/$repo_name}"

	# Check if repo already exists with the same config — skip if so
	local existing_url=$(config__repo__get_originurl "$repo_name")
	local existing_dir=$(config__repo__get_dir "$repo_name")
	if [[ "$existing_url" == "$repo_url" && "$existing_dir" == "$repo_dir" ]]; then
		if git__validate_repo "$repo_url" "$repo_name"; then
			debug $LINENO "[repo__add]" "Repository $repo_name already exists with same config, skipping"
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
	debug $LINENO "[repo__remove]" "$*"

	local repo_name=${1:?}
	local repo_dir="$REPOS_DIR/$repo_name"

	# Remove directory if it exists
	if [[ -d "$repo_dir" ]]; then
		if ! rm -rf "$repo_dir"; then
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
	debug $LINENO "[config__workspace__create_idempotent]" "$*"
	config__create_file_if_not_exist

	local workspace_name="$1"

    if config__workspace__exists "$workspace_name"; then
        warn "Creating workspace $workspace_name: already exists"
        # Idempotent, so OK to return 0
        return 0
    fi

    yq -i ".workspaces.${workspace_name}.repos = []" "$CONFIG_FILE_PATH"
    if [ $? -ne 0 ]; then
        echo "Failed to create new workspace ${workspace_name}"
    fi
}

config__workspace__delete_idempotent() {
	debug $LINENO "[config__workspace__delete_idempotent]" "$*"
	config__create_file_if_not_exist

	local workspace_name="$1"

    if ! config__workspace__exists "$workspace_name"; then
        warn "Deleting workspace $workspace_name: already absent"
        return 0
    fi

    yq -i "del(.workspaces.${workspace_name})" "$CONFIG_FILE_PATH"
}

config__workspace__add_repo_idempotent() {
	debug $LINENO "[config__workspace__add]" "$*"
	config__create_file_if_not_exist
	local workspace_name="$1"
    local repo_name="$2"

    if config__workspace__has_repo "$workspace_name" "$repo_name"; then
        warn "Adding repo $repo_name to workspace $workspace_name: already exists"
        return 0
    fi

    yq -i ".workspaces.${workspace_name}.repos += [\"$repo_name\"]" "$CONFIG_FILE_PATH"
}

config__workspace__remove_repo_idempotent() {
	debug $LINENO "[config__workspace__add]" "$*"
	config__create_file_if_not_exist
	local workspace_name="$1"
    local repo_name="$2"

    if ! config__workspace__has_repo "$workspace_name" "$repo_name"; then
        warn "Removing repo $repo_name from workspace $workspace_name: does not exist"
        return 0
    fi

    yq -i "del(.workspaces.${workspace_name}.repos[] | select(. == \"$repo_name\"))" "$CONFIG_FILE_PATH"
}

config__workspace__exists() {
	debug $LINENO "[config__workspace__exists]" "$*"
	config__create_file_if_not_exist
	local workspace_name="$1"
	yq -e ".workspaces.${workspace_name}" "$CONFIG_FILE_PATH" &>/dev/null
}

config__workspace__has_repo() {
	debug $LINENO "[config__workspace__has_repo]" "$*"
	config__create_file_if_not_exist

	local workspace_name="$1"
	local repo_name="$2"
    local repos=($(config__workspace__get_repos "$workspace_name"))

    if [[ -n $(yq ".workspaces.${workspace_name}.repos[] | select(. == \"$repo_name\")" "$CONFIG_FILE_PATH") ]]; then
        return 0
    else
        return 1
    fi
}

config__workspace__list() {
	debug $LINENO "[config__workspace__list]" "$*"
	config__create_file_if_not_exist
	
    local return=$(yq '.workspaces | keys | .[]' "$CONFIG_FILE_PATH")

    if [[ return == "null" ]]; then
        echo ""
        return 0
    else
        echo $return
    fi
}

config__workspace__get_repos() {
	debug $LINENO "[config__workspace__get_repos]" "$*"
	config__create_file_if_not_exist

    local workspace="${1:?}"

    local return=$(yq ".workspaces.${workspace}.repos[]" "$CONFIG_FILE_PATH")

    if [[ return == "null" ]]; then
        echo ""
        return 0
    else
        echo $return
    fi
}


########################
### Yaml Repo Config ###
########################

config__repo__set() {
	debug $LINENO "[config__repo__set]" "$*"
	config__create_file_if_not_exist

	local repo_url=${1:?}
	local repo_name=${2:?}
	local repo_dir=${3:?}

	# yq eval ".repos += [{name: \"$repo_name\", url: \"$repo_url\"}]" -i "$config_path"
	yq -i ".repos.${repo_name} = {\"origin_url\": \"$repo_url\", \"dir\": \"$repo_dir\"}" "$CONFIG_FILE_PATH"
}

config__repo__remove_idempotent() {
	debug $LINENO "[config__repo__remove_idempotent]" "$*"
	config__create_file_if_not_exist
	local repo_name=${1:?}

	yq -i "del(.repos.${repo_name})" "$CONFIG_FILE_PATH"
}

config__repo__list() {
	debug $LINENO "[config__repo__list]" "$*"
	config__create_file_if_not_exist
	
    local return=$(yq '.repos | keys | .[]' "$CONFIG_FILE_PATH")

    if [[ return == "null" ]]; then
        echo ""
        return 0
    else
        echo $return
    fi
}

config__repo__get_dir() {
	debug $LINENO "[config__repo__get_dir]" "$*"
	config__create_file_if_not_exist
	local repo_name="${1:?}"

	local config_path="$CONFIG_FILE_PATH"
	local return=$(yq -r ".repos.${repo_name}.dir" "$config_path")
	if [[ "$return" == "null" ]]; then
		echo ""
	else
		echo "$return"
	fi
}

config__repo__get_originurl() {
	debug $LINENO "[config__repo__get_originurl]" "$*"
	config__create_file_if_not_exist
	local repo_name=${1:?}

	local return=$(yq -r ".repos.${repo_name}.origin_url" "$CONFIG_FILE_PATH")
	if [[ "$return" == "null" ]]; then
		echo ""
	else
		echo "$return"
	fi
}

config__create_file_if_not_exist() {
	if [[ ! -f "$CONFIG_FILE_PATH" ]]; then
		mkdir -p "$REPOS_DIR"
		touch "$CONFIG_FILE_PATH"
	fi
}

#######################
##### Git Facades #####
#######################

git__add_repo_idempotent() {
	debug $LINENO "[git__add_repo_idempotent]" "$*"
	local repo_url=${1:?}
	local repo_name=${2:?}
	local repo_dir="$(const__get_repo_dir "$repo_name")"

	if ! git__validate_repo "$repo_url" "$repo_name"; then
		warn "Pre-clone check: there is an issue with the repo. Clearing and re-cloning..."
		rm -rf "$repo_dir"
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
	debug $LINENO "[git__validate_repo]" "$*"
	local repo_url=${1:?}
	local repo_name=${2:?}
	local repo_dir="$(const__get_repo_dir "$repo_name")"

	if [[ ! -d "$repo_dir" ]]; then
		warn "Git::Validate Repo. Failed validation (repo does not exist, expected "$repo_dir")"
		return 1
	fi

	if [[ "$(git__get_origin "$repo_name")" != "$repo_url" ]]; then
		warn "Git::Validate Repo. Failed validation (expected origin "$repo_url", got $(git__get_origin "$repo_name"))"
		return 1
	fi

	return 0
}

git__get_origin() {
	debug $LINENO "[git__get_origin]" "$*"
	local repo_name=${1:?}
	local repo_dir="$(const__get_repo_dir "$repo_name")"

	git -C "$repo_dir" remote get-url origin
}

git__get_repo_name() {
	debug $LINENO "[git__get_repo_name]" "$*"
	local repo_url=${1:?}

	if [[ "$repo_url" != *.git ]]; then
		warn "Invalid repository URL: $repo_url. Please provide a valid Git repository URL."
		return 1
	fi

	basename "$repo_url" .git
}

git__create_workspace_worktree_idempotent() {
	debug $LINENO "[git__create_workspace_worktree_idempotent]" "$*"
	local source_repo_dir="$1"
	local destination_worktree_dir="$2"
	local branch_name="$3"

	if git__check_worktree_exists "$source_repo_dir" "$destination_worktree_dir"; then
		debug $LINENO "[git__create_workspace_worktree_idempotent]" "Git worktree already exists" "$source_repo_dir" to "$destination_worktree_dir"
		return 0;
	fi

	git -C "$source_repo_dir" worktree add -b "$branch_name" "$destination_worktree_dir"
}

git__remove_workspace_worktree_idempotent() {
	debug $LINENO "[git__create_workspace_worktree_idempotent]" "$*"
	local source_repo_dir="$1"
	local destination_worktree_dir="$2"

	if ! git__check_worktree_exists "$source_repo_dir" "$destination_worktree_dir"; then
		debug $LINENO "[git__create_workspace_worktree_idempotent]" "Git worktree already exists" "$source_repo_dir" to "$destination_worktree_dir"
		return 0;
	fi

    git -C "$repo_dir" worktree remove --force "$subtree_dir" 2>/dev/null
}

git__check_worktree_exists() {
	debug $LINENO "[git__check_worktree_exists]" "$*"
	local source_repo_dir="$1"
	local destination_worktree_dir="$2"

	if [[ -z "$(git -C "$source_repo_dir" worktree list --porcelain | grep -e "^worktree " | cut -f 2 -d ' ' | grep -Fx "$destination_worktree_dir" )" ]]; then
		return 1
	else
		return 0
	fi
}


######################
##### Filesystem #####
######################

# Create workspace dir and return the path
fs__workspace_mkdir_idempotent() {
	debug $LINENO "[fs__workspace_mkdir_idempotent]" "$*"
	local workspace_name="$1"

	if [[ -z "$workspace_name" ]]; then
		fatal "Workspace name is empty"
	fi

	local workspace_dir=$(fs__workspace_get_dir "$workspace_name")

	mkdir -p "$workspace_dir" &> /dev/null
}

fs__workspace_get_repo_subtree_dir() {
	debug $LINENO "[fs__workspace_get_dir]" "$*"
    local workspace_name="$1"
	if [[ -z "$workspace_name" ]]; then
		fatal "Workspace name is empty"
	fi
    local repo_name="$2"
	if [[ -z "$repo_name" ]]; then
		fatal "Repo name is empty"
	fi

    echo "$(fs__workspace_get_dir $workspace_name)/$repo_name"
}

fs__workspace_get_dir() {
	debug $LINENO "[fs__workspace_get_dir]" "$*"
    local workspace_name="$1"
	if [[ -z "$workspace_name" ]]; then
		fatal "Workspace name is empty"
	fi

    echo "$WORKSPACES_DIR/$workspace_name"
}


#############################
##### Dependency Checks #####
#############################

dependency__assert() {
	debug $LINENO "[dependency__assert]" "$*"
	local dependency=$1
	local error_message=${2:-"$dependency is not installed. Please install $dependency and try again."}
	if ! command -v $dependency &>/dev/null; then
		warn "$error_message"
		exit 1
	fi
}

dependency__assert_git() {
	debug $LINENO "[dependency__assert_git]" "$*"
	if env_is_macos; then
		dependency__assert "git" $'Git is required on macOS. Please install it with: \n brew install git \n and try again.'
	else
		dependency__assert "git"
	fi
}

dependency__assert_docker() {
	debug $LINENO "[dependency__assert_docker]" "$*"
	dependency__assert "docker"
}

dependency__assert_yq() {
	debug $LINENO "[dependency__assert_yq]" "$*"
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
	debug $LINENO "[env_is_macos]" "$*"
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

print_table_vertically() {
	debug $LINENO "[print_table_vertically]" "$*"
	local n_cols=${1:?}
	shift

	local n_cells="$#"
	local cells=("$@")

	local n_rows=$(( n_cells / n_cols ))
	local leftover_cells=$(( n_cells % n_rows ))

	if [[ $leftover_cells -ne 0 ]]; then
		warn "Table has leftover cells: $leftover_cells"
		return 1
	fi

	# We can just transpose and print horizontally
	local transposed_cells=()

	for ((r=0; r < $n_rows; r++)); do
		for ((c=0; c < $n_cols; c++)); do
			local cell_idx=$(( c * n_rows + r ))
			transposed_cells+=("${cells[$cell_idx]}")
		done
	done

	print_table_horizontally $n_cols "${transposed_cells[@]+"${transposed_cells[@]}"}"

}

print_table_horizontally() {
	debug $LINENO "[print_table_horizontally]" "$*"
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
