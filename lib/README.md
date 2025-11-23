# DockUp Modular Structure

This directory contains the modular components of DockUp, organized for better maintainability and readability.

## Directory Structure

```
dockup/
├── lib/                    # Core library modules
│   ├── colors.sh           # Color constants and functions
│   ├── loading.sh          # Loading animations and spinners
│   ├── utils.sh            # Common utility functions
│   └── version.sh          # Version checking and comparison
├── commands/                # Command implementations
│   ├── list.sh             # List command (with loading animations)
│   └── version.sh          # Version command
├── interactive/            # Interactive CLI components
│   ├── menu.sh             # Main interactive menu
│   ├── remotes.sh          # Remote host management
│   └── apps.sh             # App selection
└── dockup                   # Main entry point (sources all modules)
```

## Module Loading

The main `dockup` script automatically loads modules if they exist, with fallback to inline functions for backward compatibility. This allows gradual migration.

## Adding New Modules

1. Create your module file in the appropriate directory
2. Source it in the main `dockup` file
3. Use conditional loading: `[ -f "$SCRIPT_DIR/path/to/module.sh" ] && source "$SCRIPT_DIR/path/to/module.sh"`

## Loading Animations

The `lib/loading.sh` module provides:
- `start_spinner "message"` - Start a spinner animation
- `stop_spinner` - Stop the spinner
- `show_success "message"` - Show success message
- `show_error "message"` - Show error message
- `run_with_spinner "message" command args...` - Run command with spinner

Example usage:
```bash
source "$SCRIPT_DIR/lib/loading.sh"
start_spinner "Installing..."
# ... do work ...
stop_spinner
show_success "Installation complete"
```

