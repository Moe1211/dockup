#!/bin/bash
# DockUp List Command
# Lists all registered apps with their status

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/loading.sh"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/version.sh"

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
    if ! ssh $REMOTE "echo test" >/dev/null 2>&1; then
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
    
    # Get all app names
    start_spinner "Fetching app list..."
    APP_NAMES_ARRAY=()
    while IFS= read -r line; do
        [ -n "$line" ] && APP_NAMES_ARRAY+=("$line")
    done < <(ssh $REMOTE "jq -r 'keys[]' /etc/dockup/registry.json" 2>/dev/null)
    stop_spinner
    
    # Iterate over each app name
    local app_index=0
    for APP_NAME in "${APP_NAMES_ARRAY[@]}"; do
        [ -z "$APP_NAME" ] && continue  # Skip empty entries
        
        app_index=$((app_index + 1))
        start_spinner "Checking app $app_index/${#APP_NAMES_ARRAY[@]}: $APP_NAME..."
        
        # Get app details for this specific app
        APP_PATH=$(ssh $REMOTE "jq -r '.\"$APP_NAME\".path' /etc/dockup/registry.json" 2>/dev/null)
        APP_BRANCH=$(ssh $REMOTE "jq -r '.\"$APP_NAME\".branch' /etc/dockup/registry.json" 2>/dev/null)
        APP_COMPOSE=$(ssh $REMOTE "jq -r '.\"$APP_NAME\".compose_file // \"docker-compose.yml\"' /etc/dockup/registry.json" 2>/dev/null)
        
        stop_spinner
        
        echo -e "${GREEN}📦 $APP_NAME${NC}"
        echo -e "   ${BLUE}Path:${NC}        $APP_PATH"
        echo -e "   ${BLUE}Branch:${NC}      $APP_BRANCH"
        echo -e "   ${BLUE}Compose File:${NC} $APP_COMPOSE"
        
        # Check if directory exists
        if ssh $REMOTE "test -d \"$APP_PATH\"" 2>/dev/null; then
            echo -e "   ${GREEN}Status:${NC}      Directory exists"
            
            # Check if compose file exists
            if ssh $REMOTE "test -f \"$APP_PATH/$APP_COMPOSE\"" 2>/dev/null; then
                COMPOSE_EXISTS=true
            else
                COMPOSE_EXISTS=false
            fi
        else
            echo -e "   ${YELLOW}Status:${NC}      Directory not found"
            COMPOSE_EXISTS=false
        fi
        
        # Check docker container state with enhanced logic
        start_spinner "   Checking container status..."
        RUNNING_COUNT="0"
        TOTAL_COUNT="0"
        
        if [ "$COMPOSE_EXISTS" = "true" ]; then
            # Method 1: Try docker compose ps (most accurate for compose projects)
            PROJECT_NAME=$(basename "$APP_PATH" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g')
            
            COMPOSE_PS_OUTPUT=$(ssh $REMOTE "cd \"$APP_PATH\" && docker compose -f \"$APP_COMPOSE\" -p \"$PROJECT_NAME\" ps --format json 2>/dev/null" 2>/dev/null)
            
            if [ -n "$COMPOSE_PS_OUTPUT" ] && [ "$COMPOSE_PS_OUTPUT" != "[]" ]; then
                RUNNING_COUNT=$(echo "$COMPOSE_PS_OUTPUT" | jq '[.[] | select(.State == "running")] | length' 2>/dev/null || echo "0")
                TOTAL_COUNT=$(echo "$COMPOSE_PS_OUTPUT" | jq 'length' 2>/dev/null || echo "0")
                
                # Also try without project name (default behavior)
                if [ "$RUNNING_COUNT" = "0" ] || [ -z "$RUNNING_COUNT" ]; then
                    COMPOSE_PS_OUTPUT=$(ssh $REMOTE "cd \"$APP_PATH\" && docker compose -f \"$APP_COMPOSE\" ps --format json 2>/dev/null" 2>/dev/null)
                    if [ -n "$COMPOSE_PS_OUTPUT" ] && [ "$COMPOSE_PS_OUTPUT" != "[]" ]; then
                        RUNNING_COUNT=$(echo "$COMPOSE_PS_OUTPUT" | jq '[.[] | select(.State == "running")] | length' 2>/dev/null || echo "0")
                        TOTAL_COUNT=$(echo "$COMPOSE_PS_OUTPUT" | jq 'length' 2>/dev/null || echo "0")
                    fi
                fi
            fi
            
            # Method 2: Fallback - check containers by name pattern if compose ps failed
            if [ "$RUNNING_COUNT" = "0" ] || [ -z "$RUNNING_COUNT" ] || [ "$TOTAL_COUNT" = "0" ]; then
                APP_NAME_LOWER=$(echo "$APP_NAME" | tr '[:upper:]' '[:lower:]')
                PROJECT_NAME_LOWER=$(basename "$APP_PATH" | tr '[:upper:]' '[:lower:]')
                
                APP_NAME_ESCAPED=$(echo "$APP_NAME_LOWER" | sed 's/[][\.*^$()+?{|]/\\&/g')
                PROJECT_NAME_ESCAPED=$(echo "$PROJECT_NAME_LOWER" | sed 's/[][\.*^$()+?{|]/\\&/g')
                GREP_PATTERN="($APP_NAME_ESCAPED|$PROJECT_NAME_ESCAPED)"
                
                RUNNING_BY_NAME=$(ssh $REMOTE "docker ps --format '{{.Names}}' 2>/dev/null | grep -iE '$GREP_PATTERN' | wc -l" 2>/dev/null | tr -d ' ' || echo "0")
                TOTAL_BY_NAME=$(ssh $REMOTE "docker ps -a --format '{{.Names}}' 2>/dev/null | grep -iE '$GREP_PATTERN' | wc -l" 2>/dev/null | tr -d ' ' || echo "0")
                
                if [ "$RUNNING_BY_NAME" != "0" ] && [ -n "$RUNNING_BY_NAME" ]; then
                    if [ "$RUNNING_BY_NAME" -gt "$RUNNING_COUNT" ] 2>/dev/null || [ "$RUNNING_COUNT" = "0" ]; then
                        RUNNING_COUNT="$RUNNING_BY_NAME"
                        TOTAL_COUNT="$TOTAL_BY_NAME"
                    fi
                fi
            fi
        else
            # Directory doesn't exist or compose file missing - check by name pattern only
            APP_NAME_LOWER=$(echo "$APP_NAME" | tr '[:upper:]' '[:lower:]')
            APP_NAME_ESCAPED=$(echo "$APP_NAME_LOWER" | sed 's/[][\.*^$()+?{|]/\\&/g')
            RUNNING_COUNT=$(ssh $REMOTE "docker ps --format '{{.Names}}' 2>/dev/null | grep -iE '$APP_NAME_ESCAPED' | wc -l" 2>/dev/null | tr -d ' ' || echo "0")
            TOTAL_COUNT=$(ssh $REMOTE "docker ps -a --format '{{.Names}}' 2>/dev/null | grep -iE '$APP_NAME_ESCAPED' | wc -l" 2>/dev/null | tr -d ' ' || echo "0")
        fi
        
        stop_spinner
        
        # Normalize counts
        if [ -z "$RUNNING_COUNT" ] || ! echo "$RUNNING_COUNT" | grep -qE '^[0-9]+$'; then
            RUNNING_COUNT="0"
        fi
        if [ -z "$TOTAL_COUNT" ] || ! echo "$TOTAL_COUNT" | grep -qE '^[0-9]+$'; then
            TOTAL_COUNT="0"
        fi
        
        # Display container status
        if [ "$RUNNING_COUNT" != "0" ] && [ "$RUNNING_COUNT" != "" ]; then
            if [ "$TOTAL_COUNT" != "0" ] && [ "$RUNNING_COUNT" = "$TOTAL_COUNT" ]; then
                echo -e "   ${GREEN}Containers:${NC}  $RUNNING_COUNT running"
            elif [ "$TOTAL_COUNT" != "0" ]; then
                echo -e "   ${YELLOW}Containers:${NC}  $RUNNING_COUNT/$TOTAL_COUNT running"
            else
                echo -e "   ${GREEN}Containers:${NC}  $RUNNING_COUNT running"
            fi
        else
            echo -e "   ${YELLOW}Containers:${NC}  Not running"
        fi
        echo ""
    done
}

