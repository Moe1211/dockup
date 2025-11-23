#!/bin/bash
# DockUp Interactive App Selection
# Handles app selection for commands that need it

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/colors.sh"

# Get list of apps from a remote (for selection)
get_apps_from_remote() {
    local remote="$1"
    local apps=()
    
    # Check SSH connectivity
    if ! ssh "$remote" "echo test" >/dev/null 2>&1; then
        return 1
    fi
    
    # Check if registry exists
    if ! ssh "$remote" "test -f /etc/dockup/registry.json" 2>/dev/null; then
        return 1
    fi
    
    # Get app names
    while IFS= read -r line; do
        [ -n "$line" ] && apps+=("$line")
    done < <(ssh "$remote" "jq -r 'keys[]' /etc/dockup/registry.json" 2>/dev/null)
    
    # Output apps (one per line for select menu)
    printf '%s\n' "${apps[@]}"
}

# Interactive app selection
select_app() {
    local remote="$1"
    local apps=()
    
    # Try to get apps from remote
    while IFS= read -r line; do
        [ -n "$line" ] && apps+=("$line")
    done < <(get_apps_from_remote "$remote" 2>/dev/null)
    
    # If no apps found, try to detect from git context
    if [ ${#apps[@]} -eq 0 ]; then
        if git rev-parse --show-toplevel > /dev/null 2>&1; then
            local detected_app=$(basename `git rev-parse --show-toplevel`)
            echo -e "${YELLOW}⚠️  No apps found on remote. Using detected app: $detected_app${NC}" >&2
            echo "$detected_app"
            return 0
        else
            echo -e "${YELLOW}⚠️  No apps found and not in a git repository${NC}" >&2
            read -p "Enter app name: " APP_INPUT
            if [ -z "$APP_INPUT" ]; then
                return 1
            fi
            echo "$APP_INPUT"
            return 0
        fi
    fi
    
    # If only one app, return it
    if [ ${#apps[@]} -eq 1 ]; then
        echo "${apps[0]}"
        return 0
    fi
    
    # Multiple apps - show selection menu
    echo "" >&2
    echo -e "${BLUE}Select an app:${NC}" >&2
    echo "" >&2
    
    PS3="Select app (1-${#apps[@]}): "
    select app in "${apps[@]}" "Cancel"; do
        if [ "$app" = "Cancel" ]; then
            return 1
        elif [ -n "$app" ]; then
            echo "$app"
            return 0
        else
            echo -e "${RED}Invalid selection${NC}" >&2
        fi
    done
}

