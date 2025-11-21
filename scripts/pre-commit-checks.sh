#!/bin/bash
# Comprehensive pre-commit checks for DockUp
# This script runs all checks, tests, and lints

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔍 Running pre-commit checks for DockUp...${NC}"
echo ""

# Track if any checks failed
FAILED=0

# Function to increment version in dockup script
increment_version() {
    local dockup_file="$PROJECT_ROOT/dockup"
    
    if [ ! -f "$dockup_file" ]; then
        echo -e "${YELLOW}⚠️  dockup file not found, skipping version increment${NC}"
        return 0
    fi
    
    # Extract current version
    local current_version=$(grep -E '^DOCKUP_VERSION=' "$dockup_file" | cut -d'"' -f2 || echo "")
    
    if [ -z "$current_version" ]; then
        echo -e "${YELLOW}⚠️  Could not find DOCKUP_VERSION in dockup script${NC}"
        return 0
    fi
    
    # Split version into parts (e.g., "1.0.5" -> ["1", "0", "5"])
    IFS='.' read -ra version_parts <<< "$current_version"
    
    # Get array length and last index
    local num_parts=${#version_parts[@]}
    local last_index=$((num_parts - 1))
    
    # Get the last part (patch version)
    local patch_version="${version_parts[$last_index]}"
    
    # Increment patch version
    local new_patch_version=$((patch_version + 1))
    
    # Reconstruct version with incremented patch
    local new_version="${version_parts[0]}.${version_parts[1]}.${new_patch_version}"
    
    # Update the file (use a temporary file for portability)
    local temp_file=$(mktemp)
    sed "s/^DOCKUP_VERSION=\"${current_version}\"/DOCKUP_VERSION=\"${new_version}\"/" "$dockup_file" > "$temp_file"
    mv "$temp_file" "$dockup_file"
    
    # Stage the updated file
    git add "$dockup_file" 2>/dev/null || true
    
    echo -e "${GREEN}✓ Version incremented: v${current_version} → v${new_version}${NC}"
}

# 0. Auto-increment version
echo -e "${YELLOW}📋 Step 0: Auto-increment version${NC}"
increment_version
echo ""

# Function to run a check and track failures
run_check() {
    local name="$1"
    shift
    echo -e "${BLUE}Checking: ${name}${NC}"
    if "$@" > /tmp/dockup-check-$$.log 2>&1; then
        echo -e "${GREEN}✓ ${name} passed${NC}"
        return 0
    else
        echo -e "${RED}❌ ${name} failed${NC}"
        cat /tmp/dockup-check-$$.log
        FAILED=1
        return 1
    fi
}

# 1. Shell script syntax checks
echo -e "${YELLOW}📋 Step 1: Shell script syntax checks${NC}"
for file in "$PROJECT_ROOT"/*.sh "$PROJECT_ROOT"/dockup; do
    if [ -f "$file" ] && [ -x "$file" ]; then
        run_check "Shell syntax: $(basename "$file")" bash -n "$file" || true
    fi
done
echo ""

# 2. Go formatting check
echo -e "${YELLOW}📋 Step 2: Go code formatting${NC}"
if command -v gofmt > /dev/null 2>&1; then
    if [ -n "$(gofmt -l "$PROJECT_ROOT"/*.go 2>/dev/null)" ]; then
        echo -e "${RED}❌ Go files are not formatted${NC}"
        echo "Run: gofmt -w *.go"
        FAILED=1
    else
        echo -e "${GREEN}✓ Go files are properly formatted${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  gofmt not found, skipping${NC}"
fi
echo ""

# 3. Go vet
echo -e "${YELLOW}📋 Step 3: Go vet (static analysis)${NC}"
if command -v go > /dev/null 2>&1; then
    cd "$PROJECT_ROOT"
    if go vet ./... 2>&1; then
        echo -e "${GREEN}✓ Go vet passed${NC}"
    else
        echo -e "${RED}❌ Go vet found issues${NC}"
        FAILED=1
    fi
else
    echo -e "${YELLOW}⚠️  go not found, skipping${NC}"
fi
echo ""

# 4. Go tests
echo -e "${YELLOW}📋 Step 4: Go tests${NC}"
if command -v go > /dev/null 2>&1; then
    cd "$PROJECT_ROOT"
    if go test ./... -v 2>&1; then
        echo -e "${GREEN}✓ Go tests passed${NC}"
    else
        echo -e "${RED}❌ Go tests failed${NC}"
        FAILED=1
    fi
else
    echo -e "${YELLOW}⚠️  go not found, skipping${NC}"
fi
echo ""

# 5. ShellCheck (if available)
echo -e "${YELLOW}📋 Step 5: ShellCheck (shell linting)${NC}"
if command -v shellcheck > /dev/null 2>&1; then
    for file in "$PROJECT_ROOT"/*.sh "$PROJECT_ROOT"/dockup; do
        if [ -f "$file" ] && [ -x "$file" ]; then
            # Skip install scripts as they need to work standalone
            if [[ "$(basename "$file")" =~ ^(install|install-global)\.sh$ ]]; then
                continue
            fi
            run_check "ShellCheck: $(basename "$file")" shellcheck -S warning "$file" || true
        fi
    done
else
    echo -e "${YELLOW}⚠️  shellcheck not found, install with: brew install shellcheck${NC}"
fi
echo ""

# 6. JSON validation
echo -e "${YELLOW}📋 Step 6: JSON validation${NC}"
if command -v jq > /dev/null 2>&1; then
    for file in "$PROJECT_ROOT"/*.json; do
        if [ -f "$file" ]; then
            run_check "JSON: $(basename "$file")" jq empty "$file" || true
        fi
    done
else
    echo -e "${YELLOW}⚠️  jq not found, skipping JSON validation${NC}"
fi
echo ""

# 7. Markdown linting (if available)
echo -e "${YELLOW}📋 Step 7: Markdown linting${NC}"
if command -v markdownlint > /dev/null 2>&1; then
    for file in "$PROJECT_ROOT"/*.md; do
        if [ -f "$file" ]; then
            run_check "Markdown: $(basename "$file")" markdownlint "$file" || true
        fi
    done
else
    echo -e "${YELLOW}⚠️  markdownlint not found, install with: npm install -g markdownlint-cli${NC}"
fi
echo ""

# 8. Check for common issues
echo -e "${YELLOW}📋 Step 8: Common issue checks${NC}"

# Check for TODO/FIXME in committed code (warn only)
if git diff --cached --name-only | xargs grep -l "TODO\|FIXME" 2>/dev/null; then
    echo -e "${YELLOW}⚠️  Found TODO/FIXME in staged files (this is okay, just a reminder)${NC}"
fi

# Check for merge conflicts
if git diff --cached --name-only | xargs grep -l "^<<<<<<< \|^>>>>>>> " 2>/dev/null; then
    echo -e "${RED}❌ Found merge conflict markers in staged files${NC}"
    FAILED=1
fi

# Check for large files
LARGE_FILES=$(git diff --cached --name-only | xargs ls -lh 2>/dev/null | awk '$5+0 > 1000000 {print $9, $5}')
if [ -n "$LARGE_FILES" ]; then
    echo -e "${YELLOW}⚠️  Found large files (>1MB):${NC}"
    echo "$LARGE_FILES"
fi

echo ""

# Cleanup
rm -f /tmp/dockup-check-$$.log

# Final result
if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ All pre-commit checks passed!${NC}"
    exit 0
else
    echo -e "${RED}❌ Some pre-commit checks failed. Please fix the issues above.${NC}"
    exit 1
fi

