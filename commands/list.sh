#!/bin/bash
# DockUp List Command
# Lists all registered apps with their status

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/loading.sh"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/version.sh"

# Ensure spinner is cleaned up on exit
trap 'stop_spinner' EXIT INT TERM

# Command: LIST (List registered apps)
cmd_list() {
    local REMOTE="$1"
    
    if [ -z "$REMOTE" ]; then 
        echo -e "${RED}Usage: ./dockup user@host list${NC}" >&2
        exit 1
    fi
    
    # Check for updates (don't fail if this fails)
    check_for_updates || true
    
    print_version
    echo ""
    echo -e "${GREEN}📋 Registered Apps on $REMOTE${NC}"
    echo ""
    
    # Check SSH connectivity with loading
    start_spinner "Checking SSH connectivity..."
    if ! ssh -o ConnectTimeout=5 -o BatchMode=yes $REMOTE "echo test" >/dev/null 2>&1; then
        stop_spinner
        show_error "Cannot connect to $REMOTE"
        echo -e "${YELLOW}   Check SSH connectivity and credentials${NC}" >&2
        exit 1
    fi
    stop_spinner
    show_success "Connected to $REMOTE"
    
    # Check if registry.json exists
    start_spinner "Checking registry..."
    if ! ssh $REMOTE "test -f /etc/dockup/registry.json" 2>/dev/null; then
        stop_spinner
        echo -e "${YELLOW}⚠️  Registry file not found${NC}" >&2
        echo -e "${YELLOW}   DockUp may not be set up on this VPS${NC}" >&2
        echo -e "${YELLOW}   Run: dockup $REMOTE setup${NC}" >&2
        exit 1
    fi
    stop_spinner
    show_success "Registry found"
    
    # Get registry contents
    start_spinner "Loading registry data..."
    REGISTRY_JSON=$(ssh $REMOTE "cat /etc/dockup/registry.json 2>/dev/null" || echo "{}")
    stop_spinner
    
    # Check if registry is empty
    APP_COUNT=$(echo "$REGISTRY_JSON" | jq 'length' 2>/dev/null || echo "0")
    
    if [ "$APP_COUNT" = "0" ] || [ -z "$APP_COUNT" ]; then
        echo -e "${YELLOW}No apps registered${NC}"
        echo ""
        echo -e "${BLUE}To register an app:${NC}"
        echo "  cd your-project"
        echo "  dockup $REMOTE deploy"
        echo ""
        exit 0
    fi
    
    # List all apps with details
    echo -e "${BLUE}Found $APP_COUNT registered app(s):${NC}"
    echo ""
    
    # Get all app names and details from local registry JSON
    APP_NAMES_ARRAY=()
    while IFS= read -r line; do
        [ -n "$line" ] && APP_NAMES_ARRAY+=("$line")
    done < <(echo "$REGISTRY_JSON" | jq -r 'keys[]' 2>/dev/null)
    
    # Build a single SSH command to check all directories and .env files at once
    # Format: APP_NAME|PATH|DIR_EXISTS|ENV_EXISTS
    STATUS_INFO=$(ssh $REMOTE bash <<REMOTE_SCRIPT 2>/dev/null
$(for app_name in "${APP_NAMES_ARRAY[@]}"; do
    path=$(echo "$REGISTRY_JSON" | jq -r ".\"$app_name\".path" 2>/dev/null)
    echo "if [ -d \"$path\" ]; then"
    echo "  if [ -f \"$path/.env\" ]; then"
    echo "    echo \"$app_name|$path|1|1\""
    echo "  else"
    echo "    echo \"$app_name|$path|1|0\""
    echo "  fi"
    echo "else"
    echo "  echo \"$app_name|$path|0|0\""
    echo "fi"
done)
REMOTE_SCRIPT
)
    
    # Display results
    for APP_NAME in "${APP_NAMES_ARRAY[@]}"; do
        [ -z "$APP_NAME" ] && continue
        
        # Get app details from local registry
        APP_PATH=$(echo "$REGISTRY_JSON" | jq -r ".\"$APP_NAME\".path" 2>/dev/null)
        APP_BRANCH=$(echo "$REGISTRY_JSON" | jq -r ".\"$APP_NAME\".branch" 2>/dev/null)
        APP_COMPOSE=$(echo "$REGISTRY_JSON" | jq -r ".\"$APP_NAME\".compose_file // \"docker-compose.yml\"" 2>/dev/null)
        
        # Get status info from the SSH output
        STATUS_LINE=$(echo "$STATUS_INFO" | grep "^${APP_NAME}|" | head -1)
        DIR_EXISTS=$(echo "$STATUS_LINE" | cut -d'|' -f3)
        ENV_EXISTS=$(echo "$STATUS_LINE" | cut -d'|' -f4)
        
        echo -e "${GREEN}📦 $APP_NAME${NC}"
        echo -e "   ${BLUE}Path:${NC}        $APP_PATH"
        echo -e "   ${BLUE}Branch:${NC}      $APP_BRANCH"
        echo -e "   ${BLUE}Compose File:${NC} $APP_COMPOSE"
        
        if [ "$DIR_EXISTS" = "1" ]; then
            echo -e "   ${GREEN}Status:${NC}      Directory exists"
            if [ "$ENV_EXISTS" = "1" ]; then
                echo -e "   ${GREEN}Config:${NC}      .env file present"
            else
                echo -e "   ${YELLOW}Config:${NC}      .env file not found"
            fi
        else
            echo -e "   ${YELLOW}Status:${NC}      Directory not found"
        fi
        echo ""
    done
}

