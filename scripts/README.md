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

### `record-demo.sh`
Helper script to record DockUp demo GIFs using various tools (VHS, asciinema, ttyrec).

**Usage:**
```bash
# Using VHS (recommended - scripted)
./scripts/record-demo.sh vhs demo.gif

# Using asciinema (manual recording)
./scripts/record-demo.sh asciinema demo.gif

# Using ttyrec (simple)
./scripts/record-demo.sh ttyrec demo.gif
```

See `create-demo-gif.md` for detailed instructions.

### `demo.tape`
VHS script for automated demo recording. Edit this file to customize the demo flow.

**Usage:**
```bash
vhs scripts/demo.tape
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

