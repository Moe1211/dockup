#!/bin/bash
# DockUp Global Installer
# Installs dockup as a global command available system-wide
# Usage: curl -fsSL https://raw.githubusercontent.com/Moe1211/dockup/main/install-global.sh | bash

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
DOCKUP_REPO_URL="${DOCKUP_REPO_URL:-https://raw.githubusercontent.com/Moe1211/dockup/main}"
DOCKUP_SCRIPT_URL="${DOCKUP_SCRIPT_URL:-$DOCKUP_REPO_URL/dockup}"
MAIN_GO_URL="${MAIN_GO_URL:-$DOCKUP_REPO_URL/main.go}"

echo -e "${BLUE}🚀 Installing DockUp globally...${NC}"
echo ""

# Determine install directory
if [ "$EUID" -eq 0 ]; then
    # Running as root - install system-wide
    INSTALL_DIR="/usr/local/bin"
    DATA_DIR="/usr/local/share/dockup"
else
    # Running as user - install to user directory
    if [ -d "$HOME/.local/bin" ]; then
        INSTALL_DIR="$HOME/.local/bin"
    else
        INSTALL_DIR="$HOME/bin"
        mkdir -p "$INSTALL_DIR"
    fi
    DATA_DIR="$HOME/.local/share/dockup"
fi

# Create data directory for main.go
mkdir -p "$DATA_DIR"

echo -e "${BLUE}📦 Downloading DockUp...${NC}"

# Download dockup script
TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

cd "$TMP_DIR"

if ! curl -fsSL "$DOCKUP_SCRIPT_URL" -o dockup; then
    echo -e "${RED}❌ Failed to download dockup script${NC}"
    exit 1
fi

# Download main.go
if ! curl -fsSL "$MAIN_GO_URL" -o main.go; then
    echo -e "${RED}❌ Failed to download main.go${NC}"
    exit 1
fi

# Download go.mod and go.sum (required for building)
GO_MOD_URL="${GO_MOD_URL:-$DOCKUP_REPO_URL/go.mod}"
GO_SUM_URL="${GO_SUM_URL:-$DOCKUP_REPO_URL/go.sum}"
if ! curl -fsSL "$GO_MOD_URL" -o go.mod; then
    echo -e "${YELLOW}⚠️  Failed to download go.mod (may cause build issues)${NC}"
fi
if ! curl -fsSL "$GO_SUM_URL" -o go.sum 2>/dev/null; then
    echo -e "${YELLOW}⚠️  go.sum not found (will be generated on first build)${NC}"
fi

# Make dockup executable
chmod +x dockup

# Update dockup script to use the installed main.go location
# Replace the AGENT_SRC path with the installed location
sed -i.bak "s|AGENT_SRC=\"main.go\"|AGENT_SRC=\"$DATA_DIR/main.go\"|g" dockup
rm dockup.bak

# Install dockup script
echo -e "${BLUE}📥 Installing to $INSTALL_DIR...${NC}"
cp dockup "$INSTALL_DIR/dockup"

# Install main.go, go.mod, and go.sum
echo -e "${BLUE}📥 Installing main.go to $DATA_DIR...${NC}"
cp main.go "$DATA_DIR/main.go"
if [ -f go.mod ]; then
    cp go.mod "$DATA_DIR/go.mod"
fi
if [ -f go.sum ]; then
    cp go.sum "$DATA_DIR/go.sum"
fi

# Add to PATH if not already there (for user installs)
if [ "$EUID" -ne 0 ]; then
    if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
        echo ""
        echo -e "${YELLOW}⚠️  $INSTALL_DIR is not in your PATH${NC}"
        echo ""
        echo -e "${YELLOW}Add this to your shell profile (~/.zshrc, ~/.bashrc, etc.):${NC}"
        echo -e "${BLUE}export PATH=\"\$PATH:$INSTALL_DIR\"${NC}"
        echo ""
        
        # Try to detect shell and add automatically
        SHELL_NAME=$(basename "$SHELL")
        if [ "$SHELL_NAME" = "zsh" ]; then
            SHELL_RC="$HOME/.zshrc"
        elif [ "$SHELL_NAME" = "bash" ]; then
            SHELL_RC="$HOME/.bashrc"
        else
            SHELL_RC=""
        fi
        
        if [ -n "$SHELL_RC" ] && [ -f "$SHELL_RC" ]; then
            if ! grep -q "$INSTALL_DIR" "$SHELL_RC" 2>/dev/null; then
                echo "" >> "$SHELL_RC"
                echo "# DockUp" >> "$SHELL_RC"
                echo "export PATH=\"\$PATH:$INSTALL_DIR\"" >> "$SHELL_RC"
                echo -e "${GREEN}✅ Added to $SHELL_RC${NC}"
                echo -e "${YELLOW}Run 'source $SHELL_RC' or restart your terminal${NC}"
            fi
        fi
    fi
fi

echo ""
echo -e "${GREEN}✅ DockUp installed successfully!${NC}"
echo ""
echo -e "${GREEN}You can now use 'dockup' from anywhere:${NC}"
echo "  dockup user@vps-ip deploy"
echo "  dockup user@vps-ip setup"
echo "  dockup user@vps-ip init"
echo ""

# Test if dockup is available
if command -v dockup &> /dev/null; then
    echo -e "${GREEN}✓ 'dockup' command is available${NC}\n"
else
    echo -e "${YELLOW}⚠️  'dockup' command not found in PATH${NC}"
    echo -e "${YELLOW}   Try: source ~/.zshrc (or ~/.bashrc)${NC}"
fi

echo ""

