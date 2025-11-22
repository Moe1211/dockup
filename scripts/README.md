# DockUp Scripts

This directory contains utility scripts for DockUp development and maintenance.

## Scripts

### `pre-commit-checks.sh`
Comprehensive pre-commit checks that run:
- Shell script syntax validation
- Go code formatting checks
- Go vet static analysis
- Go tests
- ShellCheck linting
- JSON validation
- Markdown linting
- Common issue detection

**Usage:**
```bash
./scripts/pre-commit-checks.sh
```

### `check-version.sh`
Validates version consistency across DockUp files.

**Usage:**
```bash
./scripts/check-version.sh
```

### Demo Recording Scripts

Demo recording scripts have been moved to `social/demos/`. See:
- `social/demos/record-demo.sh` - Helper script to record DockUp demo GIFs
- `social/demos/demo.tape` - VHS script for automated demo recording
- `social/demos/create-demo-gif.md` - Detailed instructions
- `social/demos/DEMO-QUICKSTART.md` - Quick start guide

### `post-commit-tag.sh`
Automatically creates a git tag when `DOCKUP_VERSION` is updated in the `dockup` file.

**How it works:**
- Runs after each commit
- Checks if the `dockup` file was modified
- Extracts `DOCKUP_VERSION` from the file
- Creates a git tag (e.g., `v1.0.13`) if it doesn't already exist
- Uses the commit message as the tag annotation

**Usage:**
This script runs automatically via the post-commit git hook. To run manually:
```bash
./scripts/post-commit-tag.sh
```

**Note:** The script automatically pushes the commit and tags to the remote repository (`origin`). If the push fails (e.g., no network, authentication issues), it will show a warning but won't fail the commit. You can manually push later if needed:
```bash
git push origin main --tags
```

## Integration

These scripts are automatically run by:
- Git pre-commit hook (`.git/hooks/pre-commit`)
- Git post-commit hook (`.git/hooks/post-commit`)
- Pre-commit framework (`.pre-commit-config.yaml`)
- Makefile (`make pre-commit`, `make install-hooks`)

## Requirements

- `bash` - Shell interpreter
- `go` - Go compiler (for Go checks)
- `jq` - JSON processor (optional, for JSON validation)
- `shellcheck` - Shell script linter (optional)
- `markdownlint` - Markdown linter (optional)

## Installation

Install optional tools:
```bash
# macOS
brew install shellcheck jq
npm install -g markdownlint-cli

# Linux
sudo apt-get install shellcheck jq
npm install -g markdownlint-cli
```

