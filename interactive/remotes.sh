#!/bin/bash
# DockUp Interactive Remote Management
# Handles remote host storage and selection

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/colors.sh"

# Remote host storage functions
get_remotes_file() {
    local remotes_dir="$HOME/.dockup"
    mkdir -p "$remotes_dir"
    echo "$remotes_dir/remotes.json"
}

# Save a remote host to storage
save_remote() {
    local remote="$1"
    [ -z "$remote" ] && return 1
    
    local remotes_file=$(get_remotes_file)
    local temp_file="${remotes_file}.tmp"
    
    # Check if jq is available
    if command -v jq >/dev/null 2>&1; then
        # Use jq to manage JSON array
        if [ -f "$remotes_file" ] && [ -s "$remotes_file" ]; then
            # Add remote if it doesn't exist, then deduplicate
            jq --arg remote "$remote" 'if (. | index($remote)) then . else . + [$remote] end | unique' "$remotes_file" > "$temp_file" 2>/dev/null
        else
            # Create new array
            printf '%s\n' "$remote" | jq -R -s 'split("\n") | map(select(length > 0))' > "$temp_file" 2>/dev/null
        fi
        if [ -f "$temp_file" ] && [ -s "$temp_file" ]; then
            mv "$temp_file" "$remotes_file" 2>/dev/null || true
        else
            rm -f "$temp_file" 2>/dev/null || true
        fi
    else
        # Fallback: simple text file, one per line
        if [ ! -f "$remotes_file" ] || ! grep -Fxq "$remote" "$remotes_file" 2>/dev/null; then
            echo "$remote" >> "$remotes_file"
        fi
    fi
}

# Load stored remote hosts
load_remotes() {
    local remotes_file=$(get_remotes_file)
    
    if [ ! -f "$remotes_file" ]; then
        return 0
    fi
    
    # Check if jq is available
    if command -v jq >/dev/null 2>&1; then
        jq -r '.[]' "$remotes_file" 2>/dev/null | grep -v '^$' || true
    else
        # Fallback: read text file
        grep -v '^$' "$remotes_file" 2>/dev/null || true
    fi
}

# Prompt for remote host input with stored remotes as choices
prompt_remote() {
    local prompt_text="$1"
    local default_remote="$2"
    
    # Load stored remotes
    local stored_remotes=()
    while IFS= read -r line; do
        [ -n "$line" ] && stored_remotes+=("$line")
    done < <(load_remotes)
    
    # If we have stored remotes, show them as choices
    if [ ${#stored_remotes[@]} -gt 0 ]; then
        echo -e "${BLUE}$prompt_text${NC}" >&2
        echo -e "${YELLOW}Stored remotes:${NC}" >&2
        local i=1
        for stored in "${stored_remotes[@]}"; do
            echo -e "  ${GREEN}$i)${NC} $stored" >&2
            ((i++))
        done
        echo -e "  ${GREEN}$i)${NC} Enter new remote" >&2
        echo "" >&2
        
        local choice
        read -p "Select remote (1-$i) or enter new: " choice
        
        # Check if choice is a number
        if [[ "$choice" =~ ^[0-9]+$ ]]; then
            if [ "$choice" -ge 1 ] && [ "$choice" -le ${#stored_remotes[@]} ]; then
                REMOTE_INPUT="${stored_remotes[$((choice-1))]}"
            elif [ "$choice" -eq $i ]; then
                # User wants to enter new remote
                read -p "Remote host (user@host): " REMOTE_INPUT
            else
                echo -e "${RED}❌ Invalid choice${NC}" >&2
                return 1
            fi
        else
            # User entered a remote directly
            REMOTE_INPUT="$choice"
        fi
    else
        # No stored remotes, use original prompt
        if [ -n "$default_remote" ]; then
            echo -e "${BLUE}$prompt_text${NC} (default: $default_remote)" >&2
            read -p "Remote host (user@host): " REMOTE_INPUT
            REMOTE_INPUT="${REMOTE_INPUT:-$default_remote}"
        else
            echo -e "${BLUE}$prompt_text${NC}" >&2
            read -p "Remote host (user@host): " REMOTE_INPUT
        fi
    fi
    
    if [ -z "$REMOTE_INPUT" ]; then
        echo -e "${RED}❌ Remote host is required${NC}" >&2
        return 1
    fi
    
    # Save the remote for future use
    save_remote "$REMOTE_INPUT"
    
    echo "$REMOTE_INPUT"
}

