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

#########################
### Project Variables ###
#########################

SCRIPT_NAME=$(basename "$0")
PROJ_DIR="${PROJ_DIR:-$HOME/.ows}"
REPOS_DIR="${REPOS_DIR:-$PROJ_DIR/repos}"
WORKSPACES_DIR="${WORKSPACES_DIR:-$PROJ_DIR/workspaces}"
CONFIG_FILE_PATH="$PROJ_DIR/config.yaml"
CONFIG_FILE_LOCK_DIR_PATH="$PROJ_DIR/config.lock" # mkdir as lock

GIT_WORKTREE_ALREADY_EXISTS_RETURN_CODE=42 # Arbitrary; avoids bash-reserved ranges (1-2, 126-165+)

##########################
### Object definitions ###
##########################

# repos: {
#   "<repo_name>": {
#       "origin_url": "<origin URL>"
#       "dir": "<repo directory path>"
#       "post-copy-hook": "<some bash script>"
#   }
# }
REPO_KEY="repos"
REPO_ORIGINURL_KEY="origin_url"
REPO_DIRECTORY_KEY="dir"
REPO_POST_COPY_HOOK_KEY="post-copy-hook"
REPO_POST_COPY_HOOK_DEFAULT_VALUE=$'#!/bin/bash\n# Even if there is a shebang here, it is a lie. All scripts are run with bash.\n# Run the following script after cloning the repo:\n\n'

# workspaces: {
#   "<workspace_name>": {
#       "repos": ["<repo_name>", ...]
#       "branch": "<branch_name>"
#       "dir": "<workspace directory path>"
#       "layer": "<layer_name>" | null
#   }
# }
WORKSPACE_KEY="workspaces"
WORKSPACE_REPOS_KEY="repos"
WORKSPACE_BRANCH_KEY="branch"
WORKSPACE_DIRECTORY_KEY="dir"
WORKSPACE_LAYER_KEY="layer"

# layer: {
# 	"<layer_name>": {
#		"files": [
# 			{
# 				"path": "<relative_path>",
# 				"contents": "<file_contents>",
# 			}
# 		]
# 	}
# }
LAYER_KEY="layer"
LAYER_DESCRIPTION_KEY="description"
LAYER_FILES_KEY="files"
LAYER_FILE_RELATIVE_PATH_KEY="path"
LAYER_FILE_CONTENTS_KEY="contents"

# global: {
#   "editor": "<editor command>"
# }
GLOBAL_KEY="global"
GLOBAL_EDITOR_KEY="editor"
GLOBAL_EDITOR_DEFAULT_VALUE="vi"

# TODO: may cause crash when sourcing in zshrc or bashrc, but it is OK for now.
# Validate that critical directories are absolute paths under $HOME
CRITICAL_DIRS=("$PROJ_DIR" "$REPOS_DIR" "$WORKSPACES_DIR")
for _dir_var in "${CRITICAL_DIRS[@]}"; do
	if [[ "${_dir_var}" != "$HOME"/* ]]; then
		echo "[FATAL] $_dir_var must be under \$HOME ($HOME), got '${_dir_var}'" >&2
		exit 1
	fi
done
unset _dir_var

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

#######################
##### ENTRY POINT #####
#######################

main() {
	local USAGE="

Usage:
    $SCRIPT_NAME <command> [args]

Commands:
    workspace (ws, w, wsp)    Manage workspaces
    workspaces (wss)          List all workspaces
    repo (r)                  Manage repositories
    repos (rs)                List all repositories

Shortcuts:
    exec <name> <command>     Shortcut for 'workspace exec'
    checkout (co) <name> <b>  Shortcut for 'workspace checkout'
    cd <name>                 Shortcut for 'workspace cd'
    layer (l)                 Shortcut for 'workspace layer'

Setup:
    install                   Install bash completions

Maintenance:
    update                    Update ows to the latest version
"
	fs__acquire_lock
	trap 'debug "Error on line $LINENO in ${FUNCNAME[0]:-main}"; debug_stack_trace; fs__release_lock' ERR EXIT SIGINT SIGTERM

	debug "$*"

	local cmd="${1:-}"

	if [[ -z "$cmd" ]]; then
		fatal "Error: command is required.$USAGE"
	fi

	if [[ "$cmd" == "update" ]]; then
		shift
		cmd__update "$@"
		return $?
	fi

	dependency__assert_git
	dependency__assert_yq

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
	"exec")
		shift
		cmd__workspace__exec "$@"
		;;
	"checkout" | "co")
		shift
		cmd__workspace__checkout "$@"
		;;
	"cd")
		shift
		cmd__workspace__cd "$@"
		;;
	"layer" | "l")
		shift
		cmd__layer "$@"
		;;
	"install")
		shift
		cmd__completions__install "$@"
		;;
	*)
		fatal "Error: unknown command '$cmd'.$USAGE"
		;;
	esac
}

####################################
##### High-Level User Commands #####
####################################

####################
### Workspaces ###
####################

# Completions in completion__bash_workspace
cmd__workspace() {
	local USAGE="

Usage:
    $SCRIPT_NAME workspace <sub-command> [args]

Sub-commands:
    add <name> [repos...]          Create a workspace or add repos to it
    create <name> [repos...]       Alias for add
    add-repo <name> [repos...]     Alias for add
    remove-repo <name> <repos...>  Remove repos from a workspace
    delete <name>                  Delete a workspace
    list                           List all workspaces
    exec <name> <command>          Run a command in each repo of a workspace
    checkout <name> <branch>       Check out a branch across all repos
    pull <name>                    Pull latest changes for all repos
    reset-hard-to-origin <name>    Fetch and hard reset all repos to upstream
    run-hooks <name>               Run post-copy hooks for all repos
    cd <name>                      Print the workspace directory path
    layer <sub-command>            Manage workspace layers
"

	debug "$*"

	case ${1:-} in
	"layer")
		shift
		cmd__layer "$@"
		;;
	"add" | "add-repo" | "create")
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
	"pull")
		shift
		cmd__workspace__pull "$@"
		;;
	"reset-hard-to-origin")
		shift
		cmd__workspace__reset_hard_to_origin "$@"
		;;
	"run-hooks")
		shift
		cmd__workspace__run_hooks "$@"
		;;
	"cd")
		shift
		cmd__workspace__cd "$@"
		;;
	*)
		fatal "Error: unknown sub-command '${1:-}'.$USAGE"
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
	for repo_name in "${workspace_repos[@]+"${workspace_repos[@]}"}"; do
		validate_name "$repo_name" "repo name"
	done

	workspace__add "$workspace_name" "${workspace_repos[@]+"${workspace_repos[@]}"}"
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

cmd__workspace__cd() {
	local USAGE="

Usage (workspace cd):
    $SCRIPT_NAME workspace cd <workspace_name>
    $SCRIPT_NAME cd <workspace_name>

Opens a new shell in the workspace directory.
Type 'exit' or press Ctrl+D to return to the previous shell.
"

	local curr_workspace
	if ! config__workspace__exists "${1:-}" && curr_workspace=$(env__get_caller_workspace); then
		info "Workspace detected as $curr_workspace"
		set -- "$curr_workspace" "$@"
	fi

	local workspace_name="${1:?"Error: workspace name is required.$USAGE"}"
	validate_name "$workspace_name" "workspace name"

	workspace__cd "$workspace_name"
}

cmd__workspace__pull() {
	local USAGE="

Usage (workspace pull):
    $SCRIPT_NAME workspace pull <workspace_name>
    $SCRIPT_NAME pull <workspace_name>

Pulls latest changes for all repos in the workspace.
"

	local curr_workspace
	if ! config__workspace__exists "${1:-}" && curr_workspace=$(env__get_caller_workspace); then
		info "Workspace detected as $curr_workspace"
		set -- "$curr_workspace" "$@"
	fi

	local workspace_name="${1:?"Error: workspace name is required.$USAGE"}"
	validate_name "$workspace_name" "workspace name"

	workspace__pull "$workspace_name"
}

cmd__workspace__reset_hard_to_origin() {
	local USAGE="

Usage (workspace reset-hard-to-origin):
    $SCRIPT_NAME workspace reset-hard-to-origin <workspace_name>

Fetches and hard resets all repos in the workspace to the upstream branch.
"

	local curr_workspace
	if ! config__workspace__exists "${1:-}" && curr_workspace=$(env__get_caller_workspace); then
		info "Workspace detected as $curr_workspace"
		set -- "$curr_workspace" "$@"
	fi

	local workspace_name="${1:?"Error: workspace name is required.$USAGE"}"
	validate_name "$workspace_name" "workspace name"

	workspace__reset_hard_to_origin "$workspace_name"
}

cmd__workspace__run_hooks() {
	local USAGE="

Usage (workspace run-hooks):
    $SCRIPT_NAME workspace run-hooks <workspace_name>

Runs the post-copy hook for each repo in the workspace that has one configured.
"

	local curr_workspace
	if ! config__workspace__exists "${1:-}" && curr_workspace=$(env__get_caller_workspace); then
		info "Workspace detected as $curr_workspace"
		set -- "$curr_workspace" "$@"
	fi

	local workspace_name="${1:?"Error: workspace name is required.$USAGE"}"
	validate_name "$workspace_name" "workspace name"

	workspace__run_hooks "$workspace_name"
}

################
### Layers ###
################

# Completions in completion__bash_layer
cmd__layer() {
	local USAGE="

Usage:
    $SCRIPT_NAME layer <sub-command> [args]
    $SCRIPT_NAME workspace layer <sub-command> [args]

Sub-commands:
    save <workspace> [<layer_name>] [--desc \"description\"]
                                    Save workspace layer files to config
    load <workspace> <layer_name>   Load layer files from config into workspace
    list                            List all saved layers
    set-description (set-desc) <layer_name> \"description\"
                                    Set description for an existing layer
    delete <layer_name>             Delete a saved layer
"

	debug "$*"

	case ${1:-} in
	"save")
		shift
		cmd__layer__save "$@"
		;;
	"load")
		shift
		cmd__layer__load "$@"
		;;
	"list")
		shift
		cmd__layer__list "$@"
		;;
	"delete")
		shift
		cmd__layer__delete "$@"
		;;
	"set-description" | "set-desc")
		shift
		cmd__layer__set_description "$@"
		;;
	*)
		fatal "Error: unknown sub-command '${1:-}'.$USAGE"
		;;
	esac
}

cmd__layer__save() {
	local USAGE="

Usage (layer save):
    $SCRIPT_NAME layer save <workspace_name> [<layer_name>] [--desc|--description \"description\"]

If <layer_name> is omitted, the workspace's linked layer is used.
"

	debug "$*"

	# Strip --desc/--description flag before positional arg parsing
	local desc_flag=""
	local clean_args=()
	while [[ $# -gt 0 ]]; do
		case "$1" in
		"--desc" | "--description")
			desc_flag="${2:?"Error: --desc requires a value.$USAGE"}"
			shift 2
			;;
		*)
			clean_args+=("$1")
			shift
			;;
		esac
	done
	set -- "${clean_args[@]+"${clean_args[@]}"}"

	local curr_workspace
	if ! config__workspace__exists "${1:-}" && curr_workspace=$(env__get_caller_workspace); then
		info "Workspace detected as $curr_workspace"
		set -- "$curr_workspace" "$@"
	fi

	local workspace_name="${1:?"Error: workspace name is required.$USAGE"}"
	validate_name "$workspace_name" "workspace name"

	local layer_name="${2:-}"
	if [[ -z "$layer_name" ]]; then
		local ws_obj
		ws_obj=$(config__workspace__get "$workspace_name")
		layer_name=$(config__workspace__obj_get_layer "$ws_obj")
		if [[ -z "$layer_name" ]]; then
			fatal "Error: no layer linked to workspace '$workspace_name'. Please specify a layer name.$USAGE"
		fi
	else
		validate_name "$layer_name" "layer name"
	fi

	layer__save "$workspace_name" "$layer_name" "$desc_flag"
}

cmd__layer__load() {
	local USAGE="

Usage (layer load):
    $SCRIPT_NAME layer load <workspace_name> [<layer_name>]

If <layer_name> is omitted, the workspace's linked layer is used.
"

	debug "$*"

	local curr_workspace
	if ! config__workspace__exists "${1:-}" && curr_workspace=$(env__get_caller_workspace); then
		info "Workspace detected as $curr_workspace"
		set -- "$curr_workspace" "$@"
	fi

	local workspace_name="${1:?"Error: workspace name is required.$USAGE"}"
	validate_name "$workspace_name" "workspace name"

	local layer_name="${2:-}"
	if [[ -z "$layer_name" ]]; then
		local ws_obj
		ws_obj=$(config__workspace__get "$workspace_name")
		layer_name=$(config__workspace__obj_get_layer "$ws_obj")
		if [[ -z "$layer_name" ]]; then
			fatal "Error: no layer linked to workspace '$workspace_name'. Please specify a layer name.$USAGE"
		fi
	else
		validate_name "$layer_name" "layer name"
	fi

	layer__load "$workspace_name" "$layer_name"
}

cmd__layer__list() {
	debug "$*"
	local layers=($(config__layer__list))
	local cells=()

	for layer in "${layers[@]+"${layers[@]}"}"; do
		[[ -z "$layer" ]] && continue
		local layer_obj
		layer_obj=$(config__layer__get "$layer")
		cells+=("$layer")
		cells+=("$(config__layer__obj_get_description "$layer_obj")")
	done

	print_table_horizontally 2 "name" "description" "${cells[@]+"${cells[@]}"}"
}

cmd__layer__delete() {
	local USAGE="

Usage (layer delete):
    $SCRIPT_NAME layer delete <layer_name>
"

	debug "$*"

	local layer_name="${1:?"Error: layer name is required.$USAGE"}"
	validate_name "$layer_name" "layer name"

	config__layer__delete__idempotent "$layer_name"
}

cmd__layer__set_description() {
	local USAGE="

Usage (layer set-description):
    $SCRIPT_NAME layer set-description <layer_name> \"description\"
    $SCRIPT_NAME layer set-desc <layer_name> \"description\"

Sets the description for an existing layer.
"

	debug "$*"

	local layer_name="${1:?"Error: layer name is required.$USAGE"}"
	validate_name "$layer_name" "layer name"

	local description="${2:?"Error: description is required.$USAGE"}"

	local layer_obj
	if ! layer_obj=$(config__layer__get "$layer_name"); then
		fatal "Error: layer '$layer_name' not found.$USAGE"
	fi

	layer_obj=$(config__layer__obj_set_description "$layer_obj" "$description")
	config__layer__put "$layer_name" "$layer_obj"
}

####################
### Repositories ###
####################

# Completions in completion__bash_repo
cmd__repo() {
	local USAGE="

Usage:
    $SCRIPT_NAME repo <sub-command> [args]

Sub-commands:
    add <repo_url> [repo_name]  Register a git repository
    remove <repo_name>          Remove a registered repository
    list                        List all registered repositories
    pull [repo_name ...]        Pull latest changes for repositories
    reset-to-origin [repo ...]  Fetch and hard reset to origin's current branch
    post-copy-hook <repo_name>  Create or edit post-copy hooks (as bash script)
"

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
	"pull")
		shift
		cmd__repo__pull "$@"
		;;
	"reset-to-origin")
		shift
		cmd__repo__reset_to_origin "$@"
		;;
	"post-copy-hook")
		shift
		cmd__repo__set_post_copy_hook "$@"
		;;
	*)
		fatal "Error: unknown sub-command '${1:-}'.$USAGE"
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
	repo__list
}

cmd__repo__pull() {
	local USAGE="

Usage (repo pull):
    $SCRIPT_NAME repo pull [repo_name ...]
    $SCRIPT_NAME pull [repo_name ...]

Pulls latest changes for the specified repositories.
If no repositories are specified, pulls all registered repositories.
"

	debug "$*"
	repo__validate_all
	for name in "$@"; do
		validate_name "$name" "repo name"
	done
	repo__pull "$@"
}

cmd__repo__reset_to_origin() {
	local USAGE="

Usage (repo reset-to-origin):
    $SCRIPT_NAME repo reset-to-origin [repo_name ...]

Fetches and hard resets each repository to origin's current branch.
If no repositories are specified, resets all registered repositories.
"

	debug "$*"
	repo__validate_all
	for name in "$@"; do
		validate_name "$name" "repo name"
	done
	repo__reset_to_origin "$@"
}

cmd__repo__set_post_copy_hook() {
	local USAGE="

Usage (repo post-copy-hook):
    $SCRIPT_NAME repo post-copy-hook <repo_name>

Add or edit arbitrary bash scripts that will be run after any worktree copy operation.
Typically this will be run after adding a repo to a workspace.
"
	debug "$*"
	repo__validate_all

	local repo="${1:?"Repo name is required.$USAGE"}"
	validate_name "$repo" "repo name"

	repo__set_post_copy_hook "$repo"
}

###########################
##### BASH COMPLETION #####
###########################

cmd__completions__install() {
	mkdir -p "$HOME/.bash_completions"
	rm -f "$HOME/.bash_completions/$SCRIPT_NAME.bash"

	# NOTE: requires SCRIPT_NAME to be on $PATH
	cp "$(command -v "$SCRIPT_NAME")" "$HOME/.bash_completions/$SCRIPT_NAME.bash"
	# NOTE: the sourced copy includes top-level code (variable assignments, validation).
	# This is acceptable for now; validation won't fire in normal setups.
	# remove set -euo pipefail when sourcing in bash
	perl -i -ne 'print unless /^set -euo pipefail$/' "$HOME/.bash_completions/$SCRIPT_NAME.bash"
	# remove and replace main "$@" with complete -F completion__bash SCRIPT_NAME
	perl -i -pe "s/^main \"\\\$\@\"$/complete -F completion__bash \"$SCRIPT_NAME\"/" "$HOME/.bash_completions/$SCRIPT_NAME.bash"

	# Only append to ~/.bashrc if the sourcing block is not already present
	if [[ -f ~/.bashrc ]]; then
		if ! grep -qF 'for f in ~/.bash_completions/*.bash; do' ~/.bashrc; then
			cat >>~/.bashrc <<'EOF'
for f in ~/.bash_completions/*.bash; do
    source "$f"
done
EOF
		fi
	fi

	# Only append to ~/.zshrc if the sourcing block is not already present
	# TODO: add zsh-native completions (compdef); bash compat works via zsh's built-in bashcompinit
	if [[ -f ~/.zshrc ]]; then
		if ! grep -qF 'for f in ~/.bash_completions/*.bash; do' ~/.zshrc; then
			cat >>~/.zshrc <<'EOF'
for f in ~/.bash_completions/*.bash; do
    source "$f"
done
EOF
		fi
	fi
}

cmd__update() {
	debug "$*"
	dependency__assert "curl"

	local ows_path
	ows_path=$(command -v ows)

	if [[ -L "$ows_path" ]]; then
		fatal "You're running a dev install. Update your repo with git pull instead."
	fi

	local tmpfile
	tmpfile=$(fs__tempfile__safe_create)

	if ! curl -fsSL "https://raw.githubusercontent.com/Yongbeom-Kim/OmniWorkspace/refs/heads/main/main.sh" -o "$tmpfile"; then
		fs__tempfile__clean "$tmpfile"
		fatal "Failed to download update. Check your network connection."
	fi

	if cmp -s "$ows_path" "$tmpfile"; then
		fs__tempfile__clean "$tmpfile"
		echo "Already up to date."
		return 0
	fi

	echo "Update available. Installing..."
	chmod +x "$tmpfile"
	if ! sudo cp "$tmpfile" "$ows_path"; then
		fs__tempfile__clean "$tmpfile"
		fatal "Failed to install update."
	fi

	fs__tempfile__clean "$tmpfile"
	echo "Update complete. The new version will be used on your next invocation."
}

completion__bash() {
	local cur="${COMP_WORDS[COMP_CWORD]}"
	local cmds

	if [[ $COMP_CWORD -eq 1 ]]; then
		cmds=("workspaces" "wss" "workspace" "ws" "w" "wsp" "repos" "rs" "repo" "r" "exec" "checkout" "co" "cd" "layer" "l" "install" "update")
		COMPREPLY=($(compgen -W "${cmds[*]}" -- "$cur"))
		return 0
	fi

	case "${COMP_WORDS[1]}" in
	"workspace" | "ws" | "w" | "wsp" | "exec" | "checkout" | "co" | "cd")
		completion__bash_workspace
		;;
	"repo" | "r")
		completion__bash_repo
		;;
	"layer" | "l")
		completion__bash_layer
		;;
	esac
}

completion__bash_workspace() {
	local cur="${COMP_WORDS[COMP_CWORD]}"
	local cmds=()
	local top="${COMP_WORDS[1]}"

	# Shortcuts (exec, checkout, co, cd) skip the subcommand position
	case "$top" in
	"exec" | "checkout" | "co" | "cd")
		if [[ $COMP_CWORD -eq 2 ]]; then
			cmds=($(config__workspace__list))
			COMPREPLY=($(compgen -W "${cmds[*]}" -- "$cur"))
		fi
		return 0
		;;
	esac

	# Position 2: subcommand
	if [[ $COMP_CWORD -eq 2 ]]; then
		cmds=("add" "create" "add-repo" "remove-repo" "delete" "list" "exec" "checkout" "pull" "reset-hard-to-origin" "run-hooks" "cd" "layer")
		COMPREPLY=($(compgen -W "${cmds[*]}" -- "$cur"))
		return 0
	fi

	local subcmd="${COMP_WORDS[2]}"
	# Position 3: workspace name (for commands that take one)
	if [[ $COMP_CWORD -eq 3 ]]; then
		case "$subcmd" in
		"list")
			return 0
			;;
		*)
			cmds=($(config__workspace__list))
			COMPREPLY=($(compgen -W "${cmds[*]}" -- "$cur"))
			return 0
			;;
		esac
	fi

	# Position 4+: repo names for add/add-repo/create
	case "$subcmd" in
	"add" | "add-repo" | "create")
		cmds=($(config__repo__list))
		COMPREPLY=($(compgen -W "${cmds[*]}" -- "$cur"))
		return 0
		;;
	"layer") # delegate to layer completer with offset for 'workspace layer'
		completion__bash_layer 1
		return 0
		;;
	"remove-repo") # only suggest repos inside the selected workspace
		local ws_name="${COMP_WORDS[3]}"
		local ws_obj
		if ! ws_obj=$(config__workspace__get "$ws_name" 2>/dev/null); then
			return 0
		fi
		cmds=($(config__workspace__obj_get_repos "$ws_obj"))
		COMPREPLY=($(compgen -W "${cmds[*]}" -- "$cur"))
		return 0
		;;
	esac
}

completion__bash_repo() {
	local cmds=()
	if [[ $COMP_CWORD -eq 2 ]]; then
		cmds=("add" "remove" "list" "pull" "reset-to-origin" "post-copy-hook")
		COMPREPLY=($(compgen -W "${cmds[*]}" -- "$cur"))
		return 0
	fi

	local subcmd="${COMP_WORDS[2]}"
	case "$subcmd" in
	"add" | "list")
		# no further autocompletions
		return 0
		;;
	"post-copy-hook")
		if [[ $COMP_CWORD -eq 3 ]]; then
			cmds=($(config__repo__list))
			COMPREPLY=($(compgen -W "${cmds[*]}" -- "$cur"))
		fi
		return 0
		;;
	"remove" | "pull" | "reset-to-origin")
		cmds=($(config__repo__list))
		COMPREPLY=($(compgen -W "${cmds[*]}" -- "$cur"))
		return 0
		;;
	esac
}

# offset param allows reuse from 'workspace layer' (offset=1) vs 'layer' (offset=0)
completion__bash_layer() {
	local cur="${COMP_WORDS[COMP_CWORD]}"
	local cmds=()
	local offset="${1:-0}"

	# Position 2+offset: subcommand (save, load, list, delete)
	if [[ $COMP_CWORD -eq $((2 + offset)) ]]; then
		cmds=("save" "load" "list" "delete" "set-description" "set-desc")
		COMPREPLY=($(compgen -W "${cmds[*]}" -- "$cur"))
		return 0
	fi

	local subcmd="${COMP_WORDS[$((2 + offset))]}"

	case "$subcmd" in
	"list")
		return 0
		;;
	"delete")
		# Position 3+offset: layer name
		if [[ $COMP_CWORD -eq $((3 + offset)) ]]; then
			cmds=($(config__layer__list))
			COMPREPLY=($(compgen -W "${cmds[*]}" -- "$cur"))
		fi
		return 0
		;;
	"set-description" | "set-desc")
		# Position 3+offset: layer name
		if [[ $COMP_CWORD -eq $((3 + offset)) ]]; then
			cmds=($(config__layer__list))
			COMPREPLY=($(compgen -W "${cmds[*]}" -- "$cur"))
		fi
		return 0
		;;
	"save")
		# Position 3+offset: workspace name
		if [[ $COMP_CWORD -eq $((3 + offset)) ]]; then
			cmds=($(config__workspace__list))
			COMPREPLY=($(compgen -W "${cmds[*]}" -- "$cur"))
		# Position 4+offset: layer name
		elif [[ $COMP_CWORD -eq $((4 + offset)) ]]; then
			cmds=($(config__layer__list))
			COMPREPLY=($(compgen -W "${cmds[*]}" -- "$cur"))
		fi
		return 0
		;;
	"load")
		# Position 3+offset: workspace name
		if [[ $COMP_CWORD -eq $((3 + offset)) ]]; then
			cmds=($(config__workspace__list))
			COMPREPLY=($(compgen -W "${cmds[*]}" -- "$cur"))
		# Position 4+offset: layer name
		elif [[ $COMP_CWORD -eq $((4 + offset)) ]]; then
			cmds=($(config__layer__list))
			COMPREPLY=($(compgen -W "${cmds[*]}" -- "$cur"))
		fi
		return 0
		;;
	esac
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

	local workspace_dir
	workspace_dir="$(fs__workspace_get_dir "$workspace_name")"

	local workspace_obj
	if config__workspace__exists "$workspace_name"; then
		workspace_obj=$(config__workspace__get "$workspace_name")
	else
		workspace_obj=$(config__workspace__obj_create "$workspace_name" "$workspace_dir")
	fi

	fs__workspace_mkdir_idempotent "$workspace_name"

	local added_repos=()
	local branch_name
	branch_name="$(config__workspace__obj_get_branch "$workspace_obj")"

	# Pass 1: create worktrees and update config object
	for repo in "${workspace_repos[@]+"${workspace_repos[@]}"}"; do
		if [[ -z $repo ]]; then
			continue
		fi

		if config__workspace__obj_contains_repo "$workspace_obj" "$repo"; then
			warn "Repo $repo already in workspace $workspace_name, skipping."
			continue
		fi

		local repo_obj repo_dir
		repo_obj=$(config__repo__get "$repo")
		repo_dir=$(config__repo__obj_get_directory "$repo_obj")
		local subtree_dir="$workspace_dir/$repo"

		local worktree_rc=0
		git__create_workspace_worktree "$repo_dir" "$subtree_dir" "$branch_name" || worktree_rc=$?
		if [[ "$worktree_rc" -ne 0 ]] && [[ "$worktree_rc" -ne "$GIT_WORKTREE_ALREADY_EXISTS_RETURN_CODE" ]]; then
			warn "Failed to add git worktree of $repo to workspace $workspace_name. Try again later."
			continue
		fi

		workspace_obj=$(config__workspace__obj_add_repo "$workspace_obj" "$repo")
		git__set_upstream_branch "$subtree_dir" "$branch_name" || true
		if [[ "$worktree_rc" -ne "$GIT_WORKTREE_ALREADY_EXISTS_RETURN_CODE" ]]; then
			added_repos+=("$repo")
		fi

		echo "Successfully added repo $repo to workspace $workspace_name."
	done

	# Save config before running hooks
	if ! config__workspace__put "$workspace_name" "$workspace_obj"; then
		warn "Failed to save workspace $workspace_name config."
		return 1
	fi

	# Pass 2: run post-copy hooks after config is committed
	if [[ ${#added_repos[@]} -gt 0 ]]; then
		info "Added repos, running post-copy hooks:"
		for repo in "${added_repos[@]}"; do
			local repo_obj repo_post_copy_hook
			repo_obj=$(config__repo__get "$repo")
			repo_post_copy_hook="$(config__repo__obj_get_post_copy_hook "$repo_obj")"
			local subtree_dir="$workspace_dir/$repo"

			if [[ -n "$repo_post_copy_hook" ]]; then
				info "Running post-copy hook for $repo..."
				info "$repo_post_copy_hook"
				if ! sh__run_bash_script_in_dir "$subtree_dir" "$repo_post_copy_hook"; then
					warn "Failed to execute post-copy hook in $subtree_dir"
				fi
			else
				info "No post-copy hook found for ${repo}, skipping."
			fi
		done
	fi
}

workspace__delete() {
	debug "$*"
	workspace__validate_all
	local workspace_name="$1"
	local ws_obj ws_dir
	ws_obj=$(config__workspace__get "$workspace_name")
	ws_dir=$(config__workspace__obj_get_directory "$ws_obj")

	local repos=($(config__workspace__obj_get_repos "$ws_obj"))
	# TODO: ideally we want to only have 1 fs write per operation, but this is OK.
	workspace__remove_repos "$workspace_name" "${repos[@]+"${repos[@]}"}"

	if ! config__workspace__delete_idempotent "$workspace_name"; then
		warn "Failed to delete workspace $workspace_name."
		return 1
	fi

	fs__safe_rm_rf "$ws_dir" "$WORKSPACES_DIR"
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
		local ws_obj
		ws_obj=$(config__workspace__get "$workspace")
		local repos
		repos=($(config__workspace__obj_get_repos "$ws_obj"))
		local repo_cell=""
		for i in "${!repos[@]}"; do
			repo_cell+="${repos[$i]}"
			if [[ i -lt $((${#repos[@]} - 1)) ]]; then
				repo_cell+=", "
			fi
		done
		repos_column+=("$repo_cell")

		local branch
		branch="$(config__workspace__obj_get_branch "$ws_obj")"

		branch_column+=("$branch")
	done

	print_table_vertically 3 "workspace" "${workspaces[@]+"${workspaces[@]}"}" "branch" "${branch_column[@]+"${branch_column[@]}"}" "repos" "${repos_column[@]+"${repos_column[@]}"}"
}

workspace__remove_repos() {
	debug "$*"
	workspace__validate_all
	local workspace_name="${1:?"workspace name is required"}"
	local workspace_obj="$(config__workspace__get "$workspace_name")"
	shift
	# we checked this in cmd__workspace__remove_repo, so guaranteed to have value
	local repos_to_remove=("$@")

	for repo in "${repos_to_remove[@]+"${repos_to_remove[@]}"}"; do
		local repo_obj repo_dir
		repo_obj=$(config__repo__get "$repo")
		repo_dir=$(config__repo__obj_get_directory "$repo_obj")
		local subtree_dir
		subtree_dir="$(fs__workspace_get_repo_subtree_dir "$workspace_name" "$repo")"
		if ! git__remove_workspace_worktree_idempotent "$repo_dir" "$subtree_dir"; then
			warn "Git Worktree: Failed to remove repo $repo from workspace $workspace_name"
			continue
		fi

		workspace_obj=$(config__workspace__obj_remove_repo "$workspace_obj" "$repo")
	done

	if ! config__workspace__put "$workspace_name" "$workspace_obj"; then
		warn "Config: Failed to save config"
	fi
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

	# Finished all our tasks. Release lock in case of long-running exec.
	fs__release_lock
	cd "$workspace_dir" && "$@"
}

workspace__cd() {
	debug "$*"
	workspace__validate_all

	local workspace_name="${1:?"workspace name is required"}"

	if ! config__workspace__exists "$workspace_name"; then
		fatal "Workspace $workspace_name does not exist"
	fi

	local workspace_dir="$WORKSPACES_DIR/$workspace_name"
	if [[ ! -d "$workspace_dir" ]]; then
		fatal "Workspace directory $workspace_dir does not exist"
	fi

	info "Entering $workspace_dir (exit or Ctrl+D to return)"
	# shell blocks the release lock, so we'll release the lock first here.
	fs__release_lock
	cd "$workspace_dir" && "$SHELL"
}

workspace__check_branch_conflicts_by_repo() {
	debug "$*"
	local workspace_name="$1"
	local branch_name="$2"

	local ws_obj
	ws_obj=$(config__workspace__get "$workspace_name")
	local target_repos=($(config__workspace__obj_get_repos "$ws_obj"))

	local all_workspaces=($(config__workspace__list))
	for other_ws in "${all_workspaces[@]+"${all_workspaces[@]}"}"; do
		if [[ -z "$other_ws" ]] || [[ "$other_ws" == "$workspace_name" ]]; then
			continue
		fi

		local other_obj
		other_obj=$(config__workspace__get "$other_ws") || continue
		local other_branch
		other_branch="$(config__workspace__obj_get_branch "$other_obj")"

		if [[ "$other_branch" != "$branch_name" ]]; then
			continue
		fi

		local other_repos=($(config__workspace__obj_get_repos "$other_obj"))
		for target_repo in "${target_repos[@]+"${target_repos[@]}"}"; do
			for other_repo in "${other_repos[@]+"${other_repos[@]}"}"; do
				if [[ "$target_repo" == "$other_repo" ]]; then
					fatal "Failed to checkout branch $branch_name for workspace $workspace_name: Repo $target_repo already has branch $branch_name checked out in workspace $other_ws."
				fi
			done
		done
	done
}

workspace__checkout__branch() {
	debug "$*"
	workspace__validate_all
	repo__validate_all

	local workspace_name="$1"
	local branch_name="$2"

	local ws_obj
	if ! config__workspace__exists "$workspace_name"; then
		fatal "Workspace $workspace_name does not exist"
	fi
	ws_obj=$(config__workspace__get "$workspace_name")

	local repos=($(config__workspace__obj_get_repos "$ws_obj"))

	local old_branch
	old_branch=$(config__workspace__obj_get_branch "$ws_obj")

	if [[ "$old_branch" == "$branch_name" ]]; then
		return 0
	fi

	workspace__check_branch_conflicts_by_repo "$workspace_name" "$branch_name"

	local successful_repos=()
	for repo_name in "${repos[@]+"${repos[@]}"}"; do
		local destination_worktree_dir
		destination_worktree_dir="$(fs__workspace_get_repo_subtree_dir "$workspace_name" "$repo_name")"
		if ! git__checkout_branch_on_worktree "$destination_worktree_dir" "$branch_name"; then
			# Rollback successful repos
			local rollback_failed=0
			for rollback_repo in "${successful_repos[@]+"${successful_repos[@]}"}"; do
				local rollback_dir
				rollback_dir="$(fs__workspace_get_repo_subtree_dir "$workspace_name" "$rollback_repo")"
				if ! git__checkout_branch_on_worktree "$rollback_dir" "$old_branch"; then
					warn "Failed to rollback repo $rollback_repo to branch $old_branch."
					rollback_failed=1
				fi
			done
			if [[ "$rollback_failed" -eq 1 ]]; then
				fatal "Failed to checkout branch $branch_name for workspace $workspace_name: repo $repo_name checkout failed. Some repos could not be rolled back. Manual cleanup may be needed."
			else
				fatal "Failed to checkout branch $branch_name for workspace $workspace_name: repo $repo_name checkout failed. All changes have been rolled back."
			fi
		fi
		successful_repos+=("$repo_name")
	done

	ws_obj=$(config__workspace__obj_set_branch "$ws_obj" "$branch_name")
	if ! config__workspace__put "$workspace_name" "$ws_obj"; then
		fatal "Failed to save branch $branch_name for workspace $workspace_name to config"
	fi

	for repo_name in "${repos[@]+"${repos[@]}"}"; do
		local destination_worktree_dir
		destination_worktree_dir="$(fs__workspace_get_repo_subtree_dir "$workspace_name" "$repo_name")"
		git__set_upstream_branch "$destination_worktree_dir" "$branch_name" || true
	done
}

workspace__pull() {
	debug "$*"
	workspace__validate_all
	repo__validate_all

	local workspace_name="$1"

	local ws_obj
	if ! config__workspace__exists "$workspace_name"; then
		fatal "Workspace $workspace_name does not exist"
	fi
	ws_obj=$(config__workspace__get "$workspace_name")

	local repos=($(config__workspace__obj_get_repos "$ws_obj"))
	local branch_name="$(config__workspace__obj_get_branch "$ws_obj")"

	for repo_name in "${repos[@]+"${repos[@]}"}"; do
		local repo_worktree_dir
		repo_worktree_dir="$(fs__workspace_get_repo_subtree_dir "$workspace_name" "$repo_name")"
		git__set_upstream_branch "$repo_worktree_dir" "$branch_name" || true
		info "Pulling '$repo_name' in workspace '$workspace_name'..."
		if ! git__pull "$repo_worktree_dir"; then
			warn "Failed to pull repo $repo_name ($repo_worktree_dir) under workspace $workspace_name"
		fi
	done
}

workspace__reset_hard_to_origin() {
	debug "$*"
	workspace__validate_all
	repo__validate_all

	local workspace_name="$1"

	local ws_obj
	if ! config__workspace__exists "$workspace_name"; then
		fatal "Workspace $workspace_name does not exist"
	fi
	ws_obj=$(config__workspace__get "$workspace_name")

	local repos=($(config__workspace__obj_get_repos "$ws_obj"))
	local branch_name="$(config__workspace__obj_get_branch "$ws_obj")"

	for repo_name in "${repos[@]+"${repos[@]}"}"; do
		local repo_worktree_dir
		repo_worktree_dir="$(fs__workspace_get_repo_subtree_dir "$workspace_name" "$repo_name")"
		info "Resetting '$repo_name' in workspace '$workspace_name' to origin/$branch_name..."
		git__set_upstream_branch "$repo_worktree_dir" "$branch_name" || true
		if ! git__fetch_origin "$repo_worktree_dir"; then
			warn "Failed to fetch origin for $repo_name ($repo_worktree_dir)"
			continue
		fi
		if ! git__reset_hard "$repo_worktree_dir" "origin/$branch_name"; then
			warn "Failed to reset $repo_name ($repo_worktree_dir) to origin/$branch_name"
		fi
	done
}

workspace__run_hooks() {
	debug "$*"
	workspace__validate_all
	repo__validate_all

	local workspace_name="$1"

	local ws_obj
	if ! config__workspace__exists "$workspace_name"; then
		fatal "Workspace $workspace_name does not exist"
	fi
	ws_obj=$(config__workspace__get "$workspace_name")

	local repos=($(config__workspace__obj_get_repos "$ws_obj"))

	for repo_name in "${repos[@]+"${repos[@]}"}"; do
		local repo_obj repo_post_copy_hook
		repo_obj=$(config__repo__get "$repo_name")
		repo_post_copy_hook="$(config__repo__obj_get_post_copy_hook "$repo_obj")"

		if [[ -z "$repo_post_copy_hook" ]]; then
			info "No post-copy hook for '$repo_name', skipping."
			continue
		fi

		local repo_worktree_dir
		repo_worktree_dir="$(fs__workspace_get_repo_subtree_dir "$workspace_name" "$repo_name")"
		info "Running post-copy hook for '$repo_name' in workspace '$workspace_name'..."
		if ! sh__run_bash_script_in_dir "$repo_worktree_dir" "$repo_post_copy_hook"; then
			warn "Failed to execute post-copy hook for $repo_name in $repo_worktree_dir"
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
	local ws_obj
	ws_obj=$(config__workspace__get "$workspace_name") || return 1
	local repos=($(config__workspace__obj_get_repos "$ws_obj"))

	fs__workspace_mkdir_idempotent "$workspace_name"

	for repo in "${repos[@]+"${repos[@]}"}"; do
		if [[ -z "$repo" ]]; then
			continue
		fi

		local repo_obj repo_dir repo_post_copy_hook
		repo_obj=$(config__repo__get "$repo")
		repo_dir=$(config__repo__obj_get_directory "$repo_obj")
		repo_post_copy_hook="$(config__repo__obj_get_post_copy_hook "$repo_obj")"
		local subtree_dir
		subtree_dir=$(fs__workspace_get_repo_subtree_dir "$workspace_name" "$repo")
		local branch_name
		branch_name="$(config__workspace__obj_get_branch "$ws_obj")"

		local worktree_rc=0
		git__create_workspace_worktree "$repo_dir" "$subtree_dir" "$branch_name" || worktree_rc=$?
		if [[ "$worktree_rc" -ne 0 ]] && [[ "$worktree_rc" -ne "$GIT_WORKTREE_ALREADY_EXISTS_RETURN_CODE" ]]; then
			warn "Failed to add git worktree of $repo to workspace $workspace_name. Try again later."
			continue
		fi

		if [[ "$worktree_rc" -ne "$GIT_WORKTREE_ALREADY_EXISTS_RETURN_CODE" ]] && [[ -n "$repo_post_copy_hook" ]]; then
			if ! sh__run_bash_script_in_dir "$subtree_dir" "$repo_post_copy_hook"; then
				warn "Failed to execute post-copy hook in $subtree_dir"
			fi
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
	local repo_obj repo_originurl repo_dir
	repo_obj=$(config__repo__get "$repo_name")
	repo_originurl=$(config__repo__obj_get_originurl "$repo_obj")
	repo_dir=$(config__repo__obj_get_directory "$repo_obj")

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
	local existing_obj existing_url existing_dir
	if existing_obj=$(config__repo__get "$repo_name"); then
		existing_url=$(config__repo__obj_get_originurl "$existing_obj")
		existing_dir=$(config__repo__obj_get_directory "$existing_obj")
		if [[ "$existing_url" == "$repo_url" && "$existing_dir" == "$repo_dir" ]]; then
			if git__validate_repo "$repo_url" "$repo_name"; then
				debug "Repository $repo_name already exists with same config, skipping"
				return 0
			fi
		fi
	fi

	# Configs are always the source of truth, so we always add to config first.
	local repo_obj
	repo_obj=$(config__repo__obj_create "$repo_url" "$repo_dir")
	if ! config__repo__put "$repo_name" "$repo_obj"; then
		warn "Failed to add repository $repo_name to config."
		return 1
	fi

	if ! repo_dir=$(git__add_repo_idempotent "$repo_url" "$repo_name"); then
		config__repo__delete_idempotent "$repo_name"
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
	config__repo__delete_idempotent "$repo_name"

	echo "Repository $repo_name removed successfully."
}

repo__list() {
	local repos=($(config__repo__list))
	local cells=()

	for repo in "${repos[@]+"${repos[@]}"}"; do
		local repo_obj
		repo_obj=$(config__repo__get "$repo")
		cells+=("$repo")
		cells+=("$(config__repo__obj_get_originurl "$repo_obj")")
		cells+=("$(config__repo__obj_get_directory "$repo_obj")")
	done

	print_table_horizontally 3 "repo" "origin" "directory" "${cells[@]+"${cells[@]}"}"
}

repo__pull() {
	local repos_to_pull=()
	if [[ $# -eq 0 ]]; then
		repos_to_pull=($(config__repo__list))
	else
		repos_to_pull=("$@")
	fi

	if [[ ${#repos_to_pull[@]} -eq 0 ]]; then
		warn "No repositories registered."
		return 0
	fi

	for repo_name in "${repos_to_pull[@]}"; do
		local repo_obj repo_dir
		repo_obj=$(config__repo__get "$repo_name")
		repo_dir=$(config__repo__obj_get_directory "$repo_obj")
		if [[ -z "$repo_dir" || ! -d "$repo_dir" ]]; then
			warn "Repository '$repo_name' not found, skipping."
			continue
		fi
		info "Pulling '$repo_name'..."
		git__pull "$repo_dir" || true
	done
}

repo__reset_to_origin() {
	local repos=()
	if [[ $# -eq 0 ]]; then
		repos=($(config__repo__list))
	else
		repos=("$@")
	fi

	if [[ ${#repos[@]} -eq 0 ]]; then
		warn "No repositories registered."
		return 0
	fi

	for repo_name in "${repos[@]}"; do
		local repo_obj repo_dir
		repo_obj=$(config__repo__get "$repo_name")
		repo_dir=$(config__repo__obj_get_directory "$repo_obj")
		if [[ -z "$repo_dir" || ! -d "$repo_dir" ]]; then
			warn "Repository '$repo_name' not found, skipping."
			continue
		fi
		info "Resetting '$repo_name' to origin..."
		git__reset_to_origin "$repo_dir" || true
	done
}

repo__set_post_copy_hook() {
	local repo="${1:?}"
	local repo_obj
	if ! repo_obj="$(config__repo__get "$repo")"; then
		fatal "Repo $repo does not exist."
	fi
	local repo_post_copy_hook
	repo_post_copy_hook="$(config__repo__obj_get_post_copy_hook "$repo_obj")"

	if [[ -z "$repo_post_copy_hook" ]]; then
		repo_post_copy_hook="$REPO_POST_COPY_HOOK_DEFAULT_VALUE"
	fi

	local global_obj
	global_obj="$(config__global__get)"
	local global_editor
	global_editor="$(config__global__obj_get_editor "$global_obj")"

	local tempfile
	tempfile="$(fs__tempfile__safe_create)"
	# NOTE: tempfile may leak if interrupted (e.g., Ctrl+C). Cannot use trap here
	# as it would conflict with the config file lock's EXIT trap.
	fs__tempfile__write "$tempfile" "$repo_post_copy_hook"
	fs__tempfile__open "$tempfile" "$global_editor"

	repo_post_copy_hook="$(fs__tempfile__read "$tempfile")"
	fs__tempfile__clean "$tempfile"

	repo_obj="$(config__repo__obj_set_post_copy_hook "$repo_obj" "$repo_post_copy_hook")"
	config__repo__put "$repo" "$repo_obj"
}

########################################
##### High-Level Layer Management #####
########################################

layer__save() {
	debug "$*"
	local workspace_name="${1:?}"
	local layer_name="${2:?}"
	local layer_desc="${3:-}"

	# Description resolution: explicit > existing > layer name
	if [[ -z "$layer_desc" ]]; then
		local existing_obj
		if existing_obj=$(config__layer__get "$layer_name" 2>/dev/null); then
			layer_desc=$(config__layer__obj_get_description "$existing_obj")
		fi
		if [[ -z "$layer_desc" ]]; then
			layer_desc="$layer_name"
		fi
	fi

	local workspace_obj
	workspace_obj=$(config__workspace__get "$workspace_name")
	local workspace_dir
	workspace_dir=$(fs__workspace_get_dir "$workspace_name")

	local excluded_subpaths=()
	local repos
	repos=$(config__workspace__obj_get_repos "$workspace_obj")
	while IFS= read -r repo; do
		[[ -z "$repo" ]] && continue
		excluded_subpaths+=("$(fs__workspace_get_repo_subtree_dir "$workspace_name" "$repo")")
	done <<< "$repos"

	# Read non-repo files from workspace dir (alternating path/base64 lines)
	local args=()
	while IFS= read -r line; do
		[[ -z "$line" ]] && continue
		args+=("$line")
	done <<< "$(fs__layer__read "$workspace_dir" "${excluded_subpaths[@]+"${excluded_subpaths[@]}"}")"

	local i
	for (( i=0; i<${#args[@]}; i=i+2 )); do
		if ! args[$i]=$(fs__create_relative_file_path "${args[$i]}" "$workspace_dir"); then
			fatal "File '${args[$i]}' is not inside workspace directory '$workspace_dir'"
		fi
	done

	# Create layer object and save to config
	local layer_obj
	layer_obj=$(config__layer__obj_create "$layer_desc" "${args[@]+"${args[@]}"}")
	config__layer__put "$layer_name" "$layer_obj"

	# Link layer to workspace
	workspace_obj=$(config__workspace__obj_set_layer "$workspace_obj" "$layer_name")
	config__workspace__put "$workspace_name" "$workspace_obj"
}

layer__load() {
	debug "$*"
	local workspace_name="${1:?}"
	local layer_name="${2:?}"

	local workspace_obj
	workspace_obj=$(config__workspace__get "$workspace_name")
	local workspace_dir
	workspace_dir=$(fs__workspace_get_dir "$workspace_name")

	local excluded_subpaths=()
	local repos
	repos=$(config__workspace__obj_get_repos "$workspace_obj")
	while IFS= read -r repo; do
		[[ -z "$repo" ]] && continue
		excluded_subpaths+=("$(fs__workspace_get_repo_subtree_dir "$workspace_name" "$repo")")
	done <<< "$repos"

	# Get layer from config
	local layer_obj
	if ! layer_obj=$(config__layer__get "$layer_name"); then
		fatal "Layer '$layer_name' not found"
	fi

	# Clear existing non-repo files
	fs__layer__clear "$workspace_dir" "${excluded_subpaths[@]+"${excluded_subpaths[@]}"}"

	# Extract file path/contents pairs from layer object
	local files
	files=$(config__layer__obj_get_files "$layer_obj")

	local file_args=()
	local num_files
	num_files=$(echo "$files" | yq 'length')

	local i
	for (( i=0; i<num_files; i++ )); do
		local path contents
		path=$(echo "$files" | yq -r ".[$i].\"${LAYER_FILE_RELATIVE_PATH_KEY}\"")
		contents=$(echo "$files" | yq -r ".[$i].\"${LAYER_FILE_CONTENTS_KEY}\"")
		[[ -z "$path" || "$path" == "null" ]] && continue
		local full_path="$workspace_dir/$path"
		mkdir -p "$(dirname "$full_path")"
		file_args+=("$full_path" "$contents")
	done

	# Write layer files to workspace
	if ! fs__layer__write "$workspace_dir" "${file_args[@]+"${file_args[@]}"}"; then
		fatal "Failed to write layer files to workspace '$workspace_name'. Some files already exist in the workspace directory."
	fi
}

###############################
##### Yaml Configurations #####
###############################

##########################
### Yaml Global Config ###
##########################

config__global__get() {
	debug "$*"
	config__create_file_if_not_exist

	local result
	result=$(yq -r ".[\"${GLOBAL_KEY}\"]" "$CONFIG_FILE_PATH")

	local defaults
	defaults=$(config__global__obj_defaults)
	if [[ "$result" == "null" || -z "$result" ]]; then
		echo "$defaults"
		return
	fi
	# Merge: defaults (base) * stored (override) -- stored wins
	result=$(echo "$result" | yq 'del(.. | select(. == null))')
	echo "$defaults" | result="$result" yq '. * env(result)'
}

config__global__put() {
	debug "$*"
	local global_obj="${1:?}"

	global_obj="${global_obj}" yq -i ".[\"${GLOBAL_KEY}\"] = env(global_obj)" "$CONFIG_FILE_PATH"
}

config__global__obj_get_editor() {
	debug "$*"
	local global_obj="${1:?}"

	echo "$global_obj" | yq -r ".[\"${GLOBAL_EDITOR_KEY}\"]" | yq__normalize_null
}

config__global__obj_set_editor() {
	debug "$*"
	local global_obj="${1:?}"
	local editor="${2:?}"

	echo "${global_obj}" | editor="${editor}" yq ".[\"${GLOBAL_EDITOR_KEY}\"] = env(editor)"
}

config__global__obj_defaults() {
	echo "{
		\"${GLOBAL_EDITOR_KEY}\": \"${GLOBAL_EDITOR_DEFAULT_VALUE}\"
	}" | yq '.'
	# TODO: respect $VISUAL and $EDITOR environment variables
}

#############################
### Yaml Workspace Config ###
#############################

config__workspace__get() {
	debug "$*"
	config__create_file_if_not_exist
	local workspace_name="${1:?}"

	local result
	result=$(yq -r ".[\"${WORKSPACE_KEY}\"].[\"${workspace_name}\"]" "$CONFIG_FILE_PATH")

	if [[ "$result" == "null" ]]; then
		return 1
	fi

	# Merge: defaults (base) * stored (override) -- stored wins
	local workspace_dir
	workspace_dir="$(fs__workspace_get_dir "$workspace_name")"
	local defaults
	defaults=$(config__workspace__obj_defaults "$workspace_name" "$workspace_dir")
	result=$(echo "$result" | yq 'del(.. | select(. == null))')
	echo "$defaults" | result="$result" yq '. * env(result)'
}

config__workspace__put() {
	debug "$*"
	config__create_file_if_not_exist

	local workspace_name="${1:?}" workspace_obj="${2:?}"

	workspace_obj="$workspace_obj" yq -i ".[\"${WORKSPACE_KEY}\"].[\"${workspace_name}\"] = env(workspace_obj)" "$CONFIG_FILE_PATH"
}

config__workspace__exists() {
	debug "$*"
	config__create_file_if_not_exist
	local workspace_name="${1:?}"

	yq -e ".[\"${WORKSPACE_KEY}\"].[\"${workspace_name}\"] != null" "$CONFIG_FILE_PATH" &>/dev/null
}

config__workspace__list() {
	debug "$*"
	config__create_file_if_not_exist

	local result
	result=$(yq ".[\"${WORKSPACE_KEY}\"] | keys | .[]" "$CONFIG_FILE_PATH" 2>/dev/null) || true

	if [[ -n "$result" && "$result" != "null" ]]; then
		echo "$result"
	fi
}

config__workspace__delete_idempotent() {
	debug "$*"
	config__create_file_if_not_exist
	local workspace_name="${1:?}"

	yq -i "del(.[\"${WORKSPACE_KEY}\"].[\"${workspace_name}\"])" "$CONFIG_FILE_PATH"
}

config__workspace__obj_create() {
	debug "$*"
	local workspace_name="${1:?}" workspace_dir="${2:?}"

	config__workspace__obj_defaults "$workspace_name" "$workspace_dir"
}

config__workspace__obj_defaults() {
	debug "$*"
	local workspace_name="${1:?}" workspace_dir="${2:?}"

	echo "{
		\"${WORKSPACE_REPOS_KEY}\": [],
		\"${WORKSPACE_BRANCH_KEY}\": \"${workspace_name}\",
		\"${WORKSPACE_DIRECTORY_KEY}\": \"${workspace_dir}\"
	}" | yq '.'
}

config__workspace__obj_add_repo() {
	debug "$*"
	local workspace_obj="${1:?}" repo_to_add="${2:?}"

	echo "$workspace_obj" | yq -r ".[\"${WORKSPACE_REPOS_KEY}\"] += [\"${repo_to_add}\"]"
}

config__workspace__obj_remove_repo() {
	debug "$*"
	local workspace_obj="${1:?}" repo_to_remove="${2:?}"

	echo "$workspace_obj" | yq -r "del(.[\"${WORKSPACE_REPOS_KEY}\"][] | select(. == \"${repo_to_remove}\"))"
}

config__workspace__obj_contains_repo() {
	debug "$*"
	local workspace_obj="${1:?}" repo="${2:?}"

	echo "$workspace_obj" | yq -e ".[\"${WORKSPACE_REPOS_KEY}\"] | contains([\"${repo}\"])" >/dev/null
}

config__workspace__obj_get_repos() {
	debug "$*"
	local workspace_obj="${1:?}"

	echo "$workspace_obj" | yq -r ".[\"${WORKSPACE_REPOS_KEY}\"].[]" | yq__normalize_null
}

config__workspace__obj_get_branch() {
	debug "$*"
	local workspace_obj="${1:?}"

	echo "$workspace_obj" | yq -r ".[\"${WORKSPACE_BRANCH_KEY}\"]" | yq__normalize_null
}

config__workspace__obj_set_branch() {
	debug "$*"
	local workspace_obj="${1:?}" branch="${2:?}"

	echo "$workspace_obj" | yq -r ".[\"${WORKSPACE_BRANCH_KEY}\"] = \"$branch\""
}

config__workspace__obj_get_directory() {
	debug "$*"
	local workspace_obj="${1:?}"

	echo "$workspace_obj" | yq -r ".[\"${WORKSPACE_DIRECTORY_KEY}\"]" | yq__normalize_null
}

config__workspace__obj_set_directory() {
	debug "$*"
	local workspace_obj="${1:?}" dir="${2:?}"

	echo "$workspace_obj" | yq -r ".[\"${WORKSPACE_DIRECTORY_KEY}\"] = \"$dir\""
}

config__workspace__obj_get_layer() {
	debug "$*"
	local workspace_obj="${1:?}"

	echo "$workspace_obj" | yq -r ".[\"${WORKSPACE_LAYER_KEY}\"]" | yq__normalize_null
}

config__workspace__obj_set_layer() {
	debug "$*"
	local workspace_obj="${1:?}" layer_name="${2:?}"

	echo "$workspace_obj" | yq -r ".[\"${WORKSPACE_LAYER_KEY}\"] = \"$layer_name\""
}

########################
### Yaml Repo Config ###
########################

config__repo__put() {
	debug "$*"
	config__create_file_if_not_exist

	local repo_name="${1:?}"
	local repo_obj="${2:?}"

	repo_obj="$repo_obj" yq -i ".[\"${REPO_KEY}\"].[\"${repo_name}\"] = env(repo_obj)" "$CONFIG_FILE_PATH"
}

config__repo__delete_idempotent() {
	debug "$*"
	config__create_file_if_not_exist
	local repo_name=${1:?}

	yq -i "del(.[\"${REPO_KEY}\"].[\"${repo_name}\"])" "$CONFIG_FILE_PATH"
}

config__repo__list() {
	debug "$*"
	config__create_file_if_not_exist

	local result
	result=$(yq ".[\"${REPO_KEY}\"] | keys | .[]" "$CONFIG_FILE_PATH" 2>/dev/null) || true

	if [[ -n "$result" && "$result" != "null" ]]; then
		echo "$result"
	fi
}

config__repo__get() {
	debug "$*"
	config__create_file_if_not_exist
	local repo_name="${1:?}"

	local result
	result=$(yq -r ".[\"${REPO_KEY}\"].[\"${repo_name}\"]" "$CONFIG_FILE_PATH")

	if [[ "$result" == "null" ]]; then
		return 1
	fi

	# Merge: defaults (base) * stored (override) -- stored wins
	local defaults
	defaults=$(config__repo__obj_defaults "$repo_name")
	result=$(echo "$result" | yq 'del(.. | select(. == null))')
	echo "$defaults" | result="$result" yq '. * env(result)'
}

config__repo__obj_create() {
	local repo_originurl="${1:?}" repo_dir="${2:?}"
	local repo_name
	repo_name="$(basename "$repo_dir")"
	# Factory default dir gets overwritten by explicit repo_dir from caller
	local defaults
	defaults=$(config__repo__obj_defaults "$repo_name")
	echo "$defaults" |
		repo_originurl="$repo_originurl" repo_dir="$repo_dir" \
			yq ". * {\"${REPO_ORIGINURL_KEY}\": env(repo_originurl), \"${REPO_DIRECTORY_KEY}\": env(repo_dir)}"
}

config__repo__obj_defaults() {
	debug "$*"
	local repo_name="${1:?}"

	local repo_dir
	repo_dir="$(const__get_repo_dir "$repo_name")"

	echo "{
		\"${REPO_DIRECTORY_KEY}\": \"${repo_dir}\"
	}" | yq '.'
}

config__repo__obj_set_directory() {
	debug "$*"
	local repo_obj="${1:?}" value="${2:?}"

	echo "$repo_obj" | yq ".[\"$REPO_DIRECTORY_KEY\"] = \"$value\""
}

config__repo__obj_get_directory() {
	debug "$*"
	local repo_obj="${1:?}"

	echo "$repo_obj" | yq -r ".[\"$REPO_DIRECTORY_KEY\"]" | yq__normalize_null
}

config__repo__obj_set_originurl() {
	debug "$*"
	local repo_obj="${1:?}" value="${2:?}"

	echo "$repo_obj" | yq ".[\"$REPO_ORIGINURL_KEY\"] = \"$value\""
}

config__repo__obj_get_originurl() {
	debug "$*"
	local repo_obj="${1:?}"

	echo "$repo_obj" | yq -r ".[\"$REPO_ORIGINURL_KEY\"]" | yq__normalize_null
}

config__repo__obj_set_post_copy_hook() {
	debug "$*"
	local repo_obj="${1:?}" value="${2:?}"

	echo "$repo_obj" | value="${value}" yq ".[\"$REPO_POST_COPY_HOOK_KEY\"] = [strenv(value)]"
}

config__repo__obj_get_post_copy_hook() {
	debug "$*"
	local repo_obj="${1:?}"

	echo "$repo_obj" | yq -r ".[\"$REPO_POST_COPY_HOOK_KEY\"][]" | yq__normalize_null
}

config__create_file_if_not_exist() {
	if [[ ! -f "$CONFIG_FILE_PATH" ]]; then
		mkdir -p "$REPOS_DIR"
		mkdir -p "$WORKSPACES_DIR"
		touch "$CONFIG_FILE_PATH"
	fi
}

##################################
##### Yaml File Layer Config #####
##################################

config__layer__put() {
	debug "$*"
	config__create_file_if_not_exist
	local layer_name="${1:?}"
	local layer_obj="${2:?}"

	layer_name="${layer_name}" layer_obj="${layer_obj}" yq -i ".[\"${LAYER_KEY}\"].[\"${layer_name}\"] = env(layer_obj)" "$CONFIG_FILE_PATH"
}

config__layer__delete__idempotent() {
	debug "$*"
	config__create_file_if_not_exist
	local layer_name="${1:?}"

	yq -i "del(.[\"${LAYER_KEY}\"].[\"${layer_name}\"])" "$CONFIG_FILE_PATH"
}

config__layer__list() {
	debug "$*"
	config__create_file_if_not_exist

	local result
	result=$(yq ".[\"${LAYER_KEY}\"] | keys | .[]" "$CONFIG_FILE_PATH" 2>/dev/null) || true

	if [[ -n "$result" && "$result" != "null" ]]; then
		echo "$result"
	fi
}

config__layer__get() {
	debug "$*"
	config__create_file_if_not_exist

	local layer_name="${1:?}"

	local result
	result=$(yq -r ".[\"${LAYER_KEY}\"].[\"${layer_name}\"]" "$CONFIG_FILE_PATH")

	if [[ "$result" == "null" ]]; then
		return 1
	fi

	# Merge: defaults (base) * stored (override) -- stored wins
	local defaults
	defaults=$(config__layer__obj_defaults "$layer_name")
	echo "$defaults" | result="$result" yq '. * env(result)'
}

config__layer__obj_create() {
	debug "$*"

	local layer_desc="${1:?}"
	shift

	if [[ $(($# % 2)) -ne 0 ]]; then
		fatal "[config__layer__obj_create] assertion error: should have even number of arguments after the description."
	fi

	local result
	result=$(layer_desc="$layer_desc" yq -n "{\"${LAYER_DESCRIPTION_KEY}\": strenv(layer_desc), \"${LAYER_FILES_KEY}\": []}")

	while [[ $# -gt 0 ]]; do
		local path="$1"
		local contents="$2"
		shift 2
		result=$(echo "$result" | path="$path" contents="$contents" yq ".[\"${LAYER_FILES_KEY}\"] += [{\"${LAYER_FILE_RELATIVE_PATH_KEY}\": strenv(path), \"${LAYER_FILE_CONTENTS_KEY}\": strenv(contents)}]")
	done

	echo "$result"
}

config__layer__obj_defaults() {
	debug "$*"

	echo "{
		\"${LAYER_DESCRIPTION_KEY}\": \"\",
		\"${LAYER_FILES_KEY}\": []
	}" | yq "."
}

config__layer__obj_get_description() {
	debug "$*"
	local layer_obj="${1:?}"

	echo "$layer_obj" | yq -r ".[\"${LAYER_DESCRIPTION_KEY}\"]" | yq__normalize_null
}

config__layer__obj_set_description() {
	debug "$*"
	local layer_obj="${1:?}" value="${2:?}"

	echo "$layer_obj" | value="$value" yq ".[\"${LAYER_DESCRIPTION_KEY}\"] = strenv(value)"
}

config__layer__obj_get_files() {
	debug "$*"
	local layer_obj="${1:?}"

	echo "$layer_obj" | yq -r ".[\"${LAYER_FILES_KEY}\"]" | yq__normalize_null
}

config__layer__obj_set_files() {
	debug "$*"
	local layer_obj="${1:?}"
	shift

	if [[ $(($# % 2)) -ne 0 ]]; then
		fatal "[config__layer__obj_set_files] assertion error: should have even number of arguments (path/contents pairs)."
	fi

	local result
	result=$(echo "$layer_obj" | yq ".[\"${LAYER_FILES_KEY}\"] = []")

	while [[ $# -gt 0 ]]; do
		local path="$1"
		local contents="$2"
		shift 2
		result=$(echo "$result" | path="$path" contents="$contents" yq ".[\"${LAYER_FILES_KEY}\"] += [{\"${LAYER_FILE_RELATIVE_PATH_KEY}\": strenv(path), \"${LAYER_FILE_CONTENTS_KEY}\": strenv(contents)}]")
	done

	echo "$result"
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

	git -C "$repo_dir" remote get-url origin || true
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

# Returns $GIT_WORKTREE_ALREADY_EXISTS_RETURN_CODE (42) if worktree already exists.
# Callers must use `|| rc=$?` to avoid set -e aborting on the non-zero return.
git__create_workspace_worktree() {
	debug "$*"
	local source_repo_dir="$1"
	local destination_worktree_dir="$2"
	local branch_name="$3"

	if git__check_worktree_exists "$source_repo_dir" "$destination_worktree_dir"; then
		debug "Git worktree already exists" "$source_repo_dir" to "$destination_worktree_dir"
		return $GIT_WORKTREE_ALREADY_EXISTS_RETURN_CODE
	fi

	# Empty repos (no commits) have no valid HEAD, so git worktree add fails.
	# Bootstrap with an empty commit so branches can be created.
	if ! git -C "$source_repo_dir" rev-parse HEAD &>/dev/null; then
		debug "Empty repository detected, creating initial commit"
		git -C "$source_repo_dir" commit --allow-empty -m "Initial commit"
	fi

	# Try creating with new branch first; if branch already exists, use it directly
	if ! git -C "$source_repo_dir" worktree add -b "$branch_name" "$destination_worktree_dir"; then
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

	debug "Removing worktree at $destination_worktree_dir..."
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

	if ! git -C "$destination_worktree_dir" checkout -b "$checkout_branch_name" && ! git -C "$destination_worktree_dir" checkout "$checkout_branch_name"; then
		warn "Failed to checkout branch $checkout_branch_name on $destination_worktree_dir"
		return 1
	fi
}

git__set_upstream_branch() {
	debug "$*"
	local repo_dir="$1"
	local branch_name="$2"

	if ! git -C "$repo_dir" branch --set-upstream-to="origin/$branch_name" "$branch_name"; then
		warn "Failed to set upstream branch origin/$branch_name for $branch_name in $repo_dir"
		return 1
	fi
}

git__pull() {
	debug "$*"
	local repo_dir="$1"

	if ! git -C "$repo_dir" pull; then
		warn "Failed to pull in $repo_dir"
		return 1
	fi
}

git__get_branch() {
	debug "$*"
	local repo_dir="$1"
	git -C "$repo_dir" rev-parse --abbrev-ref HEAD
}

git__reset_to_origin() {
	debug "$*"
	local repo_dir="$1"

	local branch
	branch=$(git__get_branch "$repo_dir")
	if [[ -z "$branch" || "$branch" == "HEAD" ]]; then
		warn "Could not determine current branch in $repo_dir"
		return 1
	fi

	if ! git__fetch_origin "$repo_dir"; then
		return 1
	fi

	if ! git__reset_hard "$repo_dir" "origin/$branch"; then
		return 1
	fi
}

git__fetch_origin() {
	debug "$*"
	local repo_dir="$1"

	if ! git -C "$repo_dir" fetch origin; then
		warn "Failed to fetch origin in $repo_dir"
		return 1
	fi
}

git__reset_hard() {
	debug "$*"
	local repo_dir="$1"
	local ref="$2"

	if ! git -C "$repo_dir" reset --hard "$ref"; then
		warn "Failed to reset to $ref in $repo_dir"
		return 1
	fi
}

######################
##### Filesystem #####
######################

##################
### Temp Files ###
##################

fs__tempfile__safe_create() {
	local temp_dir
	temp_dir=$(mktemp -d)
	chmod 700 "$temp_dir"

	local temp_file
	temp_file=$(mktemp "$temp_dir/tmp.XXXXXX")
	chmod 600 "$temp_file"

	echo "$temp_file"
}

fs__tempfile__open() {
	local temp_file="${1:?}" editor="${2:?}"
	# editor may contain arguments (e.g., "code --wait"), so we need eval
	eval "${editor}" '"${temp_file}"'
}

fs__tempfile__write() {
	local temp_file="${1:?}" content="${2:?}"
	printf '%s' "$content" >"${temp_file}"
}

fs__tempfile__read() {
	local temp_file="${1:?}"
	cat "${temp_file}"
}

fs__tempfile__clean() {
	local temp_file="${1:?}"
	rm "$temp_file" && rmdir "$(dirname "$temp_file")" || true
}

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

fs__layer__read() {
	local dir_path="${1:?}"
	shift
	local excluded_subpaths=("${@+"$@"}")

	while IFS= read -r file_path; do
		[[ -z "$file_path" ]] && continue
		echo "$file_path"
		env__portable_base64_encode < "$file_path"
	done <<< "$(fs__layer__get__files "$dir_path" "${excluded_subpaths[@]+"${excluded_subpaths[@]}"}")"
}

fs__layer__clear() {
	local dir_path="${1:?}"
	shift
	local excluded_subpaths=("${@+"$@"}")

	while IFS= read -r file_path; do
		[[ -z "$file_path" ]] && continue
		rm -f "$file_path"
	done <<< "$(fs__layer__get__files "$dir_path" "${excluded_subpaths[@]+"${excluded_subpaths[@]}"}")"

	# Remove empty directories bottom-up (reverse order so children before parents)
	local dirs=()
	while IFS= read -r dir_entry; do
		[[ -z "$dir_entry" ]] && continue
		dirs+=("$dir_entry")
	done <<< "$(fs__layer__get__dirs "$dir_path" "${excluded_subpaths[@]+"${excluded_subpaths[@]}"}")"

	local i
	for (( i=${#dirs[@]}-1; i>=0; i-- )); do
		rmdir "${dirs[$i]}" 2>/dev/null || true
	done
}

fs__layer__write() {
	local dir_path="${1:?}"
	shift

	if [[ $(($# % 2)) -ne 0 ]]; then
		fatal "[fs__layer__write] assertion error: should have even number of arguments after the directory path."
	fi

	local args=("$@")
	local i
	for (( i=0; i<${#args[@]}; i=i+2 )); do
		local path="${args[$i]}"
		if [[ -e "$path" ]]; then
			warn "Error while writing layered files: $path already exists"
			return 1
		fi
	done

	while [[ $# -gt 0 ]]; do
		local path="$1"
		local contents="$2"
		shift 2
		debug "Writing contents into file $path"
		echo "$contents" | env__portable_base64_decode > "$path"
	done
}

# Common find helper: fs__layer__find <dir_path> <find_type> <extra_find_args...> -- <excluded_subpaths...>
fs__layer__find() {
	local dir_path="${1:?}"
	local find_type="${2:?}"
	shift 2

	# Collect extra find args before "--"
	local extra_args=()
	while [[ $# -gt 0 && "$1" != "--" ]]; do
		extra_args+=("$1")
		shift
	done
	[[ "${1:-}" == "--" ]] && shift

	if [[ $# -eq 0 ]]; then
		find "$dir_path" "${extra_args[@]+"${extra_args[@]}"}" -type "$find_type" -print
		return 0
	fi

	local prune_expr=("(")
	local first=true
	for subpath in "$@"; do
		[[ -z "$subpath" ]] && continue
		if [[ "$first" == true ]]; then
			first=false
		else
			prune_expr+=("-o")
		fi
		prune_expr+=("-path" "$subpath")
	done
	prune_expr+=(")" "-prune" "-o")

	find "$dir_path" "${extra_args[@]+"${extra_args[@]}"}" "${prune_expr[@]}" -type "$find_type" -print
}

fs__layer__get__files() {
	local dir_path="${1:?}"
	shift
	fs__layer__find "$dir_path" f -- "$@"
}

fs__layer__get__dirs() {
	local dir_path="${1:?}"
	shift
	fs__layer__find "$dir_path" d -mindepth 1 -- "$@"
}

# lock (mkdir-based, atomic on all filesystems)
fs__acquire_lock() {
	if ! [[ -d "$PROJ_DIR" ]]; then
		mkdir -p "$PROJ_DIR"
	fi

	# Detect and clean up stale locks from dead processes
	local pid_file="$CONFIG_FILE_LOCK_DIR_PATH/pid"
	if [[ -d "$CONFIG_FILE_LOCK_DIR_PATH" && -f "$pid_file" ]]; then
		local stale_pid
		stale_pid=$(<"$pid_file")
		if ! kill -0 "$stale_pid" 2>/dev/null; then
			warn "Removing stale lock from dead process (PID $stale_pid)"
			rmdir "$CONFIG_FILE_LOCK_DIR_PATH" 2>/dev/null || fs__safe_rm_rf "$CONFIG_FILE_LOCK_DIR_PATH" "$PROJ_DIR"
		fi
	fi

	if ! mkdir "$CONFIG_FILE_LOCK_DIR_PATH" 2>/dev/null; then
		info "Another process is running $SCRIPT_NAME. Attempting to acquire lock..."
		local retries=100
		while ! mkdir "$CONFIG_FILE_LOCK_DIR_PATH" 2>/dev/null; do
			retries=$((retries - 1))
			if [[ $retries -eq 0 ]]; then
				fatal "Error: Could not acquire lock. Check if there is another instance of $SCRIPT_NAME, or delete the lock directory $CONFIG_FILE_LOCK_DIR_PATH manually."
			fi
			sleep 0.1
		done
	fi

	# Record our PID so other instances can detect stale locks
	echo $$ >"$CONFIG_FILE_LOCK_DIR_PATH/pid"
}

fs__release_lock() {
	if [[ -d "$CONFIG_FILE_LOCK_DIR_PATH" ]]; then
		rm -f "$CONFIG_FILE_LOCK_DIR_PATH/pid"
		rmdir "$CONFIG_FILE_LOCK_DIR_PATH"
	fi
}

# Portable realpath
# macOS realpath lacks -m flag, and fails for nonexistent file/dirs
fs__resolve_path() {
	local target="$1"
	if realpath "$target" 2>/dev/null; then
		return
	fi

	echo "$(fs__resolve_path "$(dirname "$target")")/$(basename "$target")"
}

fs__safe_rm_rf() {
	debug "$*"
	local target="$1"
	local allowed_parent="$2"

	if [[ -z "$target" || "$target" == "/" ]]; then
		echo "[FATAL] Refusing to rm -rf empty or root path" >&2
		exit 1
	fi

	local resolved
	resolved="$(fs__resolve_path "$target")"
	local resolved_parent
	resolved_parent="$(fs__resolve_path "$allowed_parent")"

	if [[ "$resolved" != "$resolved_parent"/* ]]; then
		echo "[FATAL] Refusing to delete '$resolved' — not under '$resolved_parent'" >&2
		exit 1
	fi

	rm -rf "$resolved"
}

fs__create_relative_file_path() {
	local file="${1:?}"
	local directory="${2:?}"

	# Ensure directory ends with / for prefix matching
	local dir_prefix="${directory%/}/"

	if [[ "$file" != "$dir_prefix"* ]]; then
		return 1
	fi

	echo "${file#"$dir_prefix"}"
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

sh__run_bash_script_in_dir() {
	echo "$*"
	# TODO: maybe should create a file in the directory and just invoke it
	# This allows the user to use the shebang to use the interpreter they want
	# But this is such a pain in the ass to do it properly without any
	# TOCTOU security vulnerabilities. So i'll keep it that way
	local dir="${1:?}" script_contents="${2:?}"
	(cd "${dir}" && /usr/bin/env bash -s <<<"${script_contents}")
}

# Normalize yq "null" output to empty string.
# yq -r returns the literal string "null" for missing/null fields.
# Usage: echo "$obj" | yq -r '.field' | yq__normalize_null
yq__normalize_null() {
	local value
	value=$(cat)
	if [[ "$value" == "null" ]]; then
		echo ""
	else
		echo "$value"
	fi
}

const__get_repo_dir() {
	local repo_name="$1"
	echo "$REPOS_DIR/$repo_name"
}

env__portable_base64_encode() {
	if env_is_macos; then
		base64
	else
		base64 -w 0
		echo
	fi
}

env__portable_base64_decode() {
	if env_is_macos; then
		base64 -D
	else
		base64 -d
	fi
}

_OWS_IS_MACOS=""
env_is_macos() {
	if [[ -z "$_OWS_IS_MACOS" ]]; then
		if [[ "$(uname)" == "Darwin" ]]; then
			_OWS_IS_MACOS=1
		else
			_OWS_IS_MACOS=0
		fi
	fi
	[[ "$_OWS_IS_MACOS" == "1" ]]
}

env__get_caller_workspace() {
	local best_match=""
	local workspace_name workspace_dir
	for workspace_name in $(config__workspace__list); do
		workspace_dir="$(fs__workspace_get_dir "$workspace_name")"
		if [[ "$PWD" == "$workspace_dir"/* || "$PWD" == "$workspace_dir" ]]; then
			if [[ ${#workspace_name} -gt ${#best_match} ]]; then
				best_match="$workspace_name"
			fi
		fi
	done
	if [[ -n "$best_match" ]]; then
		echo "$best_match"
		return 0
	fi
	return 1
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
