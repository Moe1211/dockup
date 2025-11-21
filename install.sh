#!/bin/bash
# DockUp Bootstrap Installer
# This script downloads DockUp and runs the specified command
# Usage: curl -fsSL https://your-domain.com/install.sh | bash -s -- init user@vps-ip

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration - Update these URLs to point to your hosted files
# You can override these with environment variables:
#   DOCKUP_REPO_URL=https://raw.githubusercontent.com/Moe1211/dockup/main curl -fsSL ... | bash
DOCKUP_REPO_URL="${DOCKUP_REPO_URL:-https://raw.githubusercontent.com/Moe1211/dockup/main}"
DOCKUP_SCRIPT_URL="${DOCKUP_SCRIPT_URL:-$DOCKUP_REPO_URL/dockup}"
MAIN_GO_URL="${MAIN_GO_URL:-$DOCKUP_REPO_URL/main.go}"

# Temporary directory
TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

cd "$TMP_DIR"

echo -e "${BLUE}🚀 DockUp Bootstrap Installer${NC}"
echo -e "${BLUE}Downloading DockUp...${NC}"

# Download dockup script
if ! curl -fsSL "$DOCKUP_SCRIPT_URL" -o dockup; then
    echo -e "${RED}❌ Failed to download dockup script${NC}"
    echo "Please check your internet connection and try again."
    exit 1
fi

chmod +x dockup

# Download main.go (needed for setup command)
if ! curl -fsSL "$MAIN_GO_URL" -o main.go; then
    echo -e "${RED}❌ Failed to download main.go${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Download complete${NC}"
echo ""

# Execute the command passed as arguments
if [ $# -eq 0 ]; then
    echo -e "${YELLOW}Usage:${NC}"
    echo "  curl -fsSL https://your-domain.com/install.sh | bash -s -- setup user@vps-ip"
    echo "  curl -fsSL https://your-domain.com/install.sh | bash -s -- init user@vps-ip"
    exit 1
fi

# Run dockup with all passed arguments
exec ./dockup "$@"

