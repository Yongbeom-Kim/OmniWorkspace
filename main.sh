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
WORKSPACES_DIR="${REPOS_DIR:-$PROJ_DIR/repos}"

trap 'echo "Error on line $LINENO in ${FUNCNAME[0]:-main}" >&2; debug_stack_trace' ERR

warn() {
	echo -e "[WARN] $*" >&2
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
	*)
		echo "Unknown sub-command: ${1:-}. Available sub-commands: add, remove, list"
		exit 1
		;;
	esac
}

cmd__workspace__add() {
	local workspace_name="${1:?"workspace name is required"}"
	shift
	local workspace_repos=("$@")

	workspace__add $workspace_name "${workspace_repos[@]}"
}

cmd__workspace__list() {
    workspace__list
}
# remove
# info
# add_repo
# remove_repo

####################
### Repositories ###
####################

cmd__repo() {
	debug $LINENO "[cmd__repo]" "$*"
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
	local repo_name

	if ! repo_name=$(git__get_repo_name "$repo_url"); then
		warn "Failed to get repository name from URL: $repo_url"
		return 1
	fi

	local repo_alias=${2:-$repo_name}

	repo__add "$repo_url" "$repo_alias"
}

cmd__repo__remove() {
	debug $LINENO "[cmd__repo__remove]" "$*"
	local repo_alias=$1

	repo__remove "$repo_alias"
}

cmd__repo__list() {
	debug $LINENO "[cmd__repo__list]" "$*"
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
	local workspace_name="$1"
	shift
	local workspace_repos=("$@")

    if ! config__workspace__create_idempotent "$workspace_name"; then
        warn "Failed to create workspace $workspace_name."
        return 1
    fi

    for repo in "${workspace_repos[@]+"${workspace_repos[@]}"}"; do
        if [[ -z $repo ]]; then
            continue
        fi
        if ! config__workspace__add_repo_idempotent "$workspace_name" "$repo"; then
            warn "Failed to add repo $repo to workspace $workspace_name."
            return 1
        fi

        echo "Successfully added repo $repo to workspace $workspace_name."
    done

}

workspace__list() {
	debug $LINENO "[workspace__list]" "$*"
	local workspaces=($(config__workspace__list))
	local cells=()

	for workspace in "${workspaces[@]+"${workspaces[@]}"}"; do
		if [[ -z workspace ]]; then 
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

######################################
##### High-Level Repo Management #####
######################################

repo__add() {
	debug $LINENO "[repo__add]" "$*"
	repo__validate_all

	local repo_url=${1:?}
	local repo_alias=${2:?}
	local repo_dir="$REPOS_DIR/$repo_alias"

	# Configs are always the source of truth, so we always add to config first.
	if ! config__repo__set "$repo_url" "$repo_alias" "$repo_dir"; then
		warn "Failed to add repository $repo_alias to config."
		return 1
	fi

	if ! repo_dir=$(git__add_repo "$repo_url" "$repo_alias"); then
		config__repo__remove "$repo_alias"
		warn "Failed to add repository $repo_alias. Parameters: $repo_url, $repo_alias"
		return 1
	fi

	echo "Repository $repo_alias added successfully."
}

repo__remove() {
	debug $LINENO "[repo__remove]" "$*"
	repo__validate_all

	local repo_alias=${1:?}
	local repo_dir="$REPOS_DIR/$repo_alias"

	# Configs are always the source of truth, so we always remove from config first.
	if ! rm -rf "$repo_dir"; then
		warn "Failed to remove repository $repo_alias."
	fi

	if ! [[ -d "$repo_dir" ]]; then
		warn "Repository $repo_alias does not exist."
	fi

	if ! config__repo__remove "$repo_alias"; then
		warn "Failed to remove repository $repo_alias from config."
	fi

	echo "Repository $repo_alias removed successfully."
}

# Validate all repos.
repo__validate_all() {
	debug $LINENO "[repo__validate_all]" "$*"
	config__create_file_if_not_exist

	# 1. Validate repo config
	config__repo__list | while read -r repo_alias; do
        # Funny bash business AGAIN for arrays
        if [[ -z $repo_alias ]]; then
            continue
        fi

		local repo_dir=$(config__repo__get_dir "$repo_alias")
		# 1. if no repo dir, remove from config
		if [[ -z "$repo_dir" ]]; then
			warn "Repository $repo_alias does not exist. Removing from config."
			config__repo__remove "$repo_alias"
		fi

		# 2. if no origin url, try to get from repo dir
		local repo_originurl=$(config__repo__get_originurl "$repo_alias")
		if [[ -z "$repo_originurl" ]]; then
			local origin_url
			if ! origin_url=$(git__get_origin "$repo_dir"); then
				warn "Failed to get origin URL for repository $repo_alias. Removing from config."
				config__repo__remove "$repo_alias"
				continue
			fi

			if ! config__repo__set "$origin_url" "$repo_alias" "$repo_dir"; then
				warn "Failed to set origin URL for repository $repo_alias. Removing from config."
				config__repo__remove "$repo_alias"
				continue
			fi
		fi
	done

	# 2. Validate filesystem (remove all that do not match repo)
	find "$REPOS_DIR" -mindepth 1 -maxdepth 1 -type d | while read -r fs_dir; do
		local found=0
		local repo_alias_list=($(config__repo__list))
		for repo_alias in "${repo_alias_list[@]}"; do
			local config_dir=$(config__repo__get_dir "$repo_alias")
			if [[ "$config_dir" == "$fs_dir" ]]; then # also: != → ==
				found=1
				break
			fi
		done

		if [[ "$found" -eq 0 ]]; then
			warn "Repository $fs_dir does not exist in config. Removing."
			rm -rf "$fs_dir"
			continue
		fi

		# update config
		if ! config__repo__set "$(git__get_origin "$fs_dir")" "$repo_alias" "$fs_dir"; then
			warn "Failed to update config for repository $repo_alias. Parameters: $(git__get_origin "$fs_dir"), $repo_alias, $fs_dir"
		fi
	done

}

###############################
##### Yaml Configurations #####
###############################

CONFIG_FILE_PATH="$PROJ_DIR/config.yaml"

config__workspace__create_idempotent() {
	debug $LINENO "[config__workspace__add]" "$*"
	config__create_file_if_not_exist

	local workspace_name="$1"

    if config__workspace__exists "$workspace_name"; then
        warn "Creating workspace $workspace_name: already exists"
        return 0
    fi

    yq -i ".workspaces.${workspace_name}.repos = []" "$CONFIG_FILE_PATH"
    if [ $? -ne 0 ]; then
        echo "Failed to create new workspace ${workspace_name}"
    fi

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

config__workspace__exists() {
	debug $LINENO "[config__workspace__exists]" "$*"
	config__create_file_if_not_exist
	local workspace_name="$1"
	yq -e ".workspaces.${workspace_name}" "$CONFIG_FILE_PATH" &>/dev/null
}

config__workspace__has_repo() {
	debug $LINENO "[config__workspace__exists]" "$*"
	config__create_file_if_not_exist

	local workspace_name="$1"
	local repo_name="$2"
    local repos=($(config__workspace__get_repos "$workspace_name"))

    debug $LINENO TEST_repos "${repos[@]+"${repos[@]}"}"

    for repo in "${repos[@]+"${repos[@]}"}"; do
    debug $LINENO TEST repo_name repo "$repo_name" "$repo"
        if [[ "$repo_name" == "$repo" ]]; then
            return 0
        fi
    done

    return 1
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

config__repo__set() {
	debug $LINENO "[config__repo__set]" "$*"
	config__create_file_if_not_exist

	local repo_url=${1:?}
	local repo_alias=${2:?}
	local repo_dir=${3:?}

	# yq eval ".repos += [{name: \"$repo_alias\", url: \"$repo_url\"}]" -i "$config_path"
	yq -i ".repos.${repo_alias} = {\"origin_url\": \"$repo_url\", \"dir\": \"$repo_dir\"}" "$CONFIG_FILE_PATH"
}

config__repo__remove() {
	debug $LINENO "[config__repo__remove]" "$*"
	config__create_file_if_not_exist
	local repo_alias=${1:?}

	yq -i "del(.repos.${repo_alias})" "$CONFIG_FILE_PATH"
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
    debug_stack_trace
	local repo_alias=${1:?}

	local config_path="$CONFIG_FILE_PATH"
	local return=$(yq -r ".repos.${repo_alias}.dir" "$config_path")
	if [[ "$return" == "null" ]]; then
		echo ""
	else
		echo "$return"
	fi
}

config__repo__get_originurl() {
	debug $LINENO "[config__repo__get_originurl]" "$*"
	config__create_file_if_not_exist
	local repo_alias=${1:?}

	local return=$(yq -r ".repos.${repo_alias}.origin_url" "$CONFIG_FILE_PATH")
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

git__add_repo() {
	debug $LINENO "[git__add_repo]" "$*"
	local repo_url=${1:?}
	local repo_alias=${2:?}

	local repo_dir="$REPOS_DIR/$repo_alias"
	if [ -d "$repo_dir" ]; then
		warn "Repository $repo_alias already exists. Please choose a different alias."
		return 1
	fi

	if ! git clone "$repo_url" "$repo_dir"; then
		warn "Failed to clone repository $repo_alias."
		return 1
	fi

	realpath "$repo_dir"
}

git__get_origin() {
	debug $LINENO "[git__get_origin]" "$*"
	local repo_dir=${1:?}

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

env_is_macos() {
	debug $LINENO "[env_is_macos]" "$*"
	[[ "$(uname)" == "Darwin" ]]
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