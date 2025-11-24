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
    local short_name="${2:-}"
    [ -z "$remote" ] && return 1
    
    local remotes_file
    remotes_file=$(get_remotes_file)
    local temp_file="${remotes_file}.tmp"
    
    # Check if jq is available
    if command -v jq >/dev/null 2>&1; then
        # Normalize legacy arrays and persist structured host/short_name entries
        local existing='[]'
        if [ -f "$remotes_file" ] && [ -s "$remotes_file" ]; then
            existing="$(cat "$remotes_file")"
        fi
        printf '%s' "$existing" | jq --arg remote "$remote" --arg short_name "$short_name" '
            def normalize:
                if type == "array" then
                    map(
                        if type == "string" then {host: .}
                        elif (type == "object") and (.host? != null) then
                            {host: .host} +
                            (if (.short_name? // "" | length) > 0 then {short_name: (.short_name // "")} else {} end)
                        else empty end
                    )
                else [] end;
            def sanitized_entry:
                {host: $remote} +
                (if ($short_name | length) > 0 then {short_name: $short_name} else {} end);
            normalize as $remotes
            | if any($remotes[]?; .host == $remote) then
                $remotes
                | map(
                    if .host == $remote then
                        if ($short_name | length) > 0 then
                            del(.short_name) + {short_name: $short_name}
                        else
                            .
                        end
                    else
                        .
                    end
                )
            else
                $remotes + [sanitized_entry]
            end
        ' > "$temp_file" 2>/dev/null
        if [ -f "$temp_file" ] && [ -s "$temp_file" ]; then
            mv "$temp_file" "$remotes_file" 2>/dev/null || true
        else
            rm -f "$temp_file" 2>/dev/null || true
        fi
    else
        # Fallback: simple text file, optionally storing short_name|remote
        local entry="$remote"
        [ -n "$short_name" ] && entry="$short_name|$remote"
        
        if [ ! -f "$remotes_file" ]; then
            printf '%s\n' "$entry" > "$remotes_file"
            return 0
        fi
        
        : > "$temp_file"
        local found=0
        while IFS= read -r line || [ -n "$line" ]; do
            [ -z "$line" ] && continue
            local line_host="$line"
            if [[ "$line" == *"|"* ]]; then
                line_host="${line#*|}"
            fi
            if [ "$line_host" = "$remote" ]; then
                found=1
                if [ -n "$short_name" ]; then
                    printf '%s\n' "$entry" >> "$temp_file"
                else
                    printf '%s\n' "$line" >> "$temp_file"
                fi
            else
                printf '%s\n' "$line" >> "$temp_file"
            fi
        done < "$remotes_file"
        
        if [ $found -eq 0 ]; then
            printf '%s\n' "$entry" >> "$temp_file"
        fi
        mv "$temp_file" "$remotes_file" 2>/dev/null || true
    fi
}

# Load stored remote hosts
load_remotes() {
    local remotes_file
    remotes_file=$(get_remotes_file)
    
    if [ ! -f "$remotes_file" ]; then
        return 0
    fi
    
    # Check if jq is available
    if command -v jq >/dev/null 2>&1; then
        jq -r '
            def normalize:
                if type == "array" then
                    map(
                        if type == "string" then {host: .}
                        elif (type == "object") and (.host? != null) then
                            {host: .host} +
                            (if (.short_name? // "" | length) > 0 then {short_name: (.short_name // "")} else {} end)
                        else empty end
                    )
                else [] end;
            normalize
            | map(
                if (.short_name // "" | length) > 0 then
                    "\(.short_name)|\(.host)"
                else
                    .host
                end
            )
            | .[]
        ' "$remotes_file" 2>/dev/null | grep -v '^$' || true
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
    local stored_short_names=()
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        if [[ "$line" == *"|"* ]]; then
            stored_short_names+=("${line%%|*}")
            stored_remotes+=("${line#*|}")
        else
            stored_short_names+=("")
            stored_remotes+=("$line")
        fi
    done < <(load_remotes)
    
    local REMOTE_SHORT=""
    local entered_new_remote=0
    
    # If we have stored remotes, show them as choices
    if [ ${#stored_remotes[@]} -gt 0 ]; then
        echo -e "${BLUE}$prompt_text${NC}" >&2
        echo -e "${YELLOW}Stored remotes:${NC}" >&2
        local i=1
        for idx in "${!stored_remotes[@]}"; do
            local label="${stored_remotes[$idx]}"
            if [ -n "${stored_short_names[$idx]}" ]; then
                label="${stored_short_names[$idx]} (${stored_remotes[$idx]})"
            fi
            echo -e "  ${GREEN}$i)${NC} $label" >&2
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
                entered_new_remote=1
            else
                echo -e "${RED}❌ Invalid choice${NC}" >&2
                return 1
            fi
        else
            # User entered a remote directly
            REMOTE_INPUT="$choice"
            entered_new_remote=1
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
        entered_new_remote=1
    fi
    
    if [ -z "$REMOTE_INPUT" ]; then
        echo -e "${RED}❌ Remote host is required${NC}" >&2
        return 1
    fi
    
    if [ "$entered_new_remote" -eq 1 ]; then
        read -p "Short name (optional): " REMOTE_SHORT
    fi
    
    # Save the remote for future use
    save_remote "$REMOTE_INPUT" "$REMOTE_SHORT"
    
    echo "$REMOTE_INPUT"
}

