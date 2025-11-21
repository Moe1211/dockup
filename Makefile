# Makefile for DockUp development

.PHONY: help test lint format check install-hooks clean

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-15s %s\n", $$1, $$2}'

test: ## Run Go tests
	@echo "🧪 Running Go tests..."
	@go test ./... -v

lint: ## Run all linters
	@echo "🔍 Running linters..."
	@echo "  - Go vet..."
	@go vet ./...
	@echo "  - ShellCheck..."
	@shellcheck dockup *.sh scripts/*.sh 2>/dev/null || echo "    (shellcheck not installed)"
	@echo "  - Markdown lint..."
	@markdownlint *.md 2>/dev/null || echo "    (markdownlint not installed)"
	@echo "✅ Linting complete"

format: ## Format Go code
	@echo "📝 Formatting Go code..."
	@gofmt -w *.go
	@goimports -w *.go 2>/dev/null || echo "  (goimports not installed, run: go install golang.org/x/tools/cmd/goimports@latest)"

check: ## Run all checks (format, lint, test)
	@echo "🔍 Running all checks..."
	@make format
	@make lint
	@make test
	@echo "✅ All checks complete"

install-hooks: ## Install git hooks (pre-commit and post-commit)
	@echo "📦 Installing git hooks..."
	@if command -v pre-commit > /dev/null 2>&1; then \
		echo "📦 Using pre-commit framework for pre-commit hooks..."; \
		pre-commit install; \
		echo "✅ Pre-commit hooks installed via framework"; \
		echo ""; \
		PRE_COMMIT_MANAGES_POST_COMMIT=0; \
		if [ -f ".pre-commit-config.yaml" ]; then \
			if grep -qE "stages:\s*\[.*post-commit" .pre-commit-config.yaml 2>/dev/null || grep -q "post-commit" .pre-commit-config.yaml 2>/dev/null; then \
				PRE_COMMIT_MANAGES_POST_COMMIT=1; \
			fi; \
		fi; \
		if [ -f ".git/hooks/post-commit" ] && [ -L ".git/hooks/post-commit" ] 2>/dev/null; then \
			PRE_COMMIT_MANAGES_POST_COMMIT=1; \
		elif [ -f ".git/hooks/post-commit" ]; then \
			if head -5 .git/hooks/post-commit 2>/dev/null | grep -qE "(pre-commit|\.pre-commit)" 2>/dev/null; then \
				PRE_COMMIT_MANAGES_POST_COMMIT=1; \
			fi; \
		fi; \
		if [ "$$PRE_COMMIT_MANAGES_POST_COMMIT" = "1" ]; then \
			echo "ℹ️  Post-commit hooks are managed by pre-commit framework, skipping manual installation"; \
		else \
			echo "ℹ️  Post-commit hooks are not managed by pre-commit framework"; \
			echo "   Installing post-commit hook separately..."; \
			if [ -f "scripts/post-commit-tag.sh" ]; then \
				if [ -f ".git/hooks/post-commit" ] && grep -q "post-commit-tag.sh" .git/hooks/post-commit 2>/dev/null; then \
					echo "ℹ️  Post-commit hook already installed, skipping"; \
				else \
					if [ -f ".git/hooks/post-commit" ]; then \
						cp .git/hooks/post-commit .git/hooks/post-commit.bak 2>/dev/null || true; \
						echo "⚠️  Backed up existing post-commit hook to .git/hooks/post-commit.bak"; \
					fi; \
					cp scripts/post-commit-tag.sh .git/hooks/post-commit-tag.sh 2>/dev/null || true; \
					echo '#!/bin/bash' > .git/hooks/post-commit && \
					echo 'set -e' >> .git/hooks/post-commit && \
					echo 'PROJECT_ROOT="$$(git rev-parse --show-toplevel)"' >> .git/hooks/post-commit && \
					echo 'if [ -f "$$PROJECT_ROOT/scripts/post-commit-tag.sh" ]; then' >> .git/hooks/post-commit && \
					echo '  exec "$$PROJECT_ROOT/scripts/post-commit-tag.sh"' >> .git/hooks/post-commit && \
					echo 'fi' >> .git/hooks/post-commit && \
					chmod +x .git/hooks/post-commit && \
					echo "✅ Post-commit hook installed"; \
				fi; \
			fi; \
		fi; \
	else \
		echo "⚠️  pre-commit framework not installed. Installing hooks manually..."; \
		cp scripts/pre-commit-checks.sh .git/hooks/pre-commit && \
		chmod +x .git/hooks/pre-commit && \
		echo "✅ Pre-commit hook installed manually"; \
		if [ -f "scripts/post-commit-tag.sh" ]; then \
			if [ -f ".git/hooks/post-commit" ] && grep -q "post-commit-tag.sh" .git/hooks/post-commit 2>/dev/null; then \
				echo "ℹ️  Post-commit hook already installed, skipping"; \
			else \
				if [ -f ".git/hooks/post-commit" ]; then \
					cp .git/hooks/post-commit .git/hooks/post-commit.bak 2>/dev/null || true; \
					echo "⚠️  Backed up existing post-commit hook to .git/hooks/post-commit.bak"; \
				fi; \
				cp scripts/post-commit-tag.sh .git/hooks/post-commit-tag.sh 2>/dev/null || true; \
				echo '#!/bin/bash' > .git/hooks/post-commit && \
				echo 'set -e' >> .git/hooks/post-commit && \
				echo 'PROJECT_ROOT="$$(git rev-parse --show-toplevel)"' >> .git/hooks/post-commit && \
				echo 'if [ -f "$$PROJECT_ROOT/scripts/post-commit-tag.sh" ]; then' >> .git/hooks/post-commit && \
				echo '  exec "$$PROJECT_ROOT/scripts/post-commit-tag.sh"' >> .git/hooks/post-commit && \
				echo 'fi' >> .git/hooks/post-commit && \
				chmod +x .git/hooks/post-commit && \
				echo "✅ Post-commit hook installed"; \
			fi; \
		fi; \
	fi
	@echo "✅ All hooks installed"

pre-commit: ## Run pre-commit checks manually
	@bash scripts/pre-commit-checks.sh

clean: ## Clean build artifacts
	@echo "🧹 Cleaning build artifacts..."
	@rm -f dockup-agent
	@rm -f _remote_install.sh
	@echo "✅ Clean complete"

build: ## Build the agent binary
	@echo "🔨 Building agent..."
	@GOOS=linux GOARCH=amd64 go build -o dockup-agent main.go
	@echo "✅ Build complete: dockup-agent"

