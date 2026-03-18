#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TESTS_FILE="$SCRIPT_DIR/tests.yaml"
IMAGE_NAME="ows-test"
VERBOSE=0

# Parse flags
while [[ $# -gt 0 ]]; do
    case "$1" in
        -v) VERBOSE=1; shift ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

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
build_image() {
    echo "Building test image..."
    if [[ "$VERBOSE" -eq 1 ]]; then
        docker build -t "$IMAGE_NAME" -f "$SCRIPT_DIR/TestImage.Dockerfile" "$REPO_ROOT"
    else
        docker build -t "$IMAGE_NAME" -f "$SCRIPT_DIR/TestImage.Dockerfile" "$REPO_ROOT" &>/dev/null
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

# Run all tests
run_tests() {
    local test_count
    test_count=$(yq '.tests | length' "$TESTS_FILE")

    if [[ "$test_count" -eq 0 ]]; then
        echo "No tests found"
        exit 0
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

        local container_name="ows-test-$i"
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
        if ! docker run -d --name "$container_name" -v "$HOME/.ssh:/root/.ssh:ro" "$IMAGE_NAME" &>/dev/null; then
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
        exit 1
    fi
}

# Main flow
check_prerequisites
build_image
run_tests
