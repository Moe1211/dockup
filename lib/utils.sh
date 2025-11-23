#!/bin/bash
# DockUp Utility Functions
# Common helper functions used across commands

# Source colors
[ -f "$(dirname "${BASH_SOURCE[0]}")/colors.sh" ] && source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"

# Get script directory
get_script_dir() {
    echo "$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
}

# Print version banner
print_version() {
    local version="${DOCKUP_VERSION:-1.0.42}"
    echo -e "${BLUE}DockUp v${version}${NC}"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if remote is reachable
check_ssh_connectivity() {
    local remote="$1"
    if ssh -o ConnectTimeout=5 -o BatchMode=yes "$remote" "echo test" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Validate remote host format
validate_remote() {
    local remote="$1"
    if [[ "$remote" =~ ^[a-zA-Z0-9._-]+@[a-zA-Z0-9._-]+$ ]]; then
        return 0
    else
        return 1
    fi
}

# Get app path from registry
get_app_path() {
    local remote="$1"
    local app_name="$2"
    ssh "$remote" "jq -r '.\"$app_name\".path // \"/opt/dockup/apps/$app_name\"' /etc/dockup/registry.json" 2>/dev/null || echo "/opt/dockup/apps/$app_name"
}

# Get compose file from registry
get_compose_file() {
    local remote="$1"
    local app_name="$2"
    ssh "$remote" "jq -r '.\"$app_name\".compose_file // \"docker-compose.yml\"' /etc/dockup/registry.json" 2>/dev/null || echo "docker-compose.yml"
}

# Check if app is registered
is_app_registered() {
    local remote="$1"
    local app_name="$2"
    local registered=$(ssh "$remote" "jq -r '.\"$app_name\" // empty' /etc/dockup/registry.json" 2>/dev/null || echo "")
    [ -n "$registered" ] && [ "$registered" != "null" ]
}

# Get GitHub repo URL from app directory
get_repo_url() {
    local remote="$1"
    local app_path="$2"
    ssh "$remote" "cd \"$app_path\" && git config --get remote.origin.url 2>/dev/null" || echo ""
}

# Extract GitHub repo name from URL
extract_repo_name() {
    local repo_url="$1"
    if echo "$repo_url" | grep -q "github.com"; then
        echo "$repo_url" | sed -E 's|.*github\.com[:/]([^/]+/[^/]+)|\1|' | sed 's|\.git$||' | sed 's|/$||'
    else
        echo ""
    fi
}

# Confirm action
confirm_action() {
    local prompt="$1"
    local default="${2:-no}"
    
    if [ "$default" = "yes" ]; then
        read -p "$(echo -e "${YELLOW}${prompt}${NC} (yes/no) [yes]: ")" confirm
        confirm="${confirm:-yes}"
    else
        read -p "$(echo -e "${YELLOW}${prompt}${NC} (yes/no) [no]: ")" confirm
        confirm="${confirm:-no}"
    fi
    
    [ "$confirm" = "yes" ] || [ "$confirm" = "y" ]
}

# Print section header
print_section() {
    local title="$1"
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${BLUE}${title}${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# Print step
print_step() {
    local step_num="$1"
    local step_msg="$2"
    echo -e "${BLUE}📋 Step ${step_num}: ${step_msg}${NC}"
}

# Print success
print_success() {
    local msg="$1"
    echo -e "${GREEN}✓${NC} ${msg}"
}

# Print error
print_error() {
    local msg="$1"
    echo -e "${RED}✗${NC} ${msg}"
}

# Print warning
print_warning() {
    local msg="$1"
    echo -e "${YELLOW}⚠${NC} ${msg}"
}

# Print info
print_info() {
    local msg="$1"
    echo -e "${BLUE}ℹ${NC} ${msg}"
}

