#!/bin/bash
# DockUp Loading Animation Utilities
# Provides spinner and progress indicators for long-running operations

# Source colors
[ -f "$(dirname "${BASH_SOURCE[0]}")/colors.sh" ] && source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"

# Spinner characters
SPINNER_CHARS="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
SPINNER_CHARS_ALT="⣾⣽⣻⢿⡿⣟⣯⣷"
SPINNER_CHARS_DOTS="⠁⠂⠄⠂"

# Current spinner state
SPINNER_PID=""
SPINNER_MSG=""

# Start a spinner animation
# Usage: start_spinner "Loading..."
start_spinner() {
    local msg="${1:-Loading...}"
    SPINNER_MSG="$msg"
    
    # Hide cursor
    tput civis 2>/dev/null || true
    
    # Start spinner in background, redirect to stderr to avoid conflicts with stdout
    (
        local i=0
        while true; do
            local char="${SPINNER_CHARS:$i:1}"
            echo -ne "\r${BLUE}${char}${NC} ${SPINNER_MSG}" >&2
            i=$(((i + 1) % ${#SPINNER_CHARS}))
            sleep 0.1
        done
    ) &
    
    SPINNER_PID=$!
}

# Stop the spinner
stop_spinner() {
    if [ -n "$SPINNER_PID" ]; then
        # Kill spinner and wait for it to finish
        kill $SPINNER_PID 2>/dev/null || true
        wait $SPINNER_PID 2>/dev/null || true
        SPINNER_PID=""
    fi
    
    # Show cursor and clear line (redirect to stderr)
    tput cnorm 2>/dev/null || true
    echo -ne "\r\033[K" >&2
}

# Show success message
show_success() {
    local msg="${1:-Done}"
    echo -e "\r${GREEN}✓${NC} ${msg}" >&2
}

# Show error message
show_error() {
    local msg="${1:-Error}"
    echo -e "\r${RED}✗${NC} ${msg}" >&2
}

# Show info message
show_info() {
    local msg="${1}"
    echo -e "${BLUE}ℹ${NC} ${msg}"
}

# Run a command with spinner
# Usage: run_with_spinner "Installing..." command args...
run_with_spinner() {
    local msg="$1"
    shift
    
    start_spinner "$msg"
    
    # Run command and capture output
    local output
    local exit_code
    
    if output=$("$@" 2>&1); then
        exit_code=0
    else
        exit_code=$?
    fi
    
    stop_spinner
    
    if [ $exit_code -eq 0 ]; then
        show_success "$msg"
        echo "$output"
        return 0
    else
        show_error "$msg failed"
        echo "$output" >&2
        return $exit_code
    fi
}

# Show progress bar (simple version)
# Usage: show_progress current total "message"
show_progress() {
    local current="$1"
    local total="$2"
    local msg="${3:-Progress}"
    
    local percent=$((current * 100 / total))
    local filled=$((percent / 2))
    local empty=$((50 - filled))
    
    local bar=""
    local i
    for ((i=0; i<filled; i++)); do
        bar="${bar}█"
    done
    for ((i=0; i<empty; i++)); do
        bar="${bar}░"
    done
    
    echo -ne "\r${BLUE}[${bar}]${NC} ${percent}% - ${msg}"
    
    if [ "$current" -eq "$total" ]; then
        echo ""
    fi
}

# Cleanup on exit
cleanup_spinner() {
    stop_spinner
}

# Set up trap to clean up spinner on script exit
trap cleanup_spinner EXIT INT TERM

