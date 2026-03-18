#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TESTS_FILE="$SCRIPT_DIR/tests.yaml"
VERBOSE=0
DOCKERFILES=()

# Parse flags
while [[ $# -gt 0 ]]; do
    case "$1" in
        -v) VERBOSE=1; shift ;;
        -f) DOCKERFILES+=("$2"); shift 2 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

# Default to all Dockerfiles if none specified
if [[ ${#DOCKERFILES[@]} -eq 0 ]]; then
    for f in "$SCRIPT_DIR"/*Image.Dockerfile; do
        DOCKERFILES+=("$f")
    done
fi

# Prerequisite checks
check_prerequisites() {
    if ! command -v docker &>/dev/null; then
        echo "Error: docker is not installed or not in PATH" >&2
        exit 1
    fi
    if ! docker info &>/dev/null; then
        echo "Error: docker is not running" >&2
        exit 1
    fi
    if ! command -v yq &>/dev/null; then
        echo "Error: yq is not installed or not in PATH" >&2
        exit 1
    fi
    if [[ ! -d "$HOME/.ssh" ]]; then
        echo "Error: ~/.ssh directory not found" >&2
        exit 1
    fi
}

# Build test image
# Args: $1 = dockerfile path, $2 = image name
build_image() {
    local dockerfile="$1"
    local image_name="$2"
    echo "Building $image_name from $(basename "$dockerfile")..."
    if [[ "$VERBOSE" -eq 1 ]]; then
        docker build -t "$image_name" -f "$dockerfile" "$REPO_ROOT"
    else
        docker build -t "$image_name" -f "$dockerfile" "$REPO_ROOT" &>/dev/null
    fi
}

# Run a single hook inside the container
run_hook() {
    local container="$1"
    local hook_name="$2"
    local hook_body="$3"

    if [[ "$VERBOSE" -eq 1 ]]; then
        echo "  [$hook_name] $hook_body"
        docker exec "$container" bash -c "$hook_body"
    else
        docker exec "$container" bash -c "$hook_body" &>/dev/null
    fi
}

# Run all tests against a given image
# Args: $1 = image name
run_tests() {
    local image_name="$1"
    local test_count
    test_count=$(yq '.tests | length' "$TESTS_FILE")

    if [[ "$test_count" -eq 0 ]]; then
        echo "No tests found"
        return 0
    fi

    local passed=0
    local failed=0

    for ((i = 0; i < test_count; i++)); do
        local name
        local prepare
        local test_cmd
        local verify
        name=$(yq ".tests[$i].name" "$TESTS_FILE")
        prepare=$(yq ".tests[$i].prepare" "$TESTS_FILE")
        test_cmd=$(yq ".tests[$i].test" "$TESTS_FILE")
        verify=$(yq ".tests[$i].verify" "$TESTS_FILE")

        local container_name="${image_name}-$i"
        local test_passed=1

        # Print test header
        if [[ "$VERBOSE" -eq 1 ]]; then
            echo "[$((i + 1))/$test_count] $name"
        else
            printf "[%d/%d] %s ... " "$((i + 1))" "$test_count" "$name"
        fi

        # Clean up stale container
        docker rm -f "$container_name" &>/dev/null || true

        # Start fresh container
        if ! docker run -d --name "$container_name" -v "$HOME/.ssh:/root/.ssh:ro" "$image_name" &>/dev/null; then
            test_passed=0
        fi

        # Run hooks (short-circuit on failure)
        if [[ "$test_passed" -eq 1 ]] && [[ "$prepare" != "null" ]]; then
            if ! run_hook "$container_name" "prepare" "$prepare"; then
                test_passed=0
            fi
        fi

        if [[ "$test_passed" -eq 1 ]] && [[ "$test_cmd" != "null" ]]; then
            if ! run_hook "$container_name" "test" "$test_cmd"; then
                test_passed=0
            fi
        fi

        if [[ "$test_passed" -eq 1 ]] && [[ "$verify" != "null" ]]; then
            if ! run_hook "$container_name" "verify" "$verify"; then
                test_passed=0
            fi
        fi

        # Cleanup container
        docker rm -f "$container_name" &>/dev/null || true

        # Report result
        if [[ "$test_passed" -eq 1 ]]; then
            passed=$((passed + 1))
            if [[ "$VERBOSE" -eq 1 ]]; then
                echo "  PASS"
            else
                echo "PASS"
            fi
        else
            failed=$((failed + 1))
            if [[ "$VERBOSE" -eq 1 ]]; then
                echo "  FAIL"
            else
                echo "FAIL"
            fi
        fi
    done

    echo ""
    echo "Results: $passed passed, $failed failed"

    if [[ "$failed" -gt 0 ]]; then
        return 1
    fi
}

# Derive image name from dockerfile name
# e.g. TestImage.Dockerfile -> ows-test, AppleImage.Dockerfile -> ows-apple
image_name_from_dockerfile() {
    local basename
    basename="$(basename "$1" .Dockerfile)"
    basename="${basename%Image}"
    echo "ows-$(echo "$basename" | tr '[:upper:]' '[:lower:]')"
}

# Main flow
check_prerequisites

any_failed=0
for dockerfile in "${DOCKERFILES[@]}"; do
    image_name="$(image_name_from_dockerfile "$dockerfile")"
    echo ""
    echo "=== $image_name ($(basename "$dockerfile")) ==="
    echo ""
    build_image "$dockerfile" "$image_name"
    if ! run_tests "$image_name"; then
        any_failed=1
    fi
done

if [[ "$any_failed" -eq 1 ]]; then
    exit 1
fi
