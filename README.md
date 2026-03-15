# OmniWorkspace

A multi-repo workspace manager that groups git repositories into named workspaces using git worktrees. Operate on multiple repos as a unit — create branches, run commands, and switch contexts across all of them at once.

## Install

**Dependencies:** `git`, [`yq`](https://github.com/mikefarah/yq)

```bash
# macOS
brew install git yq

# Install ows
./dev-install.sh
```

This symlinks `main.sh` to `/usr/local/bin/ows`.

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
```

**Command aliases:** `workspace` can be shortened to `ws`, `w`, or `wsp`. `repo` can be shortened to `r`.

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
- **Important:** Do not manually check out branches inside workspace repo directories (e.g. via `git checkout`). Use `ows workspace checkout` instead — it keeps the config and all worktrees in sync. Manually switching branches can cause the workspace state to diverge from `config.yaml`.

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
workspaces:
  my-feature:
    repos:
      - frontend
      - backend
    branch: feature/new-auth
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
DEBUG=1 ows …  # Enable debug logging with stack traces
```

## Name Rules

Workspace names, repo names, and branch names must contain only alphanumeric characters, dashes, underscores, and at most one forward slash.
