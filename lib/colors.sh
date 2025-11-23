#!/bin/bash
# DockUp Color Constants
# Provides color codes for terminal output

# Color codes
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export RED='\033[0;31m'
export BLUE='\033[0;34m'
export CYAN='\033[0;36m'
export MAGENTA='\033[0;35m'
export BOLD='\033[1m'
export NC='\033[0m' # No Color

# Color functions for better readability
color_green() {
    echo -e "${GREEN}$*${NC}"
}

color_yellow() {
    echo -e "${YELLOW}$*${NC}"
}

color_red() {
    echo -e "${RED}$*${NC}"
}

color_blue() {
    echo -e "${BLUE}$*${NC}"
}

color_cyan() {
    echo -e "${CYAN}$*${NC}"
}

