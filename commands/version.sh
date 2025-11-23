#!/bin/bash
# DockUp Version Command
# Shows version information and checks for updates

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/version.sh"

# Command: VERSION (Show version information)
cmd_version() {
    local version="${DOCKUP_VERSION:-1.0.42}"
    local repo="${DOCKUP_REPO:-Moe1211/dockup}"
    
    echo -e "${BLUE}DockUp Version Information${NC}"
    echo ""
    echo -e "${BLUE}Installed Version:${NC} v${version}"
    
    # Try to get latest version
    local latest_version=$(get_latest_version 2>/dev/null || echo "")
    
    if [ -n "$latest_version" ]; then
        echo -e "${BLUE}Latest Version:${NC}   v${latest_version}"
        echo ""
        
        # Compare versions
        compare_versions "$version" "$latest_version"
        local comparison_result=$?
        
        if [ $comparison_result -eq 0 ]; then
            # Installed > Latest (shouldn't happen, but handle it)
            echo -e "${YELLOW}Status:${NC} Installed version is newer than latest (v${version} > v${latest_version})"
        elif [ $comparison_result -eq 1 ]; then
            # Installed < Latest
            echo -e "${YELLOW}Status:${NC} Update available (v${version} < v${latest_version})"
            echo ""
            echo -e "${YELLOW}Update:${NC} curl -fsSL https://raw.githubusercontent.com/${repo}/main/install-global.sh | bash"
        elif [ $comparison_result -eq 2 ]; then
            # Installed == Latest
            echo -e "${GREEN}Status:${NC} Up to date (v${version} == v${latest_version})"
        fi
    else
        echo -e "${BLUE}Latest Version:${NC}   ${YELLOW}(unable to fetch)${NC}"
        echo ""
        echo -e "${YELLOW}Status:${NC} Could not check for updates (network issue or API unavailable)"
    fi
    echo ""
}

