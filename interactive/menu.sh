#!/bin/bash
# DockUp Interactive Menu
# Main interactive CLI menu

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/version.sh"
source "$SCRIPT_DIR/interactive/remotes.sh"
source "$SCRIPT_DIR/interactive/apps.sh"

# Interactive main menu
interactive_menu() {
    while true; do
        print_version
        echo ""
        echo -e "${GREEN}🚀 DockUp Interactive CLI${NC}"
        echo ""
        echo -e "${BLUE}Select a command:${NC}"
        echo ""
        
        # Command options with descriptions
        local commands=(
            "deploy:Deploy your app (recommended - handles setup + init + deploy)"
            "setup:One-time VPS setup (install DockUp agent)"
            "init:Register repository (without deploying)"
            "list:List all registered apps"
            "disconnect:Unlink project from DockUp (keeps app running)"
            "remove:Delete project completely"
            "configure-github-app:Configure GitHub App credentials"
            "version:Show version information"
            "help:Show help message"
            "exit:Exit interactive mode"
        )
        
        # Extract command names for select menu
        local cmd_names=()
        for cmd_entry in "${commands[@]}"; do
            IFS=':' read -r cmd_name cmd_desc <<< "$cmd_entry"
            cmd_names+=("$cmd_name")
        done
        
        # Display menu
        PS3="Select command (1-${#cmd_names[@]}): "
        select choice in "${cmd_names[@]}"; do
            if [ -z "$choice" ]; then
                echo -e "${RED}Invalid selection. Please try again.${NC}"
                echo ""
                break
            fi
            
            # Handle special cases
            case "$choice" in
                "exit")
                    echo -e "${BLUE}Goodbye!${NC}"
                    exit 0
                    ;;
                "help")
                    echo ""
                    echo "Usage: dockup user@host {setup|init|deploy|disconnect|remove|list|configure-github-app|version} [options]"
                    echo ""
                    echo "Commands:"
                    echo ""
                    echo -e "${GREEN}  deploy${NC}     - Unified command (RECOMMENDED)"
                    echo "     Automatically handles: setup + init + deploy"
                    echo ""
                    echo -e "${YELLOW}  setup${NC}      - One-time VPS setup"
                    echo "     Installs DockUp agent on your VPS"
                    echo ""
                    echo -e "${YELLOW}  init${NC}       - Register repository"
                    echo "     Registers your repo with DockUp (without deploying)"
                    echo ""
                    echo -e "${BLUE}  list${NC}        - List registered apps"
                    echo "     Shows all apps registered in DockUp registry"
                    echo ""
                    echo -e "${BLUE}  disconnect${NC}  - Unlink project from DockUp"
                    echo "     Removes webhook and registry entry, keeps app directory"
                    echo ""
                    echo -e "${RED}  remove${NC}      - Delete project completely"
                    echo "     Stops containers, removes webhook, deletes app directory"
                    echo ""
                    echo -e "${BLUE}  configure-github-app${NC}  - Configure GitHub App credentials"
                    echo "     Configures GitHub App for repository access"
                    echo ""
                    echo -e "${BLUE}💡 Tip: Most users should use 'deploy' - it does everything!${NC}"
                    echo ""
                    echo -e "${YELLOW}Press Enter to return to menu...${NC}"
                    read
                    break
                    ;;
                "version")
                    cmd_version
                    echo ""
                    echo -e "${YELLOW}Press Enter to return to menu...${NC}"
                    read
                    break
                    ;;
            esac
            
            # Commands that need remote host
            local remote=""
            case "$choice" in
                "setup"|"init"|"deploy"|"list"|"disconnect"|"remove"|"configure-github-app")
                    remote=$(prompt_remote "Enter remote host" "")
                    local prompt_status=$?
                    if [ -z "$remote" ] || [ $prompt_status -ne 0 ]; then
                        echo -e "${RED}❌ Remote host is required${NC}"
                        echo ""
                        echo -e "${YELLOW}Press Enter to return to menu...${NC}"
                        read
                        break
                    fi
                    ;;
            esac
            
            # Commands that need app selection
            local app_name=""
            case "$choice" in
                "disconnect"|"remove")
                    app_name=$(select_app "$remote")
                    local select_status=$?
                    if [ -z "$app_name" ] || [ $select_status -ne 0 ]; then
                        echo -e "${YELLOW}Cancelled${NC}"
                        echo ""
                        echo -e "${YELLOW}Press Enter to return to menu...${NC}"
                        read
                        break
                    fi
                    ;;
            esac
            
            # Execute the selected command
            echo ""
            case "$choice" in
                "setup")
                    cmd_setup "$remote"
                    ;;
                "init")
                    cmd_init "$remote"
                    ;;
                "deploy")
                    # Ask about rebuild flag
                    echo -e "${BLUE}Force rebuild?${NC}"
                    read -p "Rebuild images even if unchanged? (y/N): " REBUILD_INPUT
                    if [ "$REBUILD_INPUT" = "y" ] || [ "$REBUILD_INPUT" = "Y" ]; then
                        cmd_deploy "$remote" "--rebuild"
                    else
                        cmd_deploy "$remote"
                    fi
                    ;;
                "list")
                    cmd_list "$remote"
                    ;;
                "disconnect")
                    cmd_disconnect "$remote" "$app_name"
                    ;;
                "remove")
                    cmd_remove "$remote" "$app_name"
                    ;;
                "configure-github-app")
                    cmd_configure_github_app "$remote"
                    ;;
                "configure-metrics")
                    cmd_configure_metrics "$remote"
                    ;;
            esac
            
            echo ""
            echo -e "${YELLOW}Press Enter to return to menu...${NC}"
            read
            break
        done
    done
}

