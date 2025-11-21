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

## Integration

These scripts are automatically run by:
- Git pre-commit hook (`.git/hooks/pre-commit`)
- Pre-commit framework (`.pre-commit-config.yaml`)
- Makefile (`make pre-commit`)

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

