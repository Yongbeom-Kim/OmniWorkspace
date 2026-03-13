#!/usr/bin/env bash

PROJ_DIR="$HOME/.ows"
REPOS_DIR="$PROJ_DIR/repos"


main() {
    dependency__assert_git
    dependency__assert_docker
    dependency__assert_yq

    local cmd="$1"

    case "$cmd" in
        "add-repo")
            shift
            cmd__add_repo "$@"
            ;;
        "remove-repo")
            shift
            cmd__remove_repo "$@"
            ;;
        "list-repo" | "list-repos" | "repos")
            shift
            cmd__list_repos "$@"
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

cmd__add_repo() {
    local repo_url=$1
    local repo_name=$(basename "$repo_url" .git)
    local repo_alias=${2:-$repo_name}

    if ! git__add_repo "$repo_url" "$repo_alias"; then
        echo "Failed to add repository $repo_alias."
        return 1
    fi

    if ! config__repo__add "$repo_url" "$repo_alias"; then
        echo "Failed to add repository $repo_alias to config."
        return 1
    fi

    echo "Repository $repo_alias added successfully."
}

cmd__remove_repo() {
    local repo_alias=$1
    local repo_dir="$REPOS_DIR/$repo_alias"

    if ! [[ -d "$repo_dir" ]]; then
        echo "Repository $repo_alias does not exist."
        return 1
    fi

    if ! rm -rf "$repo_dir"; then
        echo "Failed to remove repository $repo_alias."
        return 1
    fi

    if ! config__repo__remove "$repo_alias"; then
        echo "Failed to remove repository $repo_alias from config."
        return 1
    fi
}

cmd__list_repos() {
    config__repo__create_file_if_not_exist

    local config_path="$REPOS_DIR/config.yaml"
    yq -r '.repos | to_entries | map("\(.key): \(.value.url)") | .[]' "$config_path"
}

###############################
##### Yaml Configurations #####
###############################

config__repo__create_file_if_not_exist() {
    local config_path="$REPOS_DIR/config.yaml"
    if [[ ! -f "$config_path" ]]; then
        mkdir -p "$REPOS_DIR"
        touch "$config_path"
    fi
}

config__repo__add() {
    config__repo__create_file_if_not_exist

    local repo_url=${1:?}
    local repo_alias=${2:?}

    local config_path="$REPOS_DIR/config.yaml"
    # yq eval ".repos += [{name: \"$repo_alias\", url: \"$repo_url\"}]" -i "$config_path"
    yq -i ".repos.${repo_alias} = {\"url\": \"$repo_url\"}" "$config_path"
}

config__repo__remove() {
    config__repo__create_file_if_not_exist
    local repo_alias=${1:?}

    local config_path="$REPOS_DIR/config.yaml"
    yq -i "del(.repos.${repo_alias})" "$config_path"
}


#######################
##### Git Facades #####
#######################

git__add_repo() {
    local repo_url=${1:?}
    local repo_alias=${2:?}

    local repo_dir="$REPOS_DIR/$repo_alias"
    if [ -d "$repo_dir" ]; then
        echo "Repository $repo_alias already exists. Please choose a different alias."
        return 1
    fi

    if ! git clone "$repo_url" "$repo_dir"; then
        echo "Failed to clone repository $repo_alias."
        return 1
    fi
}


#############################
##### Dependency Checks #####
#############################

dependency__assert() {
    local dependency=$1
    local error_message=${2:-"$dependency is not installed. Please install $dependency and try again."}
    if ! command -v $dependency &> /dev/null; then
        echo "$error_message"
        exit 1
    fi
}

dependency__assert_git() {
    if env_is_macos; then
        dependency__assert "git" $'Git is required on macOS. Please install it with: \n brew install git \n and try again.'
    else
        dependency__assert "git"
    fi
}

dependency__assert_docker() {
    dependency__assert "docker"
}

dependency__assert_yq() {
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
    [[ "$(uname)" == "Darwin" ]]
}

main "$@"