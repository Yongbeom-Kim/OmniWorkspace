#!/usr/bin/env bash

set -euo pipefail

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

PROJ_DIR="$HOME/.ows"
REPOS_DIR="$PROJ_DIR/repos"


main() {
    debug $LINENO "[main]" "$*"
    dependency__assert_git
    dependency__assert_docker
    dependency__assert_yq

    local cmd="$1"

    case "$cmd" in
        "repos")
            shift
            cmd__repo__list "$@"
            ;;
        "repo")
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
    config__repo__create_file_if_not_exist

    local config_path="$REPOS_DIR/config.yaml"

    local repos=($(config__repo__list))
    
    for repo in "${repos[@]}"; do
        printf "%-20s | %-20s | %-20s\n" "$repo" "$(config__repo__get_originurl "$repo")" "$(config__repo__get_dir "$repo")"
    done
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
        return 1
    fi

    if ! [[ -d "$repo_dir" ]]; then
        warn "Repository $repo_alias does not exist."
        return 1
    fi

    if ! config__repo__remove "$repo_alias"; then
        warn "Failed to remove repository $repo_alias from config."
        return 1
    fi

    echo "Repository $repo_alias removed successfully."
}

# Validate all repos.
repo__validate_all() {
    debug $LINENO "[repo__validate_all]" "$*"
    config__repo__create_file_if_not_exist

    # 1. Validate repo config
    config__repo__list | while read -r repo_alias; do
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
            if [[ "$config_dir" == "$fs_dir" ]]; then  # also: != → ==
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

config__repo__create_file_if_not_exist() {
    debug $LINENO "[config__repo__create_file_if_not_exist]" "$*"
    local config_path="$REPOS_DIR/config.yaml"
    if [[ ! -f "$config_path" ]]; then
        mkdir -p "$REPOS_DIR"
        touch "$config_path"
    fi
}

config__repo__set() {
    debug $LINENO "[config__repo__set]" "$*"
    config__repo__create_file_if_not_exist

    local repo_url=${1:?}
    local repo_alias=${2:?}
    local repo_dir=${3:?}

    local config_path="$REPOS_DIR/config.yaml"
    # yq eval ".repos += [{name: \"$repo_alias\", url: \"$repo_url\"}]" -i "$config_path"
    yq -i ".repos.${repo_alias} = {\"origin_url\": \"$repo_url\", \"dir\": \"$repo_dir\"}" "$config_path"
}

config__repo__remove() {
    debug $LINENO "[config__repo__remove]" "$*"
    config__repo__create_file_if_not_exist
    local repo_alias=${1:?}

    local config_path="$REPOS_DIR/config.yaml"
    yq -i "del(.repos.${repo_alias})" "$config_path"
}

config__repo__list() {
    debug $LINENO "[config__repo__list]" "$*"
    config__repo__create_file_if_not_exist
    yq '.repos | keys | .[]' "$REPOS_DIR/config.yaml"
}

config__repo__get_dir() {
    debug $LINENO "[config__repo__get_dir]" "$*"
    config__repo__create_file_if_not_exist
    local repo_alias=${1:?}

    local config_path="$REPOS_DIR/config.yaml"
    local return=$(yq -r ".repos.${repo_alias}.dir" "$config_path")
    if [[ "$return" == "null" ]]; then
        echo ""
    else
        echo "$return"
    fi
}

config__repo__get_originurl() {
    debug $LINENO "[config__repo__get_originurl]" "$*"
    config__repo__create_file_if_not_exist
    local repo_alias=${1:?}

    local config_path="$REPOS_DIR/config.yaml"
    local return=$(yq -r ".repos.${repo_alias}.origin_url" "$config_path")
    if [[ "$return" == "null" ]]; then
        echo ""
    else
        echo "$return"
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
    if ! command -v $dependency &> /dev/null; then
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



main "$@"