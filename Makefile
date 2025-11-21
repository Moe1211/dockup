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

install-hooks: ## Install pre-commit hooks
	@echo "📦 Installing pre-commit hooks..."
	@if command -v pre-commit > /dev/null 2>&1; then \
		pre-commit install; \
	else \
		echo "⚠️  pre-commit not installed. Installing git hook manually..."; \
		cp scripts/pre-commit-checks.sh .git/hooks/pre-commit && \
		chmod +x .git/hooks/pre-commit && \
		echo "✅ Git hook installed"; \
	fi

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

