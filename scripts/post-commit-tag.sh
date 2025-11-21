#!/bin/bash
# Post-commit hook script for DockUp
# Automatically creates a git tag when DOCKUP_VERSION is updated
# Also pushes the commit and tags to the remote repository

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Get the last commit
LAST_COMMIT=$(git rev-parse HEAD)

# Check if dockup file was modified in the last commit
if ! git diff-tree --no-commit-id --name-only -r "$LAST_COMMIT" | grep -q "^dockup$"; then
    # dockup file was not modified, skip tagging
    exit 0
fi

# Extract DOCKUP_VERSION from the dockup file
DOCKUP_FILE="$PROJECT_ROOT/dockup"
if [ ! -f "$DOCKUP_FILE" ]; then
    echo -e "${YELLOW}⚠️  dockup file not found, skipping tag creation${NC}"
    exit 0
fi

# Extract version from the file
VERSION=$(grep -E '^DOCKUP_VERSION=' "$DOCKUP_FILE" | cut -d'"' -f2 || echo "")

if [ -z "$VERSION" ]; then
    echo -e "${YELLOW}⚠️  Could not extract DOCKUP_VERSION from dockup file${NC}"
    exit 0
fi

# Format tag name (e.g., "1.0.13" -> "v1.0.13")
TAG_NAME="v${VERSION}"

# Check if tag already exists
if git rev-parse "$TAG_NAME" >/dev/null 2>&1; then
    echo -e "${YELLOW}ℹ️  Tag $TAG_NAME already exists, skipping${NC}"
    exit 0
fi

# Get commit message for tag annotation
COMMIT_MSG=$(git log -1 --pretty=%B "$LAST_COMMIT")
TAG_MSG="Version $TAG_NAME: $COMMIT_MSG"

# Create annotated tag
echo -e "${BLUE}📦 Creating git tag $TAG_NAME...${NC}"
git tag -a "$TAG_NAME" -m "$TAG_MSG" "$LAST_COMMIT"

echo -e "${GREEN}✅ Tag $TAG_NAME created successfully${NC}"

# Get current branch name
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
REMOTE_NAME="origin"

# Check if remote exists
if ! git remote get-url "$REMOTE_NAME" >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  Remote '$REMOTE_NAME' not found, skipping push${NC}"
    echo -e "${YELLOW}💡 To push manually, run: git push origin $CURRENT_BRANCH --tags${NC}"
    exit 0
fi

# Push commit and tags
echo -e "${BLUE}🚀 Pushing to $REMOTE_NAME/$CURRENT_BRANCH with tags...${NC}"
PUSH_OUTPUT=$(git push "$REMOTE_NAME" "$CURRENT_BRANCH" --tags 2>&1)
PUSH_EXIT_CODE=$?

if [ $PUSH_EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✅ Successfully pushed commit and tag $TAG_NAME to $REMOTE_NAME${NC}"
else
    echo -e "${YELLOW}⚠️  Failed to push automatically${NC}"
    # Show error message if available
    if [ -n "$PUSH_OUTPUT" ]; then
        echo -e "${YELLOW}   Error: $(echo "$PUSH_OUTPUT" | head -n1)${NC}"
    fi
    echo -e "${YELLOW}💡 To push manually, run: git push $REMOTE_NAME $CURRENT_BRANCH --tags${NC}"
    # Don't fail the commit if push fails
    exit 0
fi

