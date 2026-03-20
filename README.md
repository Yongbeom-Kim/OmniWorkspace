# OmniWorkspace

A multi-repo workspace manager that groups git repositories into named workspaces using git worktrees. Operate on multiple repos as a unit — create branches, run commands, and switch contexts across all of them at once.

## Why did I make this tool?

In my work, I often need to manage multiple copies of multiple repos, and sometimes features need to have a combination of repos.

I might have something like:

```
~/Dev/
├── 1/ # Some feature
│   └── monorepo_1/
├── 2/ # A feature: I need to work across two repos.
│   ├── monorepo_1/ # Oh, a copy?
│   └── monorepo_2/
└── 3/ # OMG, i need to work across 4 repos for this feature
    ├── monorepo_3/
    ├── repo_1/
    ├── repo_2/
    └── repo_3/
```

This **sucks** for many reasons.
- Typically I would `git clone` multiple repos. But for multiple monorepos, the `.git` directory takes up an *incredible* amount of disk space. `.git` directories can take up to 2-10GB of space, depending on how big the repo is.
- I would also create and re-use directories with placeholder names (as you see, `1/`, `2/`, `3/`). But this is hard to understand and remember.

### Why not use `git worktree`?
I find `git worktree` to have a particularly bad developer experience. The main issue is that it creates worktrees *in the current repo's directory*. How are you supposed to work across different repos like this?

This tool wraps `git worktree` to compose workspaces from repositories.

Instead, I can do `ows workspace add my-feature monorepo_1 repo_1 repo_2 repo_3` to automatically create a directory with copies of all 4 repos.

This will create:

```
~/.ows/
└── workspaces/
    └── my-feature/
        ├── monorepo_1/
        ├── repo_1/
        ├── repo_2/
        └── repo_3/
```

And you can do `ows workspace cd my-feature` to cd into the workspace, or `ows workspace exec my-feature <command>` to execute something in the directory.

## Installation

**Dependencies:** `git`, [`yq`](https://github.com/mikefarah/yq), `base64`

```bash
# macOS
brew install git yq

# Install ows
curl -fsSL https://raw.githubusercontent.com/Yongbeom-Kim/OmniWorkspace/refs/heads/main/main.sh | sudo tee /usr/local/bin/ows > /dev/null && sudo chmod +x /usr/local/bin/ows

# Get the autocomplete
ows install
```

**For development**, clone the repo and symlink instead:

```bash
git clone https://github.com/Yongbeom-Kim/OmniWorkspace.git
cd OmniWorkspace
./dev-install.sh  # Symlinks main.sh to /usr/local/bin/ows
```

## Quick Start

```bash
# Register some repos
ows repo add https://github.com/org/frontend.git
ows repo add https://github.com/org/backend.git
ows repo add https://github.com/org/shared-lib.git

# Create a workspace with those repos
ows workspace add my-feature frontend backend shared-lib

# Check out a feature branch across all repos
ows workspace checkout my-feature -b feature/new-auth

# Run a command in the workspace
ows workspace exec my-feature code . # spawn a vs code instance
```

## Usage

### Repositories

Register git repos so they can be added to workspaces. Repos are cloned into `~/.ows/repos/`.

```bash
ows repo add <url> [name]      # Register and clone a repo (name derived from URL if omitted)
ows repo remove <name>         # Unregister and delete a repo
ows repo list                  # List all registered repos
ows repos                      # Shorthand for repo list
ows repo post-copy-hook <name> # Create/edit a post-copy hook script
```

### Workspaces

Group repos into workspaces. Each repo in a workspace gets a [git worktree](https://git-scm.com/docs/git-worktree) under `~/.ows/workspaces/<workspace>/<repo>`, sharing object storage with the main clone.

```bash
ows workspace add <name> [repos...]            # Create a workspace and/or add repos to it
ows workspace remove-repo <name> <repos...>    # Remove repos from a workspace
ows workspace delete <name>                    # Delete a workspace and its worktrees
ows workspace list                             # List all workspaces
ows workspaces                                 # Shorthand for workspace list
ows workspace exec <name> <command> [args...]  # Run a command in the workspace directory
ows workspace checkout <name> <branch>         # Check out a branch across all repos
ows workspace checkout <name> -b <branch>      # Same (the -b flag is accepted but optional)
ows workspace run-hooks <name>                 # Run post-copy hooks for all repos
```

**Command aliases:** `workspace` can be shortened to `ws`, `w`, or `wsp`. `repo` can be shortened to `r`.

### Layers

Layers let you snapshot and restore the non-repo files in a workspace (config files, notes, scripts — anything that isn't inside a git repo directory). This is useful for switching between different workspace configurations without losing setup.

```bash
ows layer save <workspace> <layer_name>    # Snapshot non-repo files into a named layer
ows layer load <workspace> <layer_name>    # Restore a layer (clears existing non-repo files first)
ows layer list                             # List all saved layers
ows layer delete <layer_name>              # Delete a saved layer
```

`layer` can also be accessed as a workspace subcommand (`ows workspace layer save ...`) and can be shortened to `l`.

When loading a layer, existing non-repo files in the workspace are cleared before the layer's files are written. Repo directories are never touched.

### Post-Copy Hooks

You can attach a bash script to any repo that runs automatically after a worktree is created (e.g., when adding a repo to a workspace). This is useful for running install steps, builds, or other setup.

```bash
ows repo post-copy-hook <repo_name>    # Open an editor to create/edit the hook
ows workspace run-hooks <workspace>    # Manually run all hooks for a workspace
```

Hooks are stored in `config.yaml` and executed with `bash`. If your hook uses `printf` with arguments starting with `-`, use `printf --` to avoid option parsing issues (e.g., `printf -- "--flag %s " "$var"`).

### Workspace Detection

When you `cd` into a workspace directory (`~/.ows/workspaces/<name>/...`), the tool auto-detects the workspace. This lets you omit the workspace name:

```bash
cd ~/.ows/workspaces/my-feature/frontend
ows ws add backend        # Adds backend to my-feature (auto-detected)
ows ws checkout new-branch # Checks out across my-feature
```

## How It Works

```
~/.ows/
├── config.yaml          # Source of truth for all repos and workspaces
├── repos/
│   ├── frontend/        # Bare-ish clones of registered repos
│   ├── backend/
│   └── shared-lib/
└── workspaces/
    └── my-feature/
        ├── frontend/    # Git worktree → repos/frontend
        ├── backend/     # Git worktree → repos/backend
        └── shared-lib/  # Git worktree → repos/shared-lib
```

- **Config-first:** YAML config is always written before filesystem changes. On startup, repos and workspaces are validated and self-heal from config if directories are missing.
- **Git worktrees:** Workspaces use worktrees rather than full clones, so they share the git object store and are lightweight.
- **Idempotent operations:** Commands are safe to re-run — adding an already-existing repo or workspace is a no-op.
- **Safety:** `rm -rf` operations are guarded to only delete within allowed parent directories under `$HOME`.

> **Warning:** Do not manually check out branches inside workspace repo directories (e.g. via `git checkout`). Use `ows workspace checkout` instead — it keeps the config and all worktrees in sync. Manually switching branches can cause the workspace state to diverge from `config.yaml`.

## Configuration

All state is stored in `~/.ows/config.yaml`:

```yaml
repos:
  frontend:
    origin_url: https://github.com/org/frontend.git
    dir: /Users/you/.ows/repos/frontend
  backend:
    origin_url: https://github.com/org/backend.git
    dir: /Users/you/.ows/repos/backend
    post-copy-hook:
      - |
        #!/bin/bash
        npm install
workspaces:
  my-feature:
    repos:
      - frontend
      - backend
    branch: feature/new-auth
layer:
  my-layer:
    description: my-layer
    files:
      - relative_path: notes.txt
        contents: <base64-encoded content>
```

The default data directory is `~/.ows`. Override with environment variables:

| Variable | Default | Description |
|---|---|---|
| `PROJ_DIR` | `~/.ows` | Root data directory |
| `REPOS_DIR` | `$PROJ_DIR/repos` | Where repos are cloned |
| `WORKSPACES_DIR` | `$PROJ_DIR/workspaces` | Where workspace worktrees live |

## Development

```bash
make setup    # Install pre-commit hook (runs shfmt)
make fmt      # Format main.sh with shfmt
make test     # Run tests (requires Docker)
DEBUG=1 ows …  # Enable debug logging with stack traces
```

### Running Tests

Tests run inside Docker containers against multiple bash environments for compatibility testing. You'll need [Docker](https://docs.docker.com/get-docker/) installed and running.

```bash
make test                # Run all tests against all images
make test-verbose        # Run with verbose output
make test-smoke          # Run tests against upstream bash 3.2 only (faster)
make test-smoke-verbose  # Smoke test with verbose output
```

**Test images:**

| Image | Dockerfile | Description |
|---|---|---|
| `ows-test` | `TestImage.Dockerfile` | Upstream GNU bash 3.2 |
| `ows-apple` | `AppleImage.Dockerfile` | Apple's bash-142 (macOS bash 3.2 with Apple patches) |


## Name Rules

Workspace names, repo names, and branch names must contain only alphanumeric characters, dashes, underscores, and at most one forward slash.
