#!/bin/bash
# DockUp Version Checking Functions
# Handles version comparison and update checking

# Source colors
[ -f "$(dirname "${BASH_SOURCE[0]}")/colors.sh" ] && source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"

# Compare two semantic versions (returns 0 if v1 > v2, 1 if v1 < v2, 2 if equal)
# Usage: compare_versions "1.0.5" "1.0.6" -> returns 1 (1.0.5 < 1.0.6)
compare_versions() {
    local v1="$1"
    local v2="$2"
    
    # Remove 'v' prefix if present
    v1="${v1#v}"
    v2="${v2#v}"
    
    # Split versions into arrays
    IFS='.' read -ra v1_parts <<< "$v1"
    IFS='.' read -ra v2_parts <<< "$v2"
    
    # Compare each part
    local max_len=${#v1_parts[@]}
    if [ ${#v2_parts[@]} -gt $max_len ]; then
        max_len=${#v2_parts[@]}
    fi
    
    for ((i=0; i<max_len; i++)); do
        local v1_part="${v1_parts[$i]:-0}"
        local v2_part="${v2_parts[$i]:-0}"
        
        # Remove any non-numeric suffix (e.g., "1.0.5-beta" -> "1.0.5")
        v1_part="${v1_part%%[!0-9]*}"
        v2_part="${v2_part%%[!0-9]*}"
        
        if [ "$v1_part" -gt "$v2_part" ]; then
            return 0  # v1 > v2
        elif [ "$v1_part" -lt "$v2_part" ]; then
            return 1  # v1 < v2
        fi
    done
    
    return 2  # v1 == v2
}

# Get latest version from GitHub tags API
# Fetches all tags, sorts them by semantic version, and returns the latest
get_latest_version() {
    local repo="${DOCKUP_REPO:-Moe1211/dockup}"
    local cache_file="${HOME}/.dockup_version_cache"
    local cache_age=3600  # Cache for 1 hour (3600 seconds)
    local latest_version=""
    
    # Check cache first
    if [ -f "$cache_file" ]; then
        # Get cache file modification time (works on both macOS and Linux)
        local cache_time=$(stat -f "%m" "$cache_file" 2>/dev/null || stat -c "%Y" "$cache_file" 2>/dev/null || echo "0")
        
        if [ "$cache_time" != "0" ]; then
            local current_time=$(date +%s)
            local age=$((current_time - cache_time))
            
            if [ $age -lt $cache_age ]; then
                latest_version=$(cat "$cache_file" 2>/dev/null || echo "")
                if [ -n "$latest_version" ]; then
                    echo "$latest_version"
                    return 0
                fi
            fi
        fi
    fi
    
    # Fetch tags from GitHub API (non-blocking, with timeout)
    local tags_response=$(curl -s --max-time 5 --connect-timeout 3 \
        "https://api.github.com/repos/${repo}/tags?per_page=100" 2>/dev/null)
    
    if [ -z "$tags_response" ] || ! echo "$tags_response" | grep -q '"name"'; then
        # Failed to fetch or no tags found
        echo ""
        return 1
    fi
    
    # Extract all version tags and find the latest by semantic version
    local temp_file=$(mktemp)
    echo "$tags_response" | grep -o '"name": "[^"]*"' | \
        cut -d'"' -f4 | \
        grep -E '^v?[0-9]+\.[0-9]+\.[0-9]+' | \
        sed 's/^v//' > "$temp_file"
    
    if [ ! -s "$temp_file" ]; then
        rm -f "$temp_file"
        echo ""
        return 1
    fi
    
    # Sort versions semantically and get the latest
    latest_version=""
    while IFS= read -r version; do
        if [ -z "$latest_version" ]; then
            latest_version="$version"
        else
            compare_versions "$latest_version" "$version"
            local result=$?
            # If latest_version < version, update latest_version
            if [ $result -eq 1 ]; then
                latest_version="$version"
            fi
        fi
    done < "$temp_file"
    
    rm -f "$temp_file"
    
    # If we got a version, cache it
    if [ -n "$latest_version" ]; then
        echo "$latest_version" > "$cache_file" 2>/dev/null || true
        echo "$latest_version"
        return 0
    fi
    
    # Return empty if no valid version found
    echo ""
    return 1
}

# Check for updates and display notification if available
check_for_updates() {
    # Skip check if DOCKUP_SKIP_UPDATE_CHECK is set
    if [ -n "${DOCKUP_SKIP_UPDATE_CHECK:-}" ]; then
        return 0
    fi
    
    local version="${DOCKUP_VERSION:-1.0.42}"
    local repo="${DOCKUP_REPO:-Moe1211/dockup}"
    
    # Get latest version (non-blocking, cached)
    local latest_version=""
    latest_version=$(get_latest_version 2>/dev/null || echo "") || true
    
    # If we couldn't get latest version, silently continue
    if [ -z "$latest_version" ]; then
        return 0
    fi
    
    # Compare versions (don't fail if comparison fails)
    compare_versions "$version" "$latest_version" || true
    local comparison_result=$?
    
    # If installed version is less than latest, show update message
    if [ $comparison_result -eq 1 ]; then
        echo ""
        echo -e "${YELLOW}📦 Update Available!${NC}"
        echo -e "${YELLOW}   You're running v${version}, but v${latest_version} is available.${NC}"
        echo -e "${YELLOW}   Update: curl -fsSL https://raw.githubusercontent.com/${repo}/main/install-global.sh | bash${NC}"
        echo ""
    fi
    
    return 0
}

